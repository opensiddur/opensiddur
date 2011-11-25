xquery version "3.0";
(:~ perform the transliteration stage in the background 
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "xmldb:exist:///code/modules/debug.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "xmldb:exist:///code/modules/format.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace err="http://jewishliturgy.org/errors";

(:
declare variable $local:source-collection external;   source collection of data to be compiled (cache!)
declare variable $local:source-resource external;     source resource name
declare variable $local:dest-collection external;     destination collection for data to be compiled
declare variable $local:dest-resource external;       destination resource name
:)


debug:debug($debug:info,
  "compilation",
  concat("Transliteration phase for ", $local:source-collection, "/", $local:source-resource)
  ),
format:update-status($local:dest-collection, $local:source-resource, $format:transliteration, $local:job-id),
let $source-path := concat($local:source-collection, "/", $local:source-resource)
let $dest-path := concat($local:dest-collection, "/", $local:dest-resource)
let $source-doc := doc($source-path)
let $transliterated := 
  if (exists($source-doc//tei:fs[@type="Transliterate"]))
  then
    format:transliterate($source-path, $local:user, $local:password)
  else $source-doc
return 
  if (xmldb:store($local:dest-collection, $local:dest-resource, $transliterated))
  then 
    let $owner := xmldb:get-owner($local:source-collection, $local:source-resource)
    let $group := xmldb:get-group($local:source-collection, $local:source-resource)
    let $mode := xmldb:get-permissions($local:source-collection, $local:source-resource)
    return 
      xmldb:set-resource-permissions(
        $local:dest-collection, $local:dest-resource,
        $owner, $group, $mode)
  else 
    error(xs:QName("err:STORE"), concat("Cannot store ", $dest-path)),
format:complete-status($local:dest-collection, $local:source-resource)

