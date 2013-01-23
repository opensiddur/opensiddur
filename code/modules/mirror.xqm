xquery version "3.0";
(:~ mirror collections
 :
 : A mirror collection is a collection intended to cache some
 : aspect of another collection, maintaining the same directory
 : structure and permissions
 :
 : @author Efraim Feinstein
 : Open Siddur Project
 : Copyright 2011-2012 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later 
 :)
module namespace mirror = 'http://jewishliturgy.org/modules/mirror';

import module namespace app="http://jewishliturgy.org/modules/app"
  at "xmldb:exist:///db/code/modules/app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "xmldb:exist:///db/code/modules/debug.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:///db/code/magic/magic.xqm";

declare namespace error="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $mirror:configuration := "mirror-conf.xml";

(:~ create a mirror collection
 : @param $mirror-path Full path to the new mirror collection
 : @param $original-path Full path to the collection that is to be mirrored
 : @return empty-sequence()
 :)
declare function mirror:create(
  $mirror-path as xs:string,
  $original-path as xs:string
  ) as empty-sequence() {
  let $create := 
    app:make-collection-path(
      $mirror-path, "/", sm:get-permissions($original-path)
    )
  let $uri := xs:anyURI(
    xmldb:store($mirror-path, $mirror:configuration,
    <mirror:configuration>
      <mirror:of>{replace($original-path, "^/db", "")}</mirror:of>
    </mirror:configuration>)
    )
  return
    if ($uri)
    then 
      system:as-user("admin", $magic:password, (
        sm:chown($uri, "admin"),
        sm:chgrp($uri, "dba"),
        sm:chmod($uri, "rw-rw-r--")
      ))
    else error(xs:QName("error:STORAGE"), "Cannot store mirror collection configuration.", $mirror-path)  
};

(:~ @return the configuration file for a mirror collection 
 : @error error:NOT_A_MIRROR if the collection is not a mirror collection
 :)
declare function local:config(
  $mirror-path as xs:string
  ) as document-node() {
  let $config := doc($mirror-path || "/" || $mirror:configuration)
  return
    if ($config)
    then $config
    else error(xs:QName("error:NOT_A_MIRROR"), "The collection is not a mirror collection.", $mirror-path)
};

(:~ @return the original base path :)
declare function local:base-path(
  $mirror-path as xs:string
  ) as xs:string {
  local:config($mirror-path)/mirror:configuration/mirror:of/string()
};

(:~ @param $path The relative (not beginning with /) or absolute (beginning with /) path of the desired collection  
 : @return the mirror path 
 : @error error:NOT_A_MIRROR The collection $mirror-path is not a mirror collection
 : @error error:NOT_MIRRORED The collection $path is not a subcollection of the original path and is not mirrored in this mirror collection
 :)
declare function mirror:mirror-path(
  $mirror-path as xs:string,
  $path as xs:string
  ) as xs:string {
  let $mirror-no-db := replace($mirror-path, "^/db", "")
  let $path-no-db := replace($path, "^/db", "")
  let $base-path := local:base-path($mirror-path)
  return
    if (starts-with($path-no-db, $base-path))
    then replace($path-no-db, "^" || $base-path, $mirror-no-db)
    else if (starts-with($path, "/"))
    then 
      error(
        xs:QName("error:NOT_MIRRORED"), 
        "The absolute path " || $path || "is not mirrored in " || $mirror-path
      ) 
    else 
      (: relative path :)
      app:concat-path($mirror-no-db, $path)
};

(:~ turn a path from relative to a mirror to one relative the original path
 : @error error:NOT_A_MIRROR The collection $mirror-path is not a mirror collection
 : @error error:NOT_MIRRORED The collection $path is not a subcollection of the original path and is not mirrored in this mirror collection
 :)
declare function mirror:unmirror-path(
  $mirror-path as xs:string,
  $mirrored-path as xs:string
  ) as xs:string {
  let $mirror-no-db := replace($mirror-path, "^/db", "")
  let $base-path := local:base-path($mirror-path)
  let $mirrored-path-no-db := replace($mirrored-path, "^/db", "")
  return
    if (starts-with($mirrored-path-no-db, $mirror-no-db))
    then replace($mirrored-path-no-db, "^" || $mirror-no-db, $base-path)
    else 
      error(
        xs:QName("error:NOT_MIRRORED"), 
        "The absolute path " || $mirrored-path || "is not mirrored in " || $mirror-path
      )
};

(:~ make a mirror collection path that mirrors the same path in 
 : the normal /db hierarchy 
 : @param $mirror-path the base location of the mirror
 : @param $path the path that should be mirrored (relative to /db)
 : @error error:NOT_A_MIRROR The collection $mirror-path is not a mirror collection
 : @error error:NOT_MIRRORED The collection $path is not a subcollection of the original path and is not mirrored in this mirror collection
 : @error error:CREATE A collection could not be created
 :)
