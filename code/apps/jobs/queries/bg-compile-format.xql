xquery version "3.0";
(:~ perform the format compilation stage in the background 
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace data="http://jewishliturgy.org/modules/data"
  at "xmldb:exist:///code/api/modules/data.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "xmldb:exist:///code/modules/paths.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "xmldb:exist:///code/modules/format.xqm";

declare namespace err="http://jewishliturgy.org/errors";

(:
declare variable $local:source-collection external;   source collection of data to be compiled (cache!)
declare variable $local:source-resource external;     source resource name
declare variable $local:dest-collection external;     destination collection for data to be compiled
declare variable $local:dest-resource external;       destination resource name
declare variable $local:style external;               style CSS @href
:)

try {
  if ($paths:debug)
  then 
    util:log-system-out(
      concat("Format compilation phase for ", $local:source-collection, "/", $local:source-resource)
    )
  else (),
  format:update-status($local:dest-collection, $local:source-resource, $format:format),
  let $source-path := concat($local:source-collection, "/", $local:source-resource)
  let $dest-path := concat($local:dest-collection, "/", $local:dest-resource)
  let $style-dest-resource := replace($local:dest-resource, "(\.[^.]+)$", ".css")
  let $dest-css-path := concat($local:dest-collection, "/", $style-dest-resource)
  let $compiled := format:format-xhtml($source-path, $style-dest-resource, $local:user, $local:password)
  let $style-css :=
    util:binary-to-string(util:binary-doc(
      if ($local:style)
      then data:api-path-to-db($local:style)
      else "/db/code/transforms/format/xhtml/style.css"
    ))
  let $owner := xmldb:get-owner($local:source-collection, $local:source-resource)
  let $group := xmldb:get-group($local:source-collection, $local:source-resource)
  let $mode := xmldb:get-permissions($local:source-collection, $local:source-resource)
  return ( 
    if (xmldb:store($local:dest-collection, $local:dest-resource, $compiled))
    then 
      xmldb:set-resource-permissions(
        $local:dest-collection, $local:dest-resource,
        $owner, $group, $mode)
    else 
      error(xs:QName("err:STORE"), concat("Cannot store ", $dest-path)),
    if (xmldb:store($local:dest-collection, $style-dest-resource, $style-css, "text/css"))
    then
      xmldb:set-resource-permissions(
        $local:dest-collection, $style-dest-resource,
        $owner, $group, $mode)
    else
      error(xs:QName("err:STORE"), concat("Cannot store ", $dest-css-path))
  ),
  format:complete-status($local:dest-collection, $local:dest-resource)
}
catch * ($c, $d, $v) {
  util:log-system-out(("Error during background formatting: ", $c, " ", $d, " ", $v))
}

