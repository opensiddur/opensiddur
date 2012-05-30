xquery version "3.0";
(: Transliteration API module
 : 
 : Functions assume that the following has already been done:
 :  authentication,
 :  content negotiation
 : 
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed Under the GNU Lesser General Public License, version 3 or later
 :)
module namespace tran = 'http://jewishliturgy.org/api/transliteration';

import module namespace acc="http://jewishliturgy.org/modules/access"
  at "/code/api/modules/access.xqm";
import module namespace api="http://jewishliturgy.org/modules/api"
  at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "/code/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "/code/api/modules/data.xqm";
import module namespace jvalidate="http://jewishliturgy.org/modules/jvalidate"
  at "/code/modules/jvalidate.xqm";

import module namespace kwic="http://exist-db.org/xquery/kwic";

declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";

declare namespace rest="http://exquery.org/ns/rest/annotation/";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace error="http://jewishliturgy.org/errors";

declare variable $tran:data-type := "transliteration";
declare variable $tran:schema := "/schema/transliteration.rnc";
declare variable $tran:schematron := "/schema/transliteration.xsl2";
declare variable $tran:path-base := concat($data:path-base, "/", $tran:data-type);

declare function tran:validate(
  $tr as item()
  ) as xs:boolean {
  validation:jing($tr, xs:anyURI($tran:schema)) and
    jvalidate:validation-boolean(
      jvalidate:validate-iso-schematron-svrl($tr, xs:anyURI($tran:schematron))
    )
};

declare function tran:validate-report(
  $tr as item()
  ) as element() {
  jvalidate:concatenate-reports((
    validation:jing-report($tr, xs:anyURI($tran:schema)),
    jvalidate:validate-iso-schematron-svrl($tr, doc($tran:schematron))
  ))
};

(: error message when access is not allowed :)
declare function local:no-access(
  ) as item()+ {
  if (sm:is-externally-authenticated())
  then api:rest-error(403, "Forbidden")
  else api:rest-error(401, "Not authenticated")
};

declare 
  %rest:GET
  %rest:path("/api/data/transliteration/{$name}")
  %rest:produces("application/xml")
  function tran:get(
    $name as xs:string
  ) as item()+ {
  let $doc := data:doc($tran:data-type, $name)
  return
   if ($doc)
   then $doc
   else api:rest-error(404, "Not found", $name)
};

(:~ Discovery and query API: 
 : list accessible transliterations 
 : or search
 :)
declare 
  %rest:GET
  %rest:path("/api/data/transliteration")
  %rest:query-param("q", "{$query}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$count}", 100)
  %rest:produces("application/xhtml+xml")
  function tran:list(
    $query as xs:string?,
    $start as xs:integer,
    $count as xs:integer
  ) as item()+ {
  <rest:response>
    <output:serialization-parameters>
      <output:method value="html5"/>
    </output:serialization-parameters>
  </rest:response>,
  let $results as item()+ :=
    if ($query)
    then local:query($query, $start, $count)
    else local:list($start, $count)
  let $result-element := $results[1]
  let $max-results := $results[3]
  let $total := $results[4]
  return
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head profile="http://a9.com/-/spec/opensearch/1.1/">
        <title>Transliteration API</title>
        <link rel="search"
               type="application/opensearchdescription+xml" 
               href="/api/data/OpenSearchDescription?source={encode-for-uri($tran:path-base)}"
               title="Full text search" />
        <meta name="startIndex" content="{if ($total eq 0) then 0 else $start}"/>
        <meta name="endIndex" content="{min(($start + $max-results - 1, $total))}"/>
        <meta name="itemsPerPage" content="{$max-results}"/>
        <meta name="totalResults" content="{$total}"/>
      </head>
      <body>{
        $result-element
      }</body>
    </html>
};

