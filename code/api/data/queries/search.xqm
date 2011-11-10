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
declare variable $search:test-source := "/code/api/data/search.t.xml";

declare function search:title(
  $uri as xs:anyAtomicType
  ) as xs:string {
  let $q := request:get-parameter("q", ())
  return
    if ($q)
    then concat("Search results: ", $q)
    else $uri
};

declare function search:allowed-methods(
  $uri as item()+
  ) as xs:string* {
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
  (: This probably needs no changes :)
  api:allowed-method($search:allowed-methods),
  api:error((), "Method not allowed")
};

(:
declare function local:get(
  $path as xs:string
  ) as item() {
  let $path-parts := data:path-to-parts($path)
  let $db-path := data:api-path-to-db($path)
  let $top-level :=
    if (string($path-parts/data:resource))
    then 
      if (doc-available($db-path)) 
      then doc($db-path)
      else api:error(404, "Document not found or inaccessible", $db-path)
    else if (string($path-parts/data:owner))
    then collection($db-path)
    else
       no owner, top identifiable level is share-type 
      collection(concat('/',$path-parts/data:share-type))
  let $collection :=
    if ($top-level instance of document-node())
    then util:collection-name($top-level)
    else if (string($path-parts/data:owner))
    then $db-path
    else concat('/',$path-parts/data:share-type)
  return
    if ($top-level instance of element(error))
    then (
      api:serialize-as('xml'), 
      $top-level
    )
    else if (string($path-parts/data:subresource) and not($path-parts/data:subresource = $local:valid-subresources))
    then (
      api:serialize-as('xml'),
      api:error(404, "Invalid subresource", string($path-parts/data:subresource))
    )
    else 
      let $query := request:get-parameter('q', ())
      let $start := xs:integer(request:get-parameter('start', 1))
      let $max-results := 
        xs:integer(request:get-parameter('max-results', $api:default-max-results))
      let $subresource := $path-parts/data:subresource/string()
      let $uri := request:get-uri()
      let $results :=
        if (false() (-scache:is-up-to-date($collection, $uri, $query)-))
        then 
          scache:get-request($uri, $query)
        else
          scache:store($uri, $query,
            <ul class="results">{ 
              for $result in (
                if ($subresource)
                then
                  (- subresources -)
                  if ($subresource = 'title')
                  then 
                    if ($path-parts/data:purpose = 'output')
                    then $top-level//html:title[ft:query(.,$query)]
                    else $top-level//tei:title[ft:query(.,$query)]
                  else if ($subresource = 'repository')
                  then $top-level//j:repository[ft:query(.,$query)]
                  else $top-level//tei:seg[ft:query(.,$query)]
                else if ($path-parts/data:purpose = 'output')
                then
                  (- HTML based -- TODO: what happens when we have non-HTML output? -)
                  $top-level//html:body[ft:query(., $query)]
                else
                  (- TEI-based -)
                  $top-level//(j:repository|tei:title)[ft:query(., $query)]
              )
              let $root := root($result)
              let $doc-uri := document-uri($root)
              let $title := $root//(tei:title[@type='main' or not(@type)]|html:title)
              let $title-lang := string($title/ancestor-or-self::*[@xml:lang][1]/@xml:lang)
              let $formatted-result := local:result-with-lang($result)
              let $desc := (
                (- desc contains the document title and the context of the search result -)
                <span>{
                  if ($title-lang)
                  then (
                    attribute lang {$title-lang},
                    attribute xml:lang {$title-lang}
                  ) 
                  else (),
                  normalize-space($title)
                }</span>,
                $formatted-result
              )
              let $api-doc := data:db-path-to-api($doc-uri)
              let $link := 
                if ($subresource)
                then concat($api-doc, '/', if ($subresource='seg') then concat('id/', $result/@xml:id) else $subresource)
                else $api-doc
              let $alt := ( 
                if ($path-parts/data:purpose = "output")
                then (
                  "xhtml", concat($api-doc, ".xhtml"),
                  "css", concat($api-doc, ".css"),
                  "status", concat($api-doc, "/status")
                )
                else (), 
                ('db', $doc-uri)
              )
              let $supported-methods := (
                "GET",
                ("POST")[$subresource = ("repository")],
                ("PUT")[$subresource = ("seg", "title")],
                ("DELETE")[$subresource = ("seg", "title")]
              )
              let $request-content-types := (
                (api:html-content-type())[not($subresource)],
                (api:tei-content-type("tei:seg"))[$subresource = ("repository", "seg")],
                (api:tei-content-type("tei:title"))[$subresource = "title"],
                ("text/plain")[$subresource = ("title", "seg")]
              )
              let $accept-content-types := (
                (api:html-content-type())[not($subresource)],
                (api:tei-content-type())[$subresource = ("repository", "seg")],
                (api:tei-content-type())[$subresource = "title"],
                ("text/plain")[$subresource = ("title", "seg")]
              )
              where 
                $formatted-result and (
                (- if there's no owner, then we've searched through everything. Need to filter for purpose-)
                if (string($path-parts/data:owner))
                then true()
                else data:path-to-parts($api-doc)/data:purpose/string() eq $path-parts/data:purpose/string()
                )
              order by ft:score($result) descending
              return
                api:list-item($desc, $link, $supported-methods, $accept-content-types, $request-content-types, $alt)  
            }</ul>)
  return (
    api:serialize-as('xhtml'),
    api:list(
      <title>Search results for {$uri}?q={$query}</title>,
      $results,
      count(scache:get($uri, $query)/li),
      true(),
      "GET",
      api:html-content-type(), 
      ()
    )        
  )
};
:)

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
  let $sequence := nav:api-path-to-sequence($uri)
  return 
    if ($q)
    then
      for $result in $sequence[ft:query(., $q)]
      order by ft:score($result) descending
      return $result
    else $sequence
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
              count($list-body/self::ul[@class="results"]/li),
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
  local:disallowed()
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

