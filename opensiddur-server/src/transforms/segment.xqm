xquery version "3.1";

(:~ The segmentation stage converts an incoming document with an unsegmented streamText into a
 : document with a streamText broken up by elements with xml:id
:)

module namespace segment = "http://jewishliturgy.org/transform/segment";

import module namespace common="http://jewishliturgy.org/transform/common" at "../modules/common.xqm";

declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

declare function segment:segment(
  $nodes as node()*
) {
  for $node in $nodes
  return
    typeswitch ($node)
      case element(j:streamText) return segment:j-streamText($node)
      case element() return
        element { QName(namespace-uri($node), name($node)) }{
          $node/@*,
          segment:segment($node/node())
        }
      case document-node() return document { segment:segment($node/node()) }
      default return $node
};

declare function segment:j-streamText(
  $e as element(j:streamText)
) as element(j:streamText) {
  element j:streamText {
    $e/@*,
    for $node in $e/node()
    return
      typeswitch ($node)
        case text() return
          let $normalized := normalize-space($node)
          return
            if ($normalized)
            then element jf:textnode {
              attribute xml:id { common:generate-id($node) },
              $normalized
            }
            else ()
        default return $node
  }
};
