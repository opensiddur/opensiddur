xquery version "3.0";
(:~ mirror collections
 :
 : A mirror collection is a collection intended to cache some
 : aspect of another collection, maintaining the same directory
 : structure and permissions
 :
 : Open Siddur Project
 : Copyright 2011-2012 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later 
 :)
module namespace mirror = 'http://jewishliturgy.org/modules/mirror';

import module namespace app="http://jewishliturgy.org/modules/app"
  at "xmldb:exist:///code/modules/app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "xmldb:exist:///code/modules/debug.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:///code/magic/magic.xqm";

declare namespace error="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";

(:~ given a path, return the mirror path :)
declare function mirror:mirror-path(
  $mirror as xs:string,
  $path as xs:string
  ) as xs:string {
  let $mirror-no-db := replace($mirror, "^/db", "")
  let $path-no-db := replace($path, "^/db", "")
  let $base-paths := tokenize($mirror-no-db,"/")
  let $base-path := string-join(subsequence($base-paths, 1, count($base-paths) - 1), "/")
  return app:concat-path(("/", $mirror-no-db, replace($path-no-db, 
        concat("^(", $base-path, ")?"), 
        ""))[.])
};

declare function mirror:unmirror-path(
  $mirror as xs:string,
  $mirrored-path as xs:string
  ) as xs:string {
  let $mirror-no-db := replace($mirror, "^/db", "")
  let $tokens := tokenize($mirror-no-db, "/")
  let $mirrored-path-no-db := replace($mirrored-path, "^/db", "")
  let $unmirror := string-join(subsequence($tokens, 1, count($tokens) - 1), "/")
  return
    app:concat-path(("/", $unmirror, substring-after($mirrored-path-no-db, $mirror-no-db))[.])
};

(:~ make a mirror collection path that mirrors the same path in 
 : the normal /db hierarchy 
 : @param $mirror the location of the mirror
 : @param $path the path that should be mirrored (relative to /db)
 :)
declare function mirror:make-collection-path(
  $mirror as xs:string,
  $path as xs:string
  ) as empty-sequence() {
  let $unmirror-base := mirror:unmirror-path($mirror, $mirror)
  let $mirrored-path := mirror:mirror-path($mirror, $path)
  let $steps := tokenize(substring-after($mirrored-path, $unmirror-base), '/')[.]
  for $step in 1 to count($steps)
  let $this-step := 
    app:concat-path(($unmirror-base, subsequence($steps, 2, $step - 1)))
  let $mirror-this-step := mirror:mirror-path($mirror,$this-step)
  let $mirror-previous-step := app:concat-path(($unmirror-base, subsequence($steps, 1, $step - 1)))
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
      else error(xs:QName('error:CREATE'), concat('Cannot create index collection ', $this-step))
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
  $mirror as xs:string, 
  $original as item(),
  $up-to-date-function as function(xs:string, item()) as xs:boolean??
  ) as xs:boolean {
  let $original-doc := 
    typeswitch($original)
    case document-node() return $original
    default return doc($original)
  let $collection := util:collection-name($original-doc)
  let $resource := util:document-name($original-doc)
  let $mirror-collection := mirror:mirror-path($mirror, $collection) 
  let $last-modified := xmldb:last-modified($collection, $resource)
  let $mirror-last-modified := xmldb:last-modified($mirror-collection, $resource) 
  return
    (
      if (exists($up-to-date-function))
      then boolean($up-to-date-function($mirror, $original))
      else true()
    ) and
    not(
      empty($last-modified) or 
      empty($mirror-last-modified) or 
      ($last-modified > $mirror-last-modified)
    )
};

declare function mirror:is-up-to-date(
  $mirror as xs:string,
  $original as item()
  ) as xs:boolean {
  mirror:is-up-to-date($mirror, $original, ())
};

(:~ store data in a mirror collection :)
declare function mirror:store(
  $mirror as xs:string,
  $collection as xs:string,
  $resource as xs:string,
  $data as item()+
  ) as xs:string? {
  let $mirror-collection := mirror:mirror-path($mirror, $collection)
  let $make :=  
    system:as-user("admin", $magic:password, 
      mirror:make-collection-path($mirror, $collection)
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