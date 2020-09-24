xquery version "3.1";
(:~ Transformation for JLPTEI files to 0.12.0+
 : Major changes:
 : 1. Remove `tei:seg` from inside `j:streamText`.
 : 2. All segments with references to them as the beginning of the range (or the only reference) should be replaced with `tei:anchor` before them.
 : 3. All segments with references to them as the end of the range (or only reference) should be replaced with `tei:anchor` after them;
 :    the range pointer should be changed to point to the end instead of the beginning.
 : 4. all internal and external pointers in `j:streamText` must point to `tei:anchor`
 :
 :)
module namespace upg12 = "http://jewishliturgy.org/modules/upgrade12";

import module namespace mirror = "http://jewishliturgy.org/modules/mirror"
  at "mirror.xqm";
import module namespace ridx = "http://jewishliturgy.org/modules/refindex"
  at "refindex.xqm";
import module namespace didx = "http://jewishliturgy.org/modules/docindex"
  at "docindex.xqm";
import module namespace uri = "http://jewishliturgy.org/transform/uri"
  at "follow-uri.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace j = "http://jewishliturgy.org/ns/jlptei/1.0";

(:~ upgrade all the documents in /db/data
 : first, create a mirror collection for /db/data, then run [[upg12:upgrade]] on all documents,
 : saving them to an equivalent location in the mirror.
 : when finished, remove /db/data and replace it with the mirror
 : remove the mirror file.
 : This function will only perform the operations if there are any j:streamText/tei:seg elements (a proxy for
 : databases that are not converted)
 :)
