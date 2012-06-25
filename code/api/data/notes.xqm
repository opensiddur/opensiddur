xquery version "3.0";
(: Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(:~ Annotation data API
 : Annotation data includes textual notes, instructional material, 
 : category annotations and cross references 
 : @author Efraim Feinstein
 :)

module namespace notes = 'http://jewishliturgy.org/api/data/notes';

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace rest="http://exquery.org/ns/rest/annotation/";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace o="http://a9.com/-/spec/opensearch/1.1/";

import module namespace acc="http://jewishliturgy.org/modules/access"
  at "/code/api/modules/access.xqm";
import module namespace api="http://jewishliturgy.org/modules/api"
  at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "/code/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "/code/api/modules/data.xqm";
import module namespace orig="http://jewishliturgy.org/api/data/original"
  at "/code/api/data/original.xqm";
import module namespace jvalidate="http://jewishliturgy.org/modules/jvalidate"
  at "/code/modules/jvalidate.xqm";

import module namespace magic="http://jewishliturgy.org/magic"
  at "/code/magic/magic.xqm";
  
import module namespace kwic="http://exist-db.org/xquery/kwic";

declare variable $notes:data-type := "notes";
declare variable $notes:schema := "/schema/annotation.rnc";
declare variable $notes:schematron := "/schema/annotation.xsl2";
declare variable $notes:path-base := concat($data:path-base, "/", $notes:data-type);

(:~ validate 
 : @param $doc The document to be validated
 : @param $old-doc An older copy of the document that is being replaced
 : @return true() if valid, false() if not
 : @see notes:validate-report
 :) 
declare function notes:validate(
  $doc as item(),
  $old-doc as document-node()?
  ) as xs:boolean {
  validation:jing($doc, xs:anyURI($notes:schema)) and
    jvalidate:validation-boolean(
      jvalidate:validate-iso-schematron-svrl($doc, xs:anyURI($notes:schematron))
    ) and (
      empty($old-doc) or
      jvalidate:validation-boolean(
        (: original and annotations validate the same changes :)
        orig:validate-changes($doc, $old-doc)
      )
    )
};

(:~ validate, returning a validation report 
 : @param $doc The document to be validated
 : @param $old-doc An old copy of the document
 : @return true() if valid, false() if not
 : @see notes:validate
 :) 
declare function notes:validate-report(
  $doc as item(),
  $old-doc as document-node()?
  ) as element() {
  jvalidate:concatenate-reports((
    validation:jing-report($doc, xs:anyURI($notes:schema)),
    jvalidate:validate-iso-schematron-svrl($doc, doc($notes:schematron)),
    if (exists($old-doc))
    then orig:validate-changes($doc, $old-doc)
    else ()
  ))
};

(: error message when access is not allowed :)
declare function local:no-access(
  ) as item()+ {
  if (app:auth-user())
  then api:rest-error(403, "Forbidden")
  else api:rest-error(401, "Not authenticated")
};

(:~ Get an XML annotation document by name
 : @param $name Document name as a string
 : @error HTTP 404 Not found (or not available)
 :)
declare
  %rest:GET
  %rest:path("/api/data/notes/{$name}")
  %rest:produces("application/xml", "text/xml", "application/tei+xml")
  function notes:get(
    $name as xs:string
  ) as item()+ {
  let $doc := data:doc($notes:data-type, $name)
  return
   if ($doc)
   then $doc
   else api:rest-error(404, "Not found", $name)
};

(:~ List or full-text query annotation documents
 : @param $query text of the query, empty string for all
 : @param $start first document to list
 : @param $max-results number of documents to list 
 : @return a list of documents that match the search. If the documents match a query, return the context.
 : @error HTTP 404 Not found
 :)
declare 
  %rest:GET
  %rest:path("/api/data/notes")
  %rest:query-param("q", "{$query}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("html5")  
  function notes:list(
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
        <title>Annotation data API</title>
        <link rel="search"
               type="application/opensearchdescription+xml" 
               href="/api/data/OpenSearchDescription?source={encode-for-uri($notes:path-base)}"
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
    for $doc in
      collection($notes:path-base)//(tei:title|j:annotations)[ft:query(.,$query)]
    order by $doc//(tei:title[@type="main"]|tei:title[not(@type)])[1] ascending
    return $doc
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
          <a class="document" href="/api{$notes:path-base}/{$api-name}">{$doc//tei:titleStmt/(tei:title[@type="main"]|tei:title[not(@type)])[1]/string()}</a>:
          <ol class="contexts">{
            for $p in 
              kwic:summarize($hit, <config xmlns="" width="40" />)
            return
              <li class="context">{
                $p/*
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
  let $all := 
    for $doc in collection($notes:path-base)/tei:TEI
    order by $doc//(tei:title[@type="main"]|tei:title[not(@type)])[1] ascending
    return $doc
  return (
    <ul xmlns="http://www.w3.org/1999/xhtml" class="results">{
      for $result in subsequence($all, $start, $count) 
      let $api-name := replace(util:document-name($result), "\.xml$", "")
      return
        <li class="result">
          <a class="document" href="/api{$notes:path-base}/{$api-name}">{$result//tei:titleStmt/tei:title[@type="main"]/string()}</a>
          <a class="alt" property="access" href="/api{$notes:path-base}/{$api-name}/access">access</a>
        </li>
    }</ul>,
    $start,
    $count,
    count($all)
  )
};
  

(:~ Delete an annotation text
 : @param $name The name of the text
 : @return HTTP 204 (No data) if successful
 : @error HTTP 400 Cannot be deleted and a reason, including existing external references
 : @error HTTP 401 Not authorized
 : @error HTTP 403 Forbidden - logged in as a user who does not have write access to the document
 : @error HTTP 404 Not found 
 :)
declare 
  %rest:DELETE
  %rest:path("/api/data/notes/{$name}")
  function notes:delete(
    $name as xs:string
  ) as item()+ {
  let $doc := data:doc($notes:data-type, $name)
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
            <output:serialization-parameters>
              <output:method value="text"/>
            </output:serialization-parameters>
            <http:response status="204"/>
          </rest:response>
        )
        else
          local:no-access()
    else
      api:rest-error(404, "Not found", $name)
};

(:~ Post a new annotation document 
 : @param $body The annotation document
 : @return HTTP 201 if created successfully
 : @error HTTP 400 Invalid annotation XML
 : @error HTTP 401 Not authorized
 : @error HTTP 500 Storage error
 :
 : Other effects: 
 : * A change record is added to the resource
 : * The new resource is owned by the current user, group owner=current user, and mode is 664
 :)
declare
  %rest:POST("{$body}")
  %rest:path("/api/data/notes")
  %rest:consumes("application/xml", "application/tei+xml", "text/xml")
  function notes:post(
    $body as document-node()
  ) as item()+ {
  let $paths := 
    data:new-path-to-resource(
      concat($notes:data-type, "/", $body/tei:TEI/@xml:lang), 
      $body//(tei:title[@type="main"]|tei:title[not(@type)])[1]
    )
  let $resource := $paths[2]
  let $collection := $paths[1]
  let $user := app:auth-user()
  return 
    if (sm:has-access(xs:anyURI($notes:path-base), "w"))
    then 
      if (notes:validate($body, ()))
      then (
        app:make-collection-path($collection, "/", sm:get-permissions(xs:anyURI($notes:path-base))),
        let $db-path := xmldb:store($collection, $resource, $body)
        return
          if ($db-path)
          then 
            <rest:response>
              <output:serialization-parameters>
                <output:method value="text"/>
              </output:serialization-parameters>
              <http:response status="201">
                {
                  let $uri := xs:anyURI($db-path)
                  let $change-record := orig:record-change(doc($db-path), "created")
                  return system:as-user("admin", $magic:password, (
                    sm:chown($uri, $user),
                    sm:chgrp($uri, $user),
                    sm:chmod($uri, "rw-rw-r--")
                  ))
                }
                <http:header 
                  name="Location" 
                  value="{concat("/api", $notes:path-base, "/", substring-before($resource, ".xml"))}"/>
              </http:response>
            </rest:response>
          else api:rest-error(500, "Cannot store the resource")
      )
      else
        api:rest-error(400, "Input document is not a valid JLPTEI annotation document", notes:validate-report($body, ()))
    else local:no-access()
};

(:~ Edit/replace an annotation document in the database
 : @param $name Name of the document to replace
 : @param $body New document
 : @return HTTP 204 If successful
 : @error HTTP 400 Invalid XML; Attempt to edit a read-only part of the document
 : @error HTTP 401 Unauthorized - not logged in
 : @error HTTP 403 Forbidden - the document can be found, but is not writable by you
 : @error HTTP 404 Not found
 : @error HTTP 500 Storage error
 :
 : A change record is added to the resource
 : TODO: add xml:id to required places too
 :)
declare
  %rest:PUT("{$body}")
  %rest:path("/api/data/notes/{$name}")
  %rest:consumes("application/xml", "text/xml")
  function notes:put(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  let $doc := data:doc($notes:data-type, $name)
  return
    if ($doc)
    then
      let $resource := util:document-name($doc)
      let $collection := util:collection-name($doc)
      let $uri := document-uri($doc)
      return  
        if (sm:has-access(xs:anyURI($uri), "w"))
        then
          if (notes:validate($body, $doc))
          then
            if (xmldb:store($collection, $resource, $body))
            then 
              <rest:response>
                {
                  orig:record-change(doc($uri), "edited")
                }
                <output:serialization-parameters>
                  <output:method value="text"/>
                </output:serialization-parameters>
                <http:response status="204"/>
              </rest:response>
            else api:rest-error(500, "Cannot store the resource")
          else api:rest-error(400, "Input document is not valid annotation JLPTEI", notes:validate-report($body, $doc)) 
        else local:no-access()
    else 
      (: it is not clear that this is correct behavior for PUT.
       : If the user gives the document a name, maybe it should
       : just keep that resource name and create it?
       :)
      api:rest-error(404, "Not found", $name)
};

(:~ Get access/sharing data for an annotation document
 : @param $name Name of document
 : @return HTTP 200 and an access structure (a:access)
 : @error HTTP 404 Document not found or inaccessible
 :)
declare 
  %rest:GET
  %rest:path("/api/data/notes/{$name}/access")
  %rest:produces("application/xml")
  function notes:get-access(
    $name as xs:string
  ) as item()+ {
  let $doc := data:doc($notes:data-type, $name)
  return
   if ($doc)
   then acc:get-access($doc)
   else api:rest-error(404, "Not found", $name)
};

(:~ Set access/sharing data for an annotation document
 : @param $name Name of document
 : @param $body New sharing rights, as an a:access structure 
 : @return HTTP 204 No data, access rights changed
 : @error HTTP 400 Access structure is invalid
 : @error HTTP 401 Not authorized
 : @error HTTP 403 Forbidden
 : @error HTTP 404 Document not found or inaccessible
 :)
declare 
  %rest:PUT("{$body}")
  %rest:path("/api/data/notes/{$name}/access")
  %rest:consumes("application/xml", "text/xml")
  function notes:put-access(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  let $doc := data:doc($notes:data-type, $name)
  let $access := $body/*
  return
    if ($doc)
    then 
      try {
        acc:set-access($doc, $access),
        <rest:response>
          <output:serialization-parameters>
            <output:method value="text"/>
          </output:serialization-parameters>
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
