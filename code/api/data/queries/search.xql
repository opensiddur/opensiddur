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
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace exist="http://exist.sourceforge.net/NS/exist";

declare variable $local:valid-formats := ('xhtml', 'html');
declare variable $local:valid-subresources := ('title', 'seg', 'repository');

(:~ guess the language of a search result by the language of the match,
 : add to the hit
 : @param $hit the search result hit
 :)
declare function local:result-with-lang(
  $hit as node()
  ) as element(p)* {
  let $expanded := kwic:expand($hit)
  let $summary := kwic:summarize($hit, element {QName('', 'config')}{attribute width {40}})
  let $lang := string($hit/ancestor::*[@xml:lang][1]/@xml:lang)
  for $p at $i in $summary
  let $match := ($expanded//exist:match)[$i]
  let $pre := $match/preceding-sibling::node()
  let $post := $match/following-sibling::node()
  (: results are sometimes returned with blank matches. Do not return them! :)
  where $p/span[@class='hi']/string()
  return
    <p>{
      attribute lang {$lang},
      attribute xml:lang {$lang},
      $p/span[@class='previous'],
      (: add something that collapses to a space if the match is not in the middle of a word :)
      <span class="hi">{
        concat(if ($pre) then '' else ' ',
          $p/span[@class='hi'],
          if ($post) then '' else ' ')
      }</span>,
      $p/span[@class='following']
    }</p>
};

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
      (: no owner, top identifiable level is share-type :)
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
        if (false() (:scache:is-up-to-date($collection, $uri, $query):))
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
                  then 
                    if ($path-parts/data:purpose = 'output')
                    then $top-level//html:title[ft:query(.,$query)]
                    else $top-level//tei:title[ft:query(.,$query)]
                  else if ($subresource = 'repository')
                  then $top-level//j:repository[ft:query(.,$query)]
                  else $top-level//tei:seg[ft:query(.,$query)]
                else if ($path-parts/data:purpose = 'output')
                then
                  (: HTML based -- TODO: what happens when we have non-HTML output? :)
                  $top-level//html:body[ft:query(., $query)]
                else
                  (: TEI-based :)
                  $top-level//(j:repository|tei:title)[ft:query(., $query)]
              )
              let $root := root($result)
              let $doc-uri := document-uri($root)
              let $title := $root//(tei:title[@type='main' or not(@type)]|html:title)
              let $title-lang := string($title/ancestor-or-self::*[@xml:lang][1]/@xml:lang)
              let $formatted-result := local:result-with-lang($result)
              let $desc := (
                (: desc contains the document title and the context of the search result :)
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
              let $alt-desc := 'db'
              where 
                $formatted-result and (
                (: if there's no owner, then we've searched through everything. Need to filter for purpose:)
                if (string($path-parts/data:owner))
                then true()
                else data:path-to-parts($api-doc)/data:purpose/string() eq $path-parts/data:purpose/string()
                )
              order by ft:score($result) descending
              return
                api:list-item($desc, $link, (), $doc-uri, $alt-desc)  
            }</ul>)
  return (
    api:serialize-as('xhtml'),
    api:list(
      <title>Search results for {$uri}?q={$query}</title>,
      $results,
      count(scache:get($uri, $query)/li)
    )        
  )
};

if (api:allowed-method(('GET')))
then
  local:get(request:get-uri())
else 
	(:disallowed method:)
	api:error-message("Method not allowed")
