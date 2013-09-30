xquery version "3.0";
(:~ post-install for opensiddur-sources
 : loads the sources data into the proper places in the database
 : 
 : Copyright 2013 Efraim Feinstein, efraim@opensiddur.org
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(: This script has to be post-install, because pre-install cannot access imported modules :)
import module namespace debug="http://jewishliturgy.org/transform/debug"
    at "xmldb:exist:///db/apps/opensiddur-server/modules/debug.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
    at "xmldb:exist:///db/apps/opensiddur-server/modules/format.xqm";
import module namespace notes="http://jewishliturgy.org/api/data/notes"
    at "xmldb:exist:///db/apps/opensiddur-server/api/data/notes.xqm";
import module namespace orig="http://jewishliturgy.org/api/data/original"
    at "xmldb:exist:///db/apps/opensiddur-server/api/data/original.xqm";
import module namespace src="http://jewishliturgy.org/api/data/sources"
    at "xmldb:exist:///db/apps/opensiddur-server/api/data/sources.xqm";
import module namespace tran="http://jewishliturgy.org/api/transliteration"
    at "xmldb:exist:///db/apps/opensiddur-server/api/data/transliteration.xqm";
import module namespace user="http://jewishliturgy.org/api/user"
    at "xmldb:exist:///db/apps/opensiddur-server/api/user.xqm";

declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare variable $local:functions := map {
    "get-notes" := notes:get#1,
    "put-notes" := notes:put#2,
    "post-notes" := notes:post#1,
    "get-original" := orig:get#1,
    "put-original" := orig:put#2,
    "post-original" := orig:post#1,
    "get-sources" := src:get#1,
    "put-sources" := src:put#2,
    "post-sources" := src:post#1,
    "get-transliteration" := tran:get#1,
    "put-transliteration" := tran:put#2,
    "post-transliteration" := tran:post#1,
    "get-user" := user:get#1,
    "put-user" := user:put#2,
    "post-user" := local:post-user#1
    };

declare function local:post-user(
    $data as document-node()
    ) {
    let $name := $data/j:contributor/tei:idno[1]/string()
    let $resource := encode-for-uri($name) || ".xml"
    let $uri := xs:anyURI("/db/data/user/" || $resource)
    return (
      xmldb:store("/db/data/user", $resource, $data),
        sm:chmod($uri, "rw-r--r--")
    )
};

declare function local:upgrade-or-install(
    $data as document-node(),
    $get as function(xs:string) as item()+,
    $post as function(document-node()) as item()+,
    $put as function(xs:string, document-node()) as item()+ 
    ) {
    let $title := ($data//(tei:title[not(@type) or @type="main"]|tr:title|tei:idno[parent::j:contributor]))[1]/string()
    let $name := encode-for-uri(replace($title, "\p{M}", ""))
    let $null := util:log-system-out(("Name will be:", $name))
    let $return :=
        try {
          if ($get($name) instance of document-node())
          then (
              util:log-system-out("put"),
              $put($name, $data)
          )
          else (
              util:log-system-out("post"),
              $post($data)
          )
        }
        catch * {
            (<filler/>, 
            <error xmlns="">{
                debug:print-exception(
                    $err:module, $err:line-number, $err:column-number,
                    $err:code, $err:value, $err:description
                )
            }</error>)
        }
    where $return[2] instance of element(error)
    return
        util:log-system-out(("Error: ", $return[2]))
};

declare function local:upgrade-or-install-by-type(
    $data as document-node(),
    $type as xs:string
    ) {
    local:upgrade-or-install(
        $data,
        $local:functions("get-" || $type),
        $local:functions("post-" || $type),
        $local:functions("put-" || $type)
    )
};

declare function local:install-data(
    ) {
    util:log-system-out("Installing data files..."),
    for $data-type in ("user", "transliteration", "sources", "original", "notes")
    let $null := util:log-system-out("Installing " || $data-type || "...")
    for $document in collection($target || "/data/" || $data-type)
    order by count(format:get-dependencies($document)/*)
    return (
        util:log-system-out("Installing from " || util:document-name($document) || "..."),
        local:upgrade-or-install-by-type($document, $data-type)
    ) 
};

util:log-system-out("Starting installation of sources..."),
local:install-data(),
util:log-system-out("Done.")
