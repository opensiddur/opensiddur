xquery version "3.1";

(:~ Upgrade transition for 0.12.2:
 : Reduce the number of elements in j:streamText
 :)

module namespace upgrade122 = "upgrade122.xqm";

import module namespace ridx="http://jewishliturgy.org/modules/refindex" at "refindex.xqm";
import module namespace upg12 = "http://jewishliturgy.org/modules/upgrade12" at "upgrade12.xqm";
import module namespace mirror = "http://jewishliturgy.org/modules/mirror"  at "mirror.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

(:~ upgrade all the documents in /db/data
 : first, create a mirror collection for /db/data, then run [[upgrade122:upgrade122]] on all documents,
 : saving them to an equivalent location in the mirror.
 : when finished, remove /db/data and replace it with the mirror
 : remove the mirror file.
 : This function will only perform the operations if there are any j:streamText/tei:pc elements (a proxy for
 : databases that are not converted)
 :)
declare function upgrade122:upgrade-all() {
  if (exists(collection("/db/data")//j:streamText/tei:pc))
  then
    let $ridx-reindex := ridx:reindex(collection("/db/data"))
    let $upgrade-mirror := "/db/upgrade"
    let $create-mirror := mirror:create($upgrade-mirror, "/db/data", false())
    let $upgrade :=
      for $resource in upg12:recursive-file-list("/db/data")
      return
        typeswitch ($resource)
          case element(collection) return (
            util:log("info", "Upgrading to 0.12.2: mirror " || $resource/@collection),
            mirror:make-collection-path($upgrade-mirror, $resource/@collection)
          )
          case element(resource) return
            if ($resource/@mime-type = "application/xml")
            then (
              util:log("info", "Upgrading to 0.12.2: " || $resource/@collection || "/" || $resource/@resource),
              mirror:store($upgrade-mirror, $resource/@collection, $resource/@resource,
                upgrade122:upgrade122(doc($resource/@collection || "/" || $resource/@resource)))
            )
            else (
            (: not an XML file, just copy it :)
            util:log("info", "Copying for 0.12.2: " || $resource/@collection || "/" || $resource/@resource),
            xmldb:copy($resource/@collection, mirror:mirror-path($upgrade-mirror, $resource/@collection), $resource/@resource)
            )
          default return ()
    let $unmirror := xmldb:remove($upgrade-mirror, $mirror:configuration)
    let $destroy := xmldb:remove("/db/data")
    let $move := xmldb:rename($upgrade-mirror, "data")
    let $ridx-reindex := ridx:reindex(collection("/db/data"))
    let $reindex := xmldb:reindex("/db/data")
    return ()
  else
    util:log("info", "Not upgrading to 0.12.2: This database appears to already be upgraded.")
};


declare function upgrade122:upgrade122(
  $nodes as node()*
) as node()* {
  for $node in $nodes
  return
    typeswitch($node)
      case document-node() return document { upgrade122:upgrade122($node/node()) }
      case element(j:streamText) return upgrade122:j-streamText($node)
      case element() return
        element { QName(namespace-uri($node), name($node))}{
          $node/@*,
          upgrade122:upgrade122($node/node())
        }
      default return $node

};

(:~ @return true() if any of $ref contain a literal reference to the element with id $xmlid, otherwise false() :)
declare %private function upgrade122:is-literal-reference(
  $ref as element()*,
  $xmlid as xs:string
) as xs:boolean {
  let $all-reference-strings := string-join($ref/(@target|@targets), " ")
  let $all-reference-ids := tokenize($all-reference-strings, "[\s,()#]+")
  return $all-reference-ids=$xmlid
};

declare function upgrade122:j-streamText(
  $e as element(j:streamText)
) as element(j:streamText) {
  element { QName(namespace-uri($e), name($e)) }{
    $e/@*,
    for $child in $e/node()
    return
      typeswitch($child)
      case element() return
        let $refs := ridx:query-all($child, (), false())
        return
          if (
            ($child/@xml:id and exists($refs) and upgrade122:is-literal-reference($refs, $child/@xml:id))
            or (exists($child/element()))
          )
          then $child
          else $child/node()
      case text() return
        if (normalize-space($child))
        then
          (: something other than whitespace :)
          $child
        else
          (: all whitespace :)
          if (
            $child/preceding-sibling::*[1]='&#x5be;'
            or $child/following-sibling::*[1]=('&#x5c3;', '&#x5be;')) then (
          (: maqaf should always be connected to following and preceding word
            sof pasuq should be connected to preceding word.
          :))
          else text { " " }
      default return $child
  }
};