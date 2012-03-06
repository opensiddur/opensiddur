xquery version "3.0";
(:~ cache a single resource and its dependencies from the background,
 : store the cached copy in $local:dest-collection/$local:dest-resource 
 :  
 : Copyright 2011-2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace app="http://jewishliturgy.org/modules/app"
  at "xmldb:exist:///code/modules/app.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "xmldb:exist:///code/modules/format.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "xmldb:exist:///code/modules/debug.xqm";
import module namespace jcache="http://jewishliturgy.org/modules/cache"
  at "xmldb:exist:///code/modules/cache-controller.xqm";

declare namespace err="http://jewishliturgy.org/errors";

(:
declare variable $local:source-resource external;
declare variable $local:user external;
declare variable $local:password external;
:)

debug:debug(
  $debug:info,
  "jobs",
  concat("Background caching for compile: ", $local:source-collection, "/", $local:source-resource, " as ", $local:user, ":", $local:password)
  ),
format:update-status($local:dest-collection, $local:source-resource, $format:caching, $local:job-id),
let $doc-path := concat($local:source-collection, "/", $local:source-resource)
let $dest-path := concat($local:dest-collection, "/", $local:dest-resource)
return (
  jcache:cache-all($doc-path, $local:user, $local:password),
  if (xmldb:store($local:dest-collection, $local:dest-resource, doc(jcache:cached-document-path($doc-path))))
  then
    app:mirror-permissions($doc-path, $dest-path)
  else
    error(xs:QName("err:STORE"), concat("Cannot store ", $local:dest-collection, "/", $local:dest-resource))
),
format:complete-status($local:dest-collection, $local:source-resource)