(: @return (list, start, count, n-results) :) 
declare function local:query(
    $query as xs:string,
    $start as xs:integer,
    $count as xs:integer
  ) as item()+ {
  let $all-results := 
      collection($tran:path-base)//(tr:title|tr:description)[ft:query(.,$query)]
  let $listed-results := 
    <ol xmlns="http://www.w3.org/1999/xhtml" class="results">{
      for $result in  
        subsequence($all-results, $start, $count)
      let $document := root($result)
      group $result as $hit by $document as $doc
      order by max(for $h in $hit return ft:score($h))
      return
        let $api-name := replace(util:document-name($doc), "\.xml$", "")
        return
        <li class="result">
          <a class="document" href="/api{$tran:path-base}/{$api-name}">{$doc//tr:title/string()}</a>:
          <ol class="contexts">{
            for $h in $hit
            order by ft:score($h) descending
            return
              <li class="context">{
                kwic:summarize($h, <config xmlns="" width="40" />)
              }</li>
          }</ol>
        </li>
    }</ol>
  return (
    $listed-results,
    $start,
    $count, 
    count($all-results)
  )
};

declare function local:list(
  $start as xs:integer,
  $count as xs:integer
  ) {
  let $all := collection($tran:path-base)/tr:schema
  return (
    <ul xmlns="http://www.w3.org/1999/xhtml" class="results">{
      for $table in subsequence($all, $start, $count) 
      let $api-name := replace(util:document-name($table), "\.xml$", "")
      return
        <li class="result">
          <a class="document" href="/api{$tran:path-base}/{$api-name}">{$table/tr:title/string()}</a>
        </li>
    }</ul>,
    $start,
    $count,
    count($all)
  )
};
  
  
declare 
  %rest:DELETE
  %rest:path("/api/data/transliteration/{$name}")
  function tran:delete(
    $name as xs:string
  ) as item()+ {
  let $doc := data:doc($tran:data-type, $name)
  return
    if ($doc)
    then
      let $path := document-uri($doc) cast as xs:anyURI
      let $collection := util:collection-name($doc)
      let $resource := util:document-name($doc)
      return
        if (
          (: for deletion, 
          eXist requires write access to the collection.
          We need to require write access to the path
          :)
          sm:has-access(xs:anyURI($collection), "w") and 
          sm:has-access($path, "w")
          )
        then (
          (: TODO: check for references! :)
          xmldb:remove($collection, $resource),
          <rest:response>
            <http:response status="204"/>
          </rest:response>
        )
        else
          local:no-access()
    else
      api:rest-error(404, "Not found", $name)
};

declare
  %rest:POST("{$body}")
  %rest:path("/api/data/transliteration")
  %rest:consumes("application/xml", "text/xml")
  function tran:post(
    $body as document-node()
  ) as item()+ {
  
  let $paths := data:new-path-to-resource($tran:data-type, ($body//tr:title)[1])
  let $resource := $paths[2]
  let $collection := $paths[1]
  return 
    if (sm:has-access(xs:anyURI($tran:path-base), "w"))
    then 
      if (tran:validate($body))
      then (
        app:make-collection-path($collection, "/", sm:get-permissions(xs:anyURI($tran:path-base))),
        if (xmldb:store($collection, $resource, $body))
        then 
          <rest:response>
            <http:response status="201">
              <http:header 
                name="Location" 
                value="{concat("/api", $tran:path-base, "/", substring-before($resource, ".xml"))}"/>
            </http:response>
          </rest:response>
        else api:rest-error(500, "Cannot store the resource")
      )
      else
        api:rest-error(400, "Input document is not a valid transliteration", tran:validate-report($body))
  else local:no-access()
    
};

declare
  %rest:PUT("{$body}")
  %rest:path("/api/data/transliteration/{$name}")
  %rest:consumes("application/xml", "text/xml")
  function tran:put(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  let $doc := data:doc($tran:data-type, $name)
  return
    if ($doc)
    then
      let $resource := util:document-name($doc)
      let $collection := util:collection-name($doc)
      let $uri := document-uri($doc)
      return  
        if (sm:has-access(xs:anyURI($uri), "w"))
        then
          if (tran:validate($body))
          then
            if (xmldb:store($collection, $resource, $body))
            then 
              <rest:response>
                <http:response status="204"/>
              </rest:response>
            else api:rest-error(500, "Cannot store the resource")
          else api:rest-error(400, "Input document is not a valid transliteration", tran:validate-report($body)) 
        else local:no-access()
    else 
      (: it is not clear that this is correct behavior for PUT.
       : If the user gives the document a name, maybe it should
       : just keep that resource name and create it?
       :)
      api:rest-error(404, "Not found", $name)
};

declare
  %rest:GET
  %rest:path("/api/access/transliteration")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$count}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/html", "text/xml")
  %output:method("html5")
  function tran:get-access-list(
  $start as xs:integer,
  $count as xs:integer
  ) as item()+ {
  let $list := local:list(1,100)
  let $results-element := $list[1]
  let $max-results := $list[3]
  let $total := $list[4]
  return
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head profile="http://a9.com/-/spec/opensearch/1.1/">
        <title>Transliteration Access API index</title>
        <meta name="startIndex" content="{if ($total eq 0) then 0 else $start}"/>
        <meta name="endIndex" content="{min(($start + $max-results - 1, $total))}"/>
        <meta name="itemsPerPage" content="{$max-results}"/>
        <meta name="totalResults" content="{$total}"/>
      </head>
      <body>
        <ul class="results">{
          for $li in $results-element/li/a
          return
            <li class="result">
              <a href="{
                replace($li/@href, "^/api/data", "/api/access")
              }">{$li/string()}</a>
            </li>
        }</ul>
      </body>
    </html>
};

declare 
  %rest:GET
  %rest:path("/api/access/transliteration/{$name}")
  %rest:produces("application/xml")
  function tran:get-access(
    $name as xs:string
  ) as item()+ {
  let $doc := data:doc($tran:data-type, $name)
  return
   if ($doc)
   then acc:get-access($doc)
   else api:rest-error(404, "Not found", $name)
};

declare 
  %rest:PUT("{$body}")
  %rest:path("/api/access/transliteration/{$name}")
  %rest:consumes("application/xml", "text/xml")
  function tran:put-access(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  let $doc := data:doc($tran:data-type, $name)
  let $access := $body/*
  return
    if ($doc)
    then 
      try {
        acc:set-access($doc, $access),
        <rest:response>
          <http:response status="204"/>
        </rest:response>
      }
      catch error:VALIDATION {
        api:rest-error(400, "Validation error in input", acc:validate-report($access))
      }
      catch error:UNAUTHORIZED {
        api:rest-error(401, "Not authenticated")
      }
      catch error:FORBIDDEN {
        api:rest-error(403, "Forbidden")
      }
    else api:rest-error(404, "Not found", $name)
};