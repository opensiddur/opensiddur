xquery version "3.0";
(:~ cache a single resource and its dependencies from the background,
 : store the cached copy in $local:dest-collection/$local:dest-resource 
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace format="http://jewishliturgy.org/modules/format"
  at "xmldb:exist:///code/modules/format.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "xmldb:exist:///code/modules/paths.xqm";
import module namespace jcache="http://jewishliturgy.org/modules/cache"
  at "xmldb:exist:///code/modules/cache-controller.xqm";

declare namespace err="http://jewishliturgy.org/errors";

(:
declare variable $local:source-resource external;
declare variable $local:user external;
declare variable $local:password external;
:)

try {
  if ($paths:debug)
  then 
    util:log-system-out(
      concat("Background caching for compile: ", $local:source-collection, "/", $local:source-resource)
    )
  else (),
  format:update-status($local:dest-collection, $local:source-resource, $format:caching),
  let $doc-path := concat($local:source-collection, "/", $local:source-resource)
  return (
    jcache:cache-all($doc-path, $local:user, $local:password),
    if (xmldb:store($local:dest-collection, $local:dest-resource, doc(jcache:cached-document-path($doc-path))))
    then 
      let $owner := xmldb:get-owner($local:source-collection, $local:source-resource)
      let $group := xmldb:get-group($local:source-collection, $local:source-resource)
      let $mode := xmldb:get-permissions($local:source-collection, $local:source-resource)
      return 
        xmldb:set-resource-permissions(
          $local:dest-collection, $local:dest-resource,
          $owner, $group, $mode)
    else
      error(xs:QName("err:STORE"), concat("Cannot store ", $local:dest-collection, "/", $local:dest-resource))
  ),
  format:complete-status($local:dest-collection, $local:source-resource)
}
catch * ($c, $d, $v) {
  util:log-system-out(("Error during background caching: ", $c, " ", $d, " ", $v))
}