(: TODO: this function is wrong! :)
declare function mirror:make-collection-path(
  $mirror-path as xs:string,
  $path as xs:string
  ) as empty-sequence() {
  let $mirror-path-no-db := replace($mirror-path, "^/db", "")
  let $path-no-db := replace($path, "^/db", "")
  let $mirrored-path := mirror:mirror-path($mirror-path, $path)
  let $base-path := local:base-path($mirror-path)
  (: extended-* is the path part after the mirror or original base. :)
  let $extended-path := substring-after($path, $base-path)
  let $extended-mirror := substring-after($mirrored-path, $mirror-path-no-db)
  let $steps := 
    tokenize($extended-mirror, '/')[.]
  for $step in 1 to count($steps)
  let $this-step := 
    app:concat-path(($base-path, subsequence($steps, 1, $step)))
  let $mirror-this-step := 
    mirror:mirror-path($mirror-path,$this-step)
  let $mirror-previous-step := 
    app:concat-path(($mirror-path, subsequence($steps, 1, $step - 1)))
  where not(xmldb:collection-available($mirror-this-step))
  return
    let $new-collection := $steps[$step]
    let $null := 
      debug:debug(
        $debug:info,
        "mirror",
        (("step ", $step, ":", $this-step, " new-collection=",$new-collection, " from ", $mirror-previous-step))
      )
    return (
      debug:debug(
        $debug:info,
        "mirror",
        ('creating new mirror collection: ', 
        $mirror-this-step, ' from ', 
        $mirror-previous-step, ' to ', 
        $new-collection)
      ),
      if (xmldb:create-collection($mirror-previous-step, $new-collection))
      then 
        mirror:mirror-permissions($this-step, $mirror-this-step)
      else error(xs:QName('error:CREATE'), concat('Cannot create mirror collection ', $this-step))
    )
};

declare function mirror:mirror-permissions( 
  $source as xs:anyAtomicType,
  $dest as xs:anyAtomicType
  ) as empty-sequence() {
  app:mirror-permissions($source, $dest)
};

(: determine if a path or original document is up to date 
 : @param $mirror the name of the mirror collection
 : @param $original original document as document-node() or path
 : @param $up-to-date-function A function that determines additional
 :    up to date information and returns an xs:boolean
 :)
declare function mirror:is-up-to-date(
  $mirror-path as xs:string, 
  $original as item(),
  $up-to-date-function as (function(xs:string, item()) as xs:boolean)?
  ) as xs:boolean {
  let $original-doc := 
    typeswitch($original)
    case document-node() return $original
    default return doc($original)
  let $collection := util:collection-name($original-doc)
  let $resource := util:document-name($original-doc)
  let $mirror-collection := mirror:mirror-path($mirror-path, $collection) 
  let $last-modified := xmldb:last-modified($collection, $resource)
  let $mirror-last-modified := xmldb:last-modified($mirror-collection, $resource) 
  return
    (
      if (exists($up-to-date-function))
      then boolean($up-to-date-function($mirror-path, $original))
      else true()
    ) and
    not(
      empty($last-modified) or 
      empty($mirror-last-modified) or 
      ($last-modified > $mirror-last-modified)
    )
};

declare function mirror:is-up-to-date(
  $mirror-path as xs:string,
  $original as item()
  ) as xs:boolean {
  mirror:is-up-to-date($mirror-path, $original, ())
};

(:~ store data in a mirror collection 
 : @param $mirror-path Base of the mirror
 : @param $collection Original path to the collection
 : @param $resource Resource name
 : @param $data The data to store
 :)
declare function mirror:store(
  $mirror-path as xs:string,
  $collection as xs:string,
  $resource as xs:string,
  $data as item()+
  ) as xs:string? {
  let $mirror-collection := mirror:mirror-path($mirror-path, $collection)
  let $make :=  
    system:as-user("admin", $magic:password, 
      mirror:make-collection-path($mirror-path, $collection)
    )
  let $mirror-path := concat($mirror-collection, "/", $resource) 
  return
    if (xmldb:store($mirror-collection, $resource, $data))
    then (
      mirror:mirror-permissions(
        concat($collection, "/", $resource),
        $mirror-path
        ),
      $mirror-path
    )
    else () 
};

declare function mirror:remove(
  $mirror as xs:string,
  $collection as xs:string,
  $resource as xs:string?
  ) as empty-sequence() {
  let $mirror-collection := mirror:mirror-path($mirror,$collection)
  return
    if (not($resource))
    then
      (: remove a collection :)
      let $exists := xmldb:collection-available($mirror-collection)
      where $exists
      return xmldb:remove($mirror-collection)
    else
      (: remove a resource :)
      let $mirror-path := concat($mirror-collection, "/", $resource)
      let $exists := 
        util:binary-doc-available($mirror-path) or 
        doc-available($mirror-path)
      where $exists
      return xmldb:remove($mirror-collection, $resource)
};

declare function mirror:remove(
  $mirror as xs:string,
  $collection as xs:string
  ) as empty-sequence() {
  mirror:remove($mirror, $collection, ())
};

declare function mirror:collection-available(
  $mirror as xs:string,
  $collection as xs:string
  ) as xs:boolean {
  xmldb:collection-available(mirror:mirror-path($mirror, $collection))
};

declare function mirror:doc-available(
  $mirror as xs:string,
  $path as xs:string
  ) as xs:boolean {
  doc-available(mirror:mirror-path($mirror, $path))
};

(:~ get a document from a mirror :)
declare function mirror:doc(
  $mirror as xs:string,
  $path as xs:string
  ) as document-node()? {
  doc(mirror:mirror-path($mirror, $path))
};

declare function mirror:binary-doc-available(
  $mirror as xs:string,
  $path as xs:string
  ) as xs:boolean {
  util:binary-doc-available(mirror:mirror-path($mirror, $path))
};

declare function mirror:binary-doc(
  $mirror as xs:string,
  $path as xs:string
  ) as xs:base64Binary? {
  util:binary-doc(mirror:mirror-path($mirror, $path))
};