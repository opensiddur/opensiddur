xquery version "3.0";
(:~ perform the list compilation stage in the background 
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace app="http://jewishliturgy.org/modules/app"
  at "xmldb:exist:///code/modules/app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "xmldb:exist:///code/modules/debug.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "xmldb:exist:///code/modules/format.xqm";

declare namespace err="http://jewishliturgy.org/errors";

(:
declare variable $local:source-collection external;   source collection of data to be compiled (cache!)
declare variable $local:source-resource external;     source resource name
declare variable $local:dest-collection external;     destination collection for data to be compiled
declare variable $local:dest-resource external;       destination resource name
:)

debug:debug(
  $debug:info,
  "jobs",
  concat("List compilation phase for ", $local:source-collection, "/", $local:source-resource)
  ),
format:update-status($local:dest-collection, $local:source-resource, $format:list, $local:job-id),
let $source-path := concat($local:source-collection, "/", $local:source-resource)
let $dest-path := concat($local:dest-collection, "/", $local:dest-resource)
let $compiled := format:list-compile($source-path, $local:user, $local:password)
return 
  if (xmldb:store($local:dest-collection, $local:dest-resource, $compiled))
  then 
    app:mirror-permissions($source-path, $dest-path)
  else 
    error(xs:QName("err:STORE"), concat("Cannot store ", $dest-path)),
format:complete-status($local:dest-collection, $local:source-resource)