declare function upg12:upgrade-all() {
  if (exists(collection("/db/data")//j:streamText/tei:seg))
  then
    let $ridx-reindex := ridx:reindex(collection("/db/data"))
    let $didx-reindex := didx:reindex(collection("/db/data"))
    let $upgrade-mirror := "/db/upgrade"
    let $create-mirror := mirror:create($upgrade-mirror, "/db/data", false())
    let $upgrade :=
      for $resource in upg12:recursive-file-list("/db/data")
      return
        typeswitch ($resource)
        case element(collection) return (
          util:log("info", "Upgrading to 0.12.0: mirror " || $resource/@collection),
          mirror:make-collection-path($upgrade-mirror, $resource/@collection)
        )
        case element(resource) return
          if ($resource/@mime-type = "application/xml")
          then (
            util:log("info", "Upgrading to 0.12.0: " || $resource/@collection || "/" || $resource/@resource),
            mirror:store($upgrade-mirror, $resource/@collection, $resource/@resource,
              upg12:upgrade(doc($resource/@collection || "/" || $resource/@resource)))
          )
          else (
            (: not an XML file, just copy it :)
            util:log("info", "Copying for 0.12.0: " || $resource/@collection || "/" || $resource/@resource),
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
    util:log("info", "Not upgrading to 0.12.0: This database appears to already be upgraded.")
};

declare function upg12:recursive-file-list(
  $base-path as xs:string
) as element(resource)* {
  for $child-collection in xmldb:get-child-collections($base-path)
  let $uri := xs:anyURI($base-path || "/" || $child-collection)
  let $perms := sm:get-permissions($uri)
  return (
    <collection collection="{$base-path || "/" || $child-collection}"
      owner="{$perms/*/@owner/string()}"
      group="{$perms/*/@group/string()}"
      mode="{$perms/*/@mode/string()}"
      />,
    upg12:recursive-file-list($base-path || "/" || $child-collection)
  ),
  for $child-resource in xmldb:get-child-resources($base-path)
  let $uri := xs:anyURI($base-path || "/" || $child-resource)
  let $perms := sm:get-permissions($uri)
  let $mime-type := xmldb:get-mime-type($uri)
  return
    <resource collection="{$base-path}"
              resource="{$child-resource}"
              owner="{$perms/*/@owner/string()}"
              group="{$perms/*/@group/string()}"
              mode="{$perms/*/@mode/string()}"
              mime-type="{$mime-type}"
    />
};

(:~ upgrade a document file :)
declare function upg12:upgrade(
  $nodes as node()*
) {
  for $node in $nodes
  return
    typeswitch($node)
      case document-node() return document { upg12:upgrade($node/node()) }
      case element(j:streamText) return upg12:j-streamText($node)
      case element() return upg12:upgrade-ptrs($node)
      case text() return $node
      default return $node
};

(:~ this transform is intended to be called on any element with @target|@targets
 : it will copy the element and update the target according to the following rules:
 : (1) if the target is a range ptr, all ends that are segments inside j:streamText will be rewritten
 : such that beginnings of segments maintain the same xml:id and ends of segments have the xml:id with _end appended
 :)
declare function upg12:upgrade-ptrs(
  $elements as element()*
) {
  for $element in $elements
  return
    element { QName(namespace-uri($element), name($element))} {
      $element/(@* except @target|@targets),
      if ($element/(@target|@targets))
      then
        attribute {
          name($element/(@target|@targets))
        }{
          string-join(
            for $target in tokenize(string($element/(@target | @targets)), '\s+')
            return
              if (matches($target, "^http[s]?[:]"))
              then
                (: do not follow external links :)
                $target
              else
                let $target-nodes := uri:fast-follow($target, $element, 0)
                let $first-target-node-seg := $target-nodes[1][self::tei:seg][ancestor::j:streamText]
                let $last-target-node-seg := $target-nodes[last()][self::tei:seg][ancestor::j:streamText]
                let $first-is-last := $first-target-node-seg is $last-target-node-seg
                return
                  if (exists($first-target-node-seg) or exists($last-target-node-seg))
                  then
                    let $document-part := substring-before($target, "#")
                    let $fragment-ptr := substring-after($target, "#")
                    let $fragment-start :=
                      if (starts-with($fragment-ptr, "range("))
                      then substring-before(substring-after($fragment-ptr, "("), ",")
                      else $fragment-ptr
                    let $fragment-end :=
                      if (starts-with($fragment-ptr, "range("))
                      then substring-before(substring-after($fragment-ptr, ","), ")")
                      else $fragment-ptr
                    return concat($document-part, "#",
                      (
                        if ($first-is-last)
                        then
                          if (exists($first-target-node-seg))
                          then
                            (: a single segment becomes a range pointer :)
                            "range(" || $fragment-start || "," || $fragment-start || "_end)"
                          else
                            (: not a segment, no change :)
                            $fragment-ptr
                        else
                        (: a range pointer has to be rewritten-- if the end is a segment inside a streamText :)
                          "range(" || $fragment-start || "," || $fragment-end || (
                            if ($last-target-node-seg)
                            then "_end"
                            else ""
                          ) || ")"
                      )
                    )
                  else $target,
            " "
          )
        }
      else (),
      upg12:upgrade($element/node())
    }
};



(:~ upgrade j:streamText
 : 1. run the special operations for tei:seg
 : 2. join adjacent text nodes
 :)
declare function upg12:j-streamText(
  $e as element(j:streamText)
) as element(j:streamText) {
  element j:streamText {
    $e/@*,
    for $node in $e/node()
    return
      typeswitch($node)
        case element(tei:seg) return upg12:tei-seg($node)
        case element() return upg12:upgrade-ptrs($node)
        default return $node
  }
};

declare function upg12:tei-seg(
  $node as element(tei:seg)
) as item()+ {
  upg12:tei-seg($node, ridx:query-all($node))
};

(:~ a segment inside a streamText will be surrounded by anchors if there are existing references to the
 : beginning or end of the element.
 :)
declare function upg12:tei-seg(
  $node as element(tei:seg),
  $references as element()*
) as item()+ {
  let $xmlid := $node/@xml:id
  let $end-xmlid := concat($xmlid, "_end")
  let $references :=
    distinct-values(
      for $reference in $references
      for $target in tokenize(string($reference/(@target | @targets)), '\s+')
      let $target-nodes := uri:fast-follow($target, $reference, 1)
      let $i-am-first-target := $target-nodes[1] is $node
      let $i-am-last-target := $target-nodes[last()] is $node
      return (
        if ($i-am-first-target) then "first" else (),
        if ($i-am-last-target) then "last" else ()
      )
    )
  return (
    if ($references = "first")
    then
      element tei:anchor {
        attribute xml:id {$xmlid}
      }
    else (),
    upg12:upgrade-inside-seg($node/node()),
    if ($references = "last")
    then
      element tei:anchor {
        attribute xml:id {$end-xmlid}
      }
    else (),
    " "
  )
};

declare function upg12:upgrade-inside-seg(
  $nodes as node()*
) {
  $nodes
};
