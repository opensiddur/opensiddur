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

import module namespace ridx = "http://jewishliturgy.org/modules/refindex"
at "refindex.xqm";
import module namespace uri = "http://jewishliturgy.org/transform/uri"
at "follow-uri.xqm";
import module namespace data = "http://jewishliturgy.org/modules/data"
at "data.xqm";

declare namespace error="http://jewishliturgy.org/errors";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace j = "http://jewishliturgy.org/ns/jlptei/1.0";

(:~ upgrade a document file :)
declare function upg12:upgrade(
  $nodes as node()*
) {
  for $node in $nodes
  return
    typeswitch($node)
      case document-node() return document { upg12:upgrade($node/node()) }
      case element(j:streamText) return upg12:j-streamText($node)
      case element() return
        element { QName(namespace-uri($node), name($node))} {
          $node/@*,
          upg12:upgrade($node/node())
        }
      case text() return $node
      default return $node
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
        default return $node
  }
};

declare function upg12:tei-seg(
  $node as element(tei:seg)
) as item()+ {
  upg12:tei-seg($node, ridx:query-all($node))
};

declare function upg12:tei-seg(
  $node as element(tei:seg),
  $references as element()*
) as item()+ {
  let $xmlid := $node/@xml:id
  let $end-xmlid := concat($xmlid, "_end")
  let $updated-references as element(upg12:target)* :=
    for $reference-element in $references
    let $new-references := upg12:update-references($reference-element, $node)
    let $rewritten := upg12:rewrite-target($reference-element/(@target | @targets), $new-references)
    return $new-references
  return (
    if (exists($updated-references/upg12:begin))
    then
      element tei:anchor {
        attribute xml:id {$xmlid}
      }
    else (),
    upg12:upgrade-inside-seg($node/node()),
    if (exists($updated-references/upg12:end))
    then
      element tei:anchor {
        attribute xml:id {$end-xmlid}
      }
    else ()
  )
};

declare function upg12:upgrade-inside-seg(
  $nodes as node()*
) {
  $nodes
};

(:~ update the references to $referred-element in $referring-element.
 : Code is heavily copied from @see uri:fast-follow
 :
 : @return an element(upg12:targets) with one child for each target
 :      if there
 :)
declare function upg12:update-references(
  $referring-element as element(),
  $referred-element as element()
) as element()+ {
  for $target in tokenize(string($referring-element/(@target | @targets)), '\s+')
  let $document-part := substring-before($target, '#')
  let $absolute-uri := uri:absolutize-uri($target, $referring-element)
  let $resource-ptr := uri:uri-base-path($absolute-uri)
  let $fragment-ptr := uri:uri-fragment($absolute-uri)
  let $referred-document as document-node()? :=
    try {
      data:doc($resource-ptr)
    }
    catch error:NOTIMPLEMENTED {
    (: the requested path is not in /data :)
      doc($resource-ptr)
    }
  return
    <upg12:target>{
      if ($referred-document is root($referred-element) and $fragment-ptr)
      then
      (: only potentially need to change references if the reference is to $referred-element itself :)
        let $fragment-start :=
          if (starts-with($fragment-ptr, "range("))
          then substring-before(substring-after($fragment-ptr, "("), ",")
          else $fragment-ptr
        let $fragment-end :=
          if (starts-with($fragment-ptr, "range("))
          then substring-after(substring-after($fragment-ptr, "("), ",")
          else $fragment-ptr
        return
          if (not(($fragment-start, $fragment-end) = $referred-element/@xml:id))
          then
            <upg12:same>{$target}</upg12:same>
          else (
            <upg12:document>{$document-part}</upg12:document>,
            if ($fragment-start = $referred-element/@xml:id)
            then <upg12:begin>{$referred-element/@xml:id/string()}</upg12:begin>
            else <upg12:begin>{$fragment-start}</upg12:begin>,
            if ($fragment-end = $referred-element/@xml:id)
            then <upg12:end>{concat($referred-element/@xml:id/string(), "_end")}</upg12:end>
            else <upg12:end>{$fragment-end}</upg12:end>
          )
      else <upg12:same>{$target}</upg12:same>
    }</upg12:target>
};

declare function upg12:rewrite-target(
  $target as attribute(),
  $updated-references as element()+
) {
  update replace $target with
    attribute {name($target)}{
      string-join(
        for $target-element in $updated-references
        let $same := $target-element/upg12:same
        let $document := $target-element/upg12:document
        let $begin := $target-element/upg12:begin
        let $end := $target-element/upg12:end
        return
          if ($same)
          then string($same)
          else
            string-join(($document, "#",
              if ($begin = $end) then $begin
              else ("range(", $begin, ",", $end, ")")
              ), ""
            )
      , " ")
  }
} ;
