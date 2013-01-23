(:~ 
 : API module for expanded XML:
 : expanded XML is a view or concurrent section with local pointers
 :  expanded
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace expanded = 'http://jewishliturgy.org/api/data/expanded';

import module namespace api="http://jewishliturgy.org/modules/api" 
  at "/db/code/api/modules/api.xqm";
import module namespace nav="http://jewishliturgy.org/modules/nav"
  at "nav.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "/db/code/modules/follow-uri.xqm";
  
declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

declare variable $expanded:allowed-methods := "GET";
declare variable $expanded:accept-content-type := (
  api:html-content-type(),
  api:tei-content-type(),
  api:xml-content-type()
  );
declare variable $expanded:request-content-type := ();
declare variable $expanded:test-source := "/code/tests/api/data/expanded.t.xml";

declare function expanded:title(
  $uri as xs:anyAtomicType
  ) as xs:string {
  "Expanded mode"
};

declare function expanded:allowed-methods(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $expanded:allowed-methods
};

declare function expanded:accept-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $expanded:accept-content-type
};

declare function expanded:request-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $expanded:request-content-type
};

declare function expanded:list-entry(
  $uri as xs:anyAtomicType
  ) as element(li) {
  api:list-item(
    element span {expanded:title($uri)},
    $uri,
    expanded:allowed-methods($uri),
    expanded:accept-content-type($uri),
    expanded:request-content-type($uri),
    ()
  )
};

declare function local:disallowed() {
  let $d := api:allowed-method($expanded:allowed-methods)
  where not($d)
  return api:error((), "Method not allowed")
};

declare function expanded:get() {
  let $test-result := api:tests($expanded:test-source)
  let $accepted := api:get-accept-format($expanded:accept-content-type)
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($test-result)
    then $test-result
    else 
      let $uri := request:get-uri()
      let $element := nav:api-path-to-sequence($uri)
      let $format := api:simplify-format($accepted, "tei")
      return
        if ($format instance of element(error))
        then $format
        else if ($format = ("xml", "tei"))
        then (
          api:serialize-as($format, $accepted),
          expanded:expanded($element)
        )
        else (
          api:serialize-as("xhtml", $accepted),
          let $list-body := (
            <ul class="common">{
              <li>Provides a formatted XML representation of 
              {replace($uri, "/-expanded$", "")} with all internal 
              pointers expanded</li>
            }</ul>,
            (: insert results here :) ()
          )
          return
            api:list(
              <title>{expanded:title($uri)}</title>,
              $list-body,
              count($list-body/self::ul[@class="results"]/li),
              false(),
              expanded:allowed-methods($uri),
              expanded:accept-content-type($uri),
              expanded:request-content-type($uri),
              $expanded:test-source
            )
        )
};

declare function expanded:put() {
  local:disallowed()
};

declare function expanded:post() {
  local:disallowed()
};

declare function expanded:delete() {
  local:disallowed()
};

declare function expanded:go(
  $sequence as element()
  ) {
  let $method := api:get-method()
  return
    if ($method = "GET")
    then expanded:get()
    else if ($method = "PUT") 
    then expanded:put()
    else if ($method = "POST")
    then expanded:post()
    else if ($method = "DELETE")
    then expanded:delete()
    else local:disallowed()
};

(:~ run the expanded mode transformation :)
declare function expanded:expanded(
  $node as node()*
  ) as node()* {
  for $n in $node
  return
    typeswitch($n)
    case document-node() return document { expanded:expanded($n/*) }
    case element(tei:ptr) return expanded:tei-ptr($n)
    case element() return expanded:element($n)
    case text() return $n
    default return $n
};

declare function expanded:element(
  $node as element()
  ) as element() {
  element { QName(namespace-uri($node), name($node)) }{
    $node/@*,
    expanded:expanded($node/*)
  }
};

declare function expanded:tei-ptr(
  $node as element(tei:ptr)
  ) as element() {
  let $targets := tokenize($node/@target, "\s+")
  return
    element tei:ptr {
      $node/@*,
      for $uri at $n in $targets
      let $target := 
        uri:fast-follow($node/@target, $node, 
          uri:follow-steps($node)) 
      return 
        if (every $t in $target satisfies root($t) is root($node))
        then expanded:expanded($target)
        else 
          element tei:ptr {
            attribute target { $targets[$n] }
          }
    }
};