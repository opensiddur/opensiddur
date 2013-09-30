xquery version "3.0";
(:~ pre-install for opensiddur-sources
 : loads the sources data into the proper places in the database
 : 
 : Copyright 2013 Efraim Feinstein, efraim@opensiddur.org
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace debug="http://jewishliturgy.org/transform/debug"
    at "xmldb:exist:///db/apps/opensiddur-server/modules/debug.xqm";
import module namespace tran="http://jewishliturgy.org/api/transliteration"
    at "xmldb:exist:///db/apps/opensiddur-server/api/data/transliteration.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare function local:upgrade-or-install(
    $data as document-node(),
    $get as function(xs:string) as item()+,
    $post as function(document-node()) as item()+,
    $put as function(xs:string, document-node()) as item()+ 
    ) {
    let $title := ($data//(tei:title[not(@type) or @type="main"]|tr:title))[1]/string()
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

declare function local:install-transliteration(
    ) {
    let $get := tran:get#1
    let $put := tran:put#2
    let $post := tran:post#1
    for $document in collection($target || "/data/transliteration")[tr:schema]
    return (
        util:log-system-out("installing from " || util:document-name($document) || "..."),
        local:upgrade-or-install($document, $get, $post, $put)
    )
};

util:log-system-out("Starting installation of sources..."),
local:install-transliteration(),
util:log-system-out("Done.")
