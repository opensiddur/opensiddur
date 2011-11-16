(:~ 
 : Module to support search and search results
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace search = 'http://jewishliturgy.org/api/data/search';

import module namespace api="http://jewishliturgy.org/modules/api" 
  at "/code/api/modules/api.xqm";
import module namespace nav="http://jewishliturgy.org/modules/nav"
  at "nav.xqm";
import module namespace navdoc="http://jewishliturgy.org/api/data/navdoc"
  at "navdoc.xqm";
import module namespace navel="http://jewishliturgy.org/api/data/navel"
  at "navel.xqm";
import module namespace navat="http://jewishliturgy.org/api/data/navat"
  at "navat.xqm";
import module namespace orig="http://jewishliturgy.org/api/data/original"
  at "/code/api/data/original/original.xqm";
  
declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";

declare variable $search:allowed-methods := "GET";
declare variable $search:accept-content-type := (
  api:html-content-type(),
  api:xml-content-type(),
  api:tei-content-type()
  );
declare variable $search:request-content-type := ();
declare variable $search:test-source :=
  let $uri := request:get-uri()
  return
    if ($uri = "/code/api/data/original") 
    then $orig:test-source
    else "/code/api/data/search.t.xml";

declare function search:title(
  $uri as xs:anyAtomicType
  ) as xs:string {
  let $q := request:get-parameter("q", ())
  return
    if ($q)
    then concat("Search results: ", $q)
    else $uri
};

(: the root can be used to POST to a new document :)
declare function local:is-root(
  $uri as item()+
  ) as xs:boolean {
  $uri instance of xs:anyAtomicType
    and not(replace($uri, "^(/code/api/data)?/original(/)?", ""))
};

declare function search:allowed-methods(
  $uri as item()+
  ) as xs:string* {
  if (local:is-root($uri))
  then
    ("GET", "POST")
  else
    $search:allowed-methods
};

declare function search:accept-content-type(
  $uri as item()+
  ) as xs:string* {
  $search:accept-content-type
};

declare function search:request-content-type(
  $uri as item()+
  ) as xs:string* {
  if (local:is-root($uri))
  then
    (
      api:html-content-type(),
      api:xml-content-type(),
      api:tei-content-type()
    )
  else
    $search:request-content-type
};

declare function search:list-entry(
  $uri as xs:anyAtomicType
  ) as element(li) {
  api:list-item(
    element span {search:title($uri)},
    $uri,
    search:allowed-methods($uri),
    search:accept-content-type($uri),
    search:request-content-type($uri),
    ()
  )
};

declare function local:disallowed() {
  let $d := api:allowed-method($search:allowed-methods)
  where not($d)
  return api:error((), "Method not allowed")
};

declare function local:show-element(
  $result as element(),
  $format as xs:string
  ) as element() {
  if ($format = ("xml", "tei"))
  then $result
  else navel:list-entry(nav:sequence-to-api-path($result))
};

declare function local:show-attribute(
  $result as attribute(),
  $format as xs:string
  ) as element() {
  if ($format = ("xml", "tei"))
  then element jx:attribute-result {$result}
  else navat:list-entry(nav:sequence-to-api-path($result))
};

declare function local:show-document(
  $result as document-node(),
  $format as xs:string
  ) as element() {
  let $api-path := nav:sequence-to-api-path($result)
  return
    if ($format = ("xml", "tei"))
    then 
      element jx:document-ptr { 
        attribute target { $api-path } 
      }
    else navdoc:list-entry($api-path)
};

(:~ semi-internal function to display a set of search results
 : as 'xml', 'tei', or 'xhtml'
 :)
declare function search:show-results(
  $uri as xs:string,
  $results as node(),
  $format as xs:string
  ) {
  let $formatted-results := 
    for $result in $results
    return
      typeswitch($result)
      case element() return local:show-element($result, $format)
      case attribute() return local:show-attribute($result, $format)
      case document-node() return local:show-document($result, $format)
      default return ()
  return
    $formatted-results
};

declare function local:get-search-results(
  $uri as xs:string
  ) as item()* {
  let $q := request:get-parameter("q", ())
  let $seq := nav:api-path-to-sequence($uri)
  let $sequence :=
    typeswitch($seq)
    case document-node()+ return 
      if ($q)
      then $seq//(tei:title|tei:seg)
      else $seq
    default return $seq
  return 
    if ($q)
    then
      for $result in $sequence[ft:query(., $q)]
      order by ft:score($result) descending
      return $result
    else 
      for $result in $sequence
      order by (
        typeswitch ($result)
        case document-node() return string($result//tei:title[@type="main"])
        default return string($result)
      )
      return $result
};

declare function search:get() {
  let $test-result := api:tests($search:test-source)
  let $accepted := api:get-accept-format($search:accept-content-type)
  let $format := api:simplify-format($accepted, "xhtml")
  let $uri := request:get-uri()
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($test-result)
    then $test-result
    else 
      let $results := local:get-search-results($uri)
      let $start := xs:integer(request:get-parameter("start", 1))
      let $max-results := 
        xs:integer(request:get-parameter("max-results", $api:default-max-results))
      let $show := search:show-results(
        $uri,  
        subsequence($results, $start, $max-results), 
        $format)
      return
        (
        api:serialize-as($format, $accepted),
        if ($format = ("xml", "tei"))
        then 
          element tei:div {
            attribute type { "search-results" },
            attribute jx:start { $start},
            attribute jx:max-results { $max-results },
            attribute jx:n-results { count($results) },
            $show
          }
        else 
          let $list-body := (
            <ul class="results">{
              $show
            }</ul>
          )
          return
            api:list(
              <title>{search:title($uri)}</title>,
              $list-body,
              count($results),
              false(),
              search:allowed-methods($uri),
              search:accept-content-type($uri),
              search:request-content-type($uri),
              $search:test-source
            )
        )
};

declare function search:put() {
  local:disallowed()
};

declare function search:post() {
  let $uri := request:get-uri()
  return
    if (local:is-root($uri))
    then orig:post()
    else local:disallowed()
};

declare function search:delete() {
  local:disallowed()
};

declare function search:go(
  $sequence as item()*
  ) {
  let $method := api:get-method()
  return
    if ($method = "GET")
    then search:get()
    else if ($method = "PUT") 
    then search:put()
    else if ($method = "POST")
    then search:post()
    else if ($method = "DELETE")
    then search:delete()
    else local:disallowed()
};

