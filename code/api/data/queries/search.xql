xquery version "1.0";
(:~ Search API for data
 :
 : Available formats: xhtml
 : Method: GET
 : Status:
 :	200 OK
 :	401, 403 Authentication
 :	404 Bad format 
 :
 : Open Siddur Project 
 : Copyright 2011 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace kwic="http://exist-db.org/xquery/kwic";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
	at "/code/api/modules/data.xqm";
import module namespace scache="http://jewishliturgy.org/modules/scache"
	at "/code/api/modules/scache.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

declare variable $local:valid-formats := ('xhtml', 'html');
declare variable $local:valid-subresources := ('title', 'seg', 'repository');

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
    else collection(data:api-path-to-db($path))
  let $collection :=
    if ($top-level instance of document-node())
    then util:collection-name($top-level)
    else data:api-path-to-db($path)
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
      let $null := util:log-system-out(('$path-parts=', $path-parts, ' db-path=', $db-path, ' collection=', $collection))
      let $results :=
        if (scache:is-up-to-date($collection, $uri, $query))
        then 
          scache:get-request($uri, $query)
        else
          scache:store($uri, $query,
            <ul class="results">{ 
              for $result in (
                if ($subresource)
                then
                  (: subresources :)
                  if ($subresource = 'title')
                  then $top-level//tei:title[ft:query(.,$query)]
                  else if ($subresource = 'repository')
                  then $top-level//j:repository[ft:query(.,$query)]
                  else $top-level//tei:seg[ft:query(.,$query)]
                else
                  $top-level//(j:repository|tei:title)[ft:query(., $query)]
              )
              let $doc-uri := document-uri(root($result))
              let $desc := kwic:summarize($result, element {QName('', 'config')}{attribute width {40}})
              let $api-doc := data:db-path-to-api($doc-uri)
              let $link := 
                if ($subresource)
                then concat($api-doc, '/', if ($subresource='seg') then concat('id/', $result/@xml:id) else $subresource)
                else $api-doc
              let $alt-desc := 'doc'
              order by ft:score($result) descending
              return
                api:list-item($desc, $link, (), $api-doc, $alt-desc)  
            }</ul>)
  return
    api:list(
      <title>Search results for {$uri}?q={$query}</title>,
      $results,
      count($results/li)
    )        
};

if (api:allowed-method(('GET')))
then
  local:get(request:get-uri())
else 
	(:disallowed method:)
	api:error-message("Method not allowed")
