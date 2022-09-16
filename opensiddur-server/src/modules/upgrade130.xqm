xquery version "3.1";
(:~ Transformation for JLPTEI files to 0.13.0+
 : Major changes:
 : 1. Move all files from YYYY/MM directories into the root directory
 :
 :)
module namespace upg13 = "http://jewishliturgy.org/modules/upgrade130";

import module namespace mirror = "http://jewishliturgy.org/modules/mirror"
  at "mirror.xqm";
import module namespace ridx = "http://jewishliturgy.org/modules/refindex"
  at "refindex.xqm";
import module namespace didx = "http://jewishliturgy.org/modules/docindex"
  at "docindex.xqm";
import module namespace uri = "http://jewishliturgy.org/transform/uri"
  at "follow-uri.xqm";
import module namespace upg12="http://jewishliturgy.org/modules/upgrade12"
  at "upgrade12.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace j = "http://jewishliturgy.org/ns/jlptei/1.0";

(:~ upgrade all the documents in /db/data
 : first, create a mirror collection for /db/data, then run [[upg13:upgrade]] on all documents,
 : saving them to an equivalent location in the mirror.
 : when finished, remove /db/data and replace it with the mirror
 : remove the mirror file.
 :)
declare function upg13:upgrade-all() {
  if (exists(xmldb:get-child-collections("/db/data/original/en")))
  then
    let $upgrade-mirror := "/db/upgrade13"
    let $create-mirror := mirror:create($upgrade-mirror, "/db/data", false())
    let $upgrade :=
      (: use the function from upg12 to list files... :)
      for $resource in upg12:recursive-file-list("/db/data")
      return
        typeswitch ($resource)
        case element(collection) return (
          let $to-create := tokenize($resource/@collection, "/")[.][last()]
          return
            if (matches($to-create, "^\d+$"))
            then
                util:log("info", "Upgrading to 0.13.0: Not mirroring " || $resource/@collection)
            else (
                util:log("info", "Upgrading to 0.13.0: mirror " || $resource/@collection),
                mirror:make-collection-path($upgrade-mirror, $resource/@collection)
            )
        )
        case element(resource) return
          let $destination-collection := replace($resource/@collection, "[/]\d+[/]\d+", "")
          let $log := util:log("info", "Copying for 0.13.0: " || $resource/@collection || "/" || $resource/@resource || " to " || $destination-collection)
          return
            xmldb:copy-resource($resource/@collection, $resource/@resource, mirror:mirror-path($upgrade-mirror, $destination-collection), $resource/@resource)
        default return ()
    let $unmirror := xmldb:remove($upgrade-mirror, $mirror:configuration)
    let $destroy := xmldb:remove("/db/data")
    let $move := xmldb:rename($upgrade-mirror, "data")
    (: the entire /db/data directory has been wiped and all indexes are inconsistent. Completely remake them. :)
    let $didx-delete := xmldb:remove($didx:didx-path)
    let $ridx-delete := xmldb:remove($ridx:ridx-path)
    let $didx-resetup := didx:setup()
    let $ridx-resetup := ridx:setup()
    let $didx-reindex := didx:reindex(collection("/db/data"))
    let $ridx-reindex := ridx:reindex(collection("/db/data"))
    let $reindex := xmldb:reindex("/db/data")
    return ()
  else
    util:log("info", "Not upgrading to 0.13.0: This database appears to already be upgraded.")
};
