xquery version "3.1";

(:~ Functions to test for deep XML equality.
  :
  : Copyright 2019 Efraim Feinstein, Open Siddur Project
  : Licensed under the GNU Lesser General Public License, version 3 or later
  :)

module namespace deepequality = "http://jewishliturgy.org/modules/deepequality";

(:~ compare two nodes. If the result is not deep equal to expected according to [[deepequality:equal-wildcard]],
 : return the result, otherwise, return empty
 :)
declare function deepequality:equal-or-result(
  $result as node()*,
  $expected as node()*
) as node()* {
  let $is-equal := deepequality:equal-wildcard($result, $expected)
  where not($is-equal)
  return $result
};

(:~ determine if two nodes are equal, allowing for the string ... to be a wildcard
 : and the namespace http://www.w3.org/1998/xml/namespace/alias to be equivalent to the
 : xml namespace
 : @param $node1 The original node
 : @param $node2 The expectation node, which may include aliased namespaces and wildcards
 :)
declare function deepequality:equal-wildcard(
  $node1 as node()*,
  $node2 as node()*
) as xs:boolean {
  let $n1 := deepequality:clean-xml($node1)
  let $n2 := deepequality:clean-xml($node2)
  return
    (
      count($n1) = count($n2)
        and
        (every $result in
        (
          for $n at $pos in $n1
          return
            typeswitch ($n)
              case document-node() return deepequality:docnode($n, $n2[$pos])
              case comment() return deepequality:comment($n, $n2[$pos])
              case text() return deepequality:text($n, $n2[$pos])
              case attribute() return deepequality:attribute($n, $n2)
              case element() return deepequality:element($n, $n2[$pos])
              default return false()
        )
        satisfies $result
        )
    )
};

(: clean up empty text nodes from XML :)
declare %private function deepequality:clean-xml(
  $nodes as node()*
) as node()* {
  for $node in $nodes
  return
    typeswitch($node)
      case text() return
        if (normalize-space($node))
        then $node
        else ()
      case document-node() return
        document {
          deepequality:clean-xml($node/node())
        }
      case element() return
        element { QName(namespace-uri($node), name($node)) }{
          $node/@*,
          deepequality:clean-xml($node/node())
        }
      default return $node
};


declare function deepequality:docnode(
  $node1 as document-node(),
  $node2 as node()
) as xs:boolean {
  ($node2 instance of document-node()) and
    deepequality:equal-wildcard($node1/node(), $node2/node())
};

declare function deepequality:comment(
  $node1 as comment(),
  $node2 as node()
) as xs:boolean {
  ($node2 instance of comment()) and (
    string($node1) = string($node2)
      or string($node2) = '...'
  )
};

declare function deepequality:text(
  $node1 as text(),
  $node2 as node()
) as xs:boolean {
  ($node2 instance of text()) and (
    string($node1) = string($node2)
      or string($node2) = '...'
  )
};

declare function deepequality:attribute(
  $node1 as attribute(),
  $node2 as attribute()*
) as xs:boolean {
  let $equivalent :=
    $node2[
    (
      namespace-uri(.) = namespace-uri($node1)
        or
        namespace-uri(.) = 'http://www.w3.org/1998/xml/namespace/alias' and
          namespace-uri($node1) = 'http://www.w3.org/1998/xml/namespace'
    )
      and local-name(.) = local-name($node1)
    ]
  return exists($equivalent) and (
    string($equivalent) = (string($node1), '...')
  )
};

declare function deepequality:element(
  $node1 as element(),
  $node2 as node()
) as xs:boolean {
  ($node2 instance of element()) and
    namespace-uri($node1) = namespace-uri($node2) and
    local-name($node1) = local-name($node2) and
    deepequality:equal-wildcard($node1/@*, $node2/@*) and
    (
      (count($node2/node()) = 1 and string($node2) = '...') or
        deepequality:equal-wildcard($node1/node(), $node2/node())
    )
};
