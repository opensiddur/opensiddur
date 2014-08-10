xquery version "3.0";
(:~ mirror collections
 :
 : A mirror collection is a collection intended to cache some
 : aspect of another collection, maintaining the same directory
 : structure and permissions
 :
 : @author Efraim Feinstein
 : Open Siddur Project
 : Copyright 2011-2014 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later 
 :)
module namespace mirror = 'http://jewishliturgy.org/modules/mirror';

import module namespace app="http://jewishliturgy.org/modules/app"
  at "app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "debug.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "../magic/magic.xqm";

declare namespace error="http://jewishliturgy.org/errors";

declare variable $mirror:configuration := "mirror-conf.xml";

(:~ create a mirror collection
 : @param $mirror-path Full path to the new mirror collection
 : @param $original-path Full path to the collection that is to be mirrored
 : @param $allow-universal-access Allow universal r/w/x access 
 :    to cache *collections*; useful for intermediate processing 
 :    collections where guests should be allowed to make modifications
 : @param $extension-map Map extensions to other extensions in this mirror. If an extension is not listed, it stays the same
 : @return empty-sequence()
 : @error error:INPUT one of the the original or mirror paths is not absolute
 :)
declare function mirror:create(
  $mirror-path as xs:string,
  $original-path as xs:string,
  $allow-universal-access as xs:boolean,
  $extension-map as map
  ) as empty-sequence() {
  let $check := 
    if (starts-with($mirror-path, "/db"))
    then
        if (starts-with($original-path, "/db"))
        then true()
        else error(xs:QName("error:INPUT"), "original-path must be absolute")
    else error(xs:QName("error:INPUT"), "mirror-path must be absolute")
  let $create := 
    app:make-collection-path(
      $mirror-path, "/", 
      sm:get-permissions($original-path)
    )
  let $universal :=
    for $allow in $allow-universal-access
    where $allow
    return
      system:as-user("admin", $magic:password, 
        sm:chmod(xs:anyURI($mirror-path), "rwxrwxrwx")
      )
  let $uri := xs:anyURI(
    xmldb:store($mirror-path, $mirror:configuration,
    <mirror:configuration>
      <mirror:of>{
        $original-path
      }</mirror:of>
      <mirror:universal-access>{$allow-universal-access}</mirror:universal-access>
      {
        for $extension in map:keys($extension-map)
        return
          <mirror:map from="{$extension}" to="{$extension-map($extension)}"/>
      }
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

declare function mirror:create(
  $mirror-path as xs:string,
  $original-path as xs:string,
  $allow-universal-access as xs:boolean
  ) as empty-sequence() {
  mirror:create($mirror-path, $original-path, $allow-universal-access, map {})
};


declare function mirror:create(
  $mirror-path as xs:string,
  $original-path as xs:string
  ) as empty-sequence() {
  mirror:create($mirror-path, $original-path, false(), map {})
};

(:~ @return Whether the mirror supports universal access
 : @error error:NOT_A_MIRROR if the collection is not a mirror collection
 :)
declare function mirror:supports-universal-access(
  $mirror-path as xs:string
  ) as xs:boolean {
  xs:boolean(local:config($mirror-path)/*/mirror:universal-access)
};

(:~ @return A resource name mapped to its in-mirror representation
 :)
declare function mirror:map-resource-name(
  $mirror-path as xs:string,
  $name as xs:string
  ) as xs:string {
  let $extensions :=
      local:config($mirror-path)/*/mirror:map
  return (
    for $ext in $extensions
    let $regexp := "\." || $ext/@from || "$"
    where matches($name, $regexp)
    return replace($name, $regexp, "." || $ext/@to ),
    $name
  )[1]
};

(:~ @return A resource name mapped to its original representation
 :)
declare function mirror:unmap-resource-name(
  $mirror-path as xs:string,
  $mirror-name as xs:string
  ) as xs:string {
  let $extensions :=
      local:config($mirror-path)/*/mirror:map
  return (
    for $ext in $extensions
    let $regexp := "\." || $ext/@to || "$"
    where matches($mirror-name, $regexp)
    return replace($mirror-name, $regexp, "." || $ext/@from ),
    $mirror-name
  )[1]
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

(:~
 : @param $mirror-path The absolute path to the mirror 
 : @param $path The relative (not beginning with /db) or absolute (beginning with /db) path of the desired collection  
 : @return the mirror path 
 : @error error:NOT_A_MIRROR The collection $mirror-path is not a mirror collection
 : @error error:NOT_MIRRORED The collection $path is not a subcollection of the original path and is not mirrored in this mirror collection
 :)
declare function mirror:mirror-path(
  $mirror-path as xs:string,
  $path as xs:string
  ) as xs:string {
  let $check :=
    if (starts-with($mirror-path, "/db"))
    then true()
    else error(xs:QName("error:INPUT"), "mirror-path is not absolute")
  let $base-path := local:base-path($mirror-path)
  return
    mirror:map-resource-name($mirror-path ,
      if (starts-with($path, $base-path))
      then replace($path, "^" || $base-path, $mirror-path)
      else if (starts-with($path, "/"))
      then 
        error(
          xs:QName("error:NOT_MIRRORED"), 
          "The absolute path " || $path || "is not mirrored in " || $mirror-path
        ) 
      else 
        (: relative path :)
        app:concat-path($mirror-path, $path)
    )
};

(:~ turn a path from relative to a mirror to one relative the original path
 : @param $mirror-path The absolute path to the mirror
 : @param $mirrored-path The absolute path to the mirrored location
 : @error error:INPUT One of the parameters is not an absolute path
 : @error error:NOT_A_MIRROR The collection $mirror-path is not a mirror collection
 : @error error:NOT_MIRRORED The collection $path is not a subcollection of the original path and is not mirrored in this mirror collection
 :)
declare function mirror:unmirror-path(
  $mirror-path as xs:string,
  $mirrored-path as xs:string
  ) as xs:string {
  let $check :=
    if (starts-with($mirror-path, "/db"))
    then
        if (starts-with($mirrored-path, "/db"))
        then true()
        else error(xs:QName("error:INPUT"), "The mirrored path is not absolute")
    else error(xs:QName("error:INPUT"), "The mirror-path is not absolute")
  let $base-path := local:base-path($mirror-path)
  return
    if (starts-with($mirrored-path, $mirror-path)) 
    then 
      mirror:unmap-resource-name(
        $mirror-path,
        replace($mirrored-path, "^" || $mirror-path, $base-path)
      )
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
        mirror:mirror-permissions($mirror-path, $this-step, $mirror-this-step)
      else error(xs:QName('error:CREATE'), concat('Cannot create mirror collection ', $this-step))
    )
};

declare function mirror:mirror-permissions(
  $mirror-path as xs:string,
  $source as xs:anyAtomicType,
  $dest as xs:anyAtomicType
  ) as empty-sequence() {
  if (mirror:supports-universal-access($mirror-path))
  then
    let $src-uri := $source cast as xs:anyURI
    let $dest-uri := $dest cast as xs:anyURI
    let $src-permissions := sm:get-permissions($src-uri)
    return
      system:as-user("admin", $magic:password, (
        sm:chown($dest-uri, $src-permissions/*/@owner/string()),
        sm:chgrp($dest-uri, $src-permissions/*/@group/string()),
        sm:chmod($dest-uri, "rwxrwxrwx")
      ))
  else
    app:mirror-permissions($source, $dest)
};

(: determine if a path or original document is up to date 
 : @param $mirror the name of the mirror collection
 : @param $original original document as document-node() or path
 : @param $up-to-date-function A function that determines additional
 :    up to date information and returns an xs:boolean ; The up-to-date function 
 :    will not be called when the mirror is already known to be out of date
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
  let $original-resource-name := util:document-name($original-doc)
  let $mirror-resource-name := 
    mirror:map-resource-name(
      $mirror-path, 
      $original-resource-name
    )
  let $mirror-collection := mirror:mirror-path($mirror-path, $collection) 
  let $last-modified := 
    try {
      xmldb:last-modified($collection, $original-resource-name)
    }
    catch * { () }
  let $mirror-last-modified := 
    (: if the collection does not exist, xmldb:last-modified() fails :)
    try {
      xmldb:last-modified($mirror-collection, $mirror-resource-name)
    }
    catch * { () } 
  return
    not(
      empty($last-modified) or 
      empty($mirror-last-modified) or 
      ($last-modified > $mirror-last-modified)
    ) and
    (
      empty($up-to-date-function)
      or $up-to-date-function($mirror-path, $original)
    )
};

declare function mirror:is-up-to-date(
  $mirror-path as xs:string,
  $original as item()
  ) as xs:boolean {
  mirror:is-up-to-date($mirror-path, $original, ())
};

(:~ determine if a cache is up to date with respect to another cache 
 : @param $mirror-path the cache to be determined
 : @param $original pointer to the original document or original document
 : @param $prev-mirror-path the cache to compare to
 : @return a boolean
 :)
declare function mirror:is-up-to-date-cache(
  $mirror-path as xs:string,
  $original as item(),
  $prev-mirror-path as xs:string
  ) as xs:boolean {
  let $doc :=
    typeswitch($original)
    case document-node() return $original
    default return doc($original)
  let $collection := util:collection-name($doc)
  let $mirror-collection := mirror:mirror-path($mirror-path, $collection)
  let $prev-collection := mirror:mirror-path($prev-mirror-path, $collection)
  let $resource := util:document-name($doc)
  let $mirror-resource-name := mirror:map-resource-name($mirror-path, $resource)
  let $prev-resource-name := mirror:map-resource-name($prev-mirror-path, $resource)
  let $mirror-last-modified :=
    try {
        xmldb:last-modified($mirror-collection, $mirror-resource-name) 
    }
    catch * { () }
  let $prev-last-modified :=
    try {
        xmldb:last-modified($prev-collection, $prev-resource-name) 
    }
    catch * { () }
  return not(
    empty($mirror-last-modified) or
    empty($prev-last-modified) or
    ($mirror-last-modified < $prev-last-modified)
    )
};

declare function mirror:apply-if-outdated(
  $mirror-path as xs:string,
  $transformee as item(),
  $transform as function(node()*) as node()*
  ) as document-node()? {
  mirror:apply-if-outdated($mirror-path, $transformee, $transform, $transformee, ())
};

declare function mirror:apply-if-outdated(
  $mirror-path as xs:string,
  $transformee as item(),
  $transform as function(node()*) as node()*,
  $original as item()
  ) as document-node()? {
  mirror:apply-if-outdated($mirror-path, $transformee, $transform, $original, ())
};

(:~ apply a function or transform to the original, if the mirror is out of date,
 : otherwise return the mirror
 : @param $mirror-path Base of the mirror
 : @param $transformee Path or resource node to be transformed
 : @param $transform The transform to run, use a partial function to pass parameters
 : @param $original If $transformee is the result of intermediate processing, this should point to the actual original document
 : @param $up-to-date-function Additional function to pass to mirror:is-up-to-date 
 :) 
declare function mirror:apply-if-outdated(
  $mirror-path as xs:string,
  $transformee as item(),
  $transform as function(node()*) as node()*,
  $original as item(),
  $up-to-date-function as (function(xs:string, item()) as xs:boolean)?
  ) as document-node()? {
  if (mirror:is-up-to-date($mirror-path, $original, $up-to-date-function))
  then 
    mirror:doc(
      $mirror-path, 
      typeswitch($original)
      case $o as document-node() return document-uri($o)
      default $o return $o
    )
  else 
    let $transformee-doc := 
      typeswitch($transformee)
      case document-node() return $transformee
      default return doc($transformee)
    let $original-doc :=
      typeswitch($original)
      case document-node() return $original
      default return doc($original)
    let $collection := util:collection-name($original-doc)
    let $resource := util:document-name($original-doc)
    let $path := 
      mirror:store($mirror-path, $collection, $resource, 
                   $transform($transformee-doc)
                  )
    return doc($path)
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
  let $resource-name := mirror:map-resource-name($mirror-path, $resource)
  let $mirror-resource := concat($mirror-collection, "/", $resource-name) 
  return
    if (xmldb:store($mirror-collection, $resource-name, $data))
    then (
      mirror:mirror-permissions(
        $mirror-path,
        concat($collection, "/", $resource),
        $mirror-resource
        ),
      $mirror-resource
    )
    else () 
};

(:~ remove a resource from the given mirror
 : If there are no more mirror resources in the collection,
 : remove the collection
 : @param $mirror The mirror
 : @param $collection The collection where the resource is
 : @param $resource The resource 
 :)
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
      return mirror:clear-collections($mirror-collection, true())
    else
      (: remove a resource :)
      let $resource-name := mirror:map-resource-name($mirror, $resource)
      let $mirror-path := concat($mirror-collection, "/", $resource-name)
      let $exists := 
        util:binary-doc-available($mirror-path) or 
        doc-available($mirror-path)
      where $exists
      return (
        xmldb:remove($mirror-collection, $resource-name),
        mirror:clear-collections($mirror-collection, false())
      )      
};

(:~ clear cache collections :)
declare %private function mirror:clear-collections(
  $collection as xs:string,
  $allow-nonempty as xs:boolean
  ) as empty-sequence() {
  if (
    $allow-nonempty or
    empty(
      system:as-user("admin", $magic:password, 
        collection($collection)
      )
    )
  )
  then
    let $tokens := tokenize($collection, "/")
    return (
      system:as-user("admin", $magic:password, xmldb:remove($collection)),
      mirror:clear-collections(
        string-join(subsequence($tokens, 1, count($tokens) - 1), "/"),
        false()
      )
    )
  else ()
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
