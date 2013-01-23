(:~ 
 : Module to support search and search results
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace search = 'http://jewishliturgy.org/api/data/search';

import module namespace api="http://jewishliturgy.org/modules/api" 
  at "/db/code/api/modules/api.xqm";
import module namespace nav="http://jewishliturgy.org/modules/nav"
  at "nav.xqm";
import module namespace navdoc="http://jewishliturgy.org/api/data/navdoc"
  at "navdoc.xqm";
import module namespace navel="http://jewishliturgy.org/api/data/navel"
  at "navel.xqm";
import module namespace navat="http://jewishliturgy.org/api/data/navat"
  at "navat.xqm";
import module namespace orig="http://jewishliturgy.org/api/data/original"
  at "/db/code/api/data/original/original.xqm";
import module namespace kwic="http://exist-db.org/xquery/kwic";
  
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

declare function local:show-result-context(
  $list-entry as element(li),
  $context as item()
  ) as element(li) {
  element li {
    $list-entry/(@*|node()),
    let $c := $context
    where not($c instance of element(search:empty))
    return 
      element { QName(namespace-uri($c), name($c)) }{
        attribute class { "result-context" },
        $c/(@*|node())
      }
  }
};

declare function local:show-element(
  $result as element(),
  $context as item(),
  $format as xs:string
  ) as element() {
  if ($format = ("xml", "tei"))
  then $result
  else local:show-result-context(
    navel:list-entry(nav:sequence-to-api-path($result)),
    $context
    )
};

declare function local:show-attribute(
  $result as attribute(),
  $context as item(),
  $format as xs:string
  ) as element() {
  if ($format = ("xml", "tei"))
  then element jx:attribute-result {$result}
  else local:show-result-context(
    navat:list-entry(nav:sequence-to-api-path($result)),
    $context
    )
};

declare function local:show-document(
  $result as document-node(),
  $context as item(),
  $format as xs:string
  ) as element() {
  let $api-path := nav:sequence-to-api-path($result)
  return
    if ($format = ("xml", "tei"))
    then 
      element jx:document-ptr { 
        attribute target { $api-path } 
      }
    else local:show-result-context(
      navdoc:list-entry($api-path),
      $context
      )
};

(: show the document that the result came from.
 : 
 :)
declare function local:show-result-document(
  $result-item as element(), 
  $result as item(),
  $format as xs:string
  ) {
  element {QName(namespace-uri($result-item), name($result-item))}{
    $result-item/(@*|node()),
    let $result-document := nav:db-path-to-api-path(document-uri(root($result)), ())
    return
      if ($format = ("xml", "tei"))
      then
        element jx:document-ptr { 
          attribute target { $result-document } 
        }
      else 
        element ul {
          attribute class { "result-document" },
          navdoc:list-entry($result-document)
        }
  }
};

(:~ semi-internal function to display a set of search results
 : as 'xml', 'tei', or 'xhtml'
 : $seq is the uri of the search call or the sequence
 :)
declare function search:show-results(
  $seq as item()*,
  $results as item()*,
  $format as xs:string
  ) {
  let $sequence := 
    if ($seq instance of xs:anyAtomicType)
    then nav:api-path-to-sequence($seq)
    else $seq 
  for $result at $n in $results
  let $result-context := subsequence($results, $n + 1, 1)
  where ($n mod 2) = 1
  return
    let $result-entry :=
      typeswitch($result)
      case element() return local:show-element($result, $result-context, $format)
      case attribute() return local:show-attribute($result, $result-context, $format)
      case document-node() return local:show-document($result, $result-context, $format)
      default return ()
    where $result-entry
    return
      if ($sequence instance of document-node()+)
      then
        local:show-result-document($result-entry, $result, $format)
      else $result-entry
};

(: get the search results given the sequence pointed to by
 : the API's URI.
 : Return the results in the form:
 :  (result1, context1, result2, context2...)
 : If no context is available, return <search:empty/> as the context 
 :)
declare function local:get-search-results(
  $seq as item()*
  ) as item()* {
  let $q := request:get-parameter("q", ())
  let $sequence :=
    typeswitch($seq)
    case document-node()+ return 
      if ($q)
      then $seq//(tei:title|tei:seg)
      else $seq
    default return $seq
  let $empty-result := <search:empty/>
  let $return-value := 
    if ($q)
    then
      let $owner := request:get-parameter("owner", ())
      let $group := request:get-parameter("group", ())
      for $result in $sequence[ft:query(., $q)]
        [if ($owner) then xmldb:get-owner(.)=$owner else true()]
        [ if ($group) 
          then 
            xmldb:get-group(util:collection-name(.), util:document-name(.))=$group
          else true()
        ][.]
      let $sum := kwic:summarize($result, <config xmlns="" width="40"/>)
      let $summary := 
        if (exists($sum))
        then 
          (: kwic returns no-namespace! :)
          element p {
            for $span in $sum/*
            return element span { $span/(@*|node()) }
          }
        else $empty-result
      (: WARNING: order by results in *missing elements* -- requires investigation :)
      (:order by ft:score($result) descending:)
      return ($result, $summary)
    else 
      for $result in $sequence
      (:
      order by (
        typeswitch ($result)
        case document-node() return string($result//tei:title[@type="main"])
        default return string($result)
      )
      :)
      return ($result, $empty-result)
  return (
    $return-value,
    util:log-system-out(("***Return value=", $return-value))
  )
};

declare function search:get() {
  let $test-result := api:tests($search:test-source)
  let $accepted := api:get-accept-format($search:accept-content-type)
  let $format := api:simplify-format($accepted, "xhtml")
  let $uri := request:get-uri()
  let $seq := nav:api-path-to-sequence($uri)
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($test-result)
    then $test-result
    else 
      let $results  := local:get-search-results($seq)
      let $start := xs:integer(request:get-parameter("start", 1))
      let $max-results := 
        xs:integer(request:get-parameter("max-results", $api:default-max-results))
      let $show := search:show-results(
        $seq,
        subsequence($results, ($start * 2) - 1, ($max-results * 2)), 
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
            attribute jx:n-results { count($results) div 2 },
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
              count($results) div 2,
              true(),
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

