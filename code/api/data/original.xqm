xquery version "3.0";
(: Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(:~ Original data API
 : @author Efraim Feinstein
 :)

module namespace orig = 'http://jewishliturgy.org/api/data/original';

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
import module namespace jvalidate="http://jewishliturgy.org/modules/jvalidate"
  at "/code/modules/jvalidate.xqm";
import module namespace user="http://jewishliturgy.org/api/user"
  at "/code/api/user.xqm";

import module namespace magic="http://jewishliturgy.org/magic"
  at "/code/magic/magic.xqm";
  
import module namespace kwic="http://exist-db.org/xquery/kwic";

declare variable $orig:data-type := "original";
declare variable $orig:schema := "/schema/jlptei.rnc";
declare variable $orig:schematron := "/schema/jlptei.xsl2";
declare variable $orig:path-base := concat($data:path-base, "/", $orig:data-type);

(:~ record that a change occurred
 : @param $doc TEI document where the change should be recorded
 : @param $change-type the type of the change
 : @return On return, the document is updated.
 :
 : If the document has no existing revisionDesc, one is created
 : New changes are positioned as the first element in the revisionDesc
 :)
declare function orig:record-change(
  $doc as document-node(),
  $change-type as xs:string
  ) as empty-sequence() {
  let $who := app:auth-user()
  let $who-uri := user:db-path($who)
  let $revisionDesc := $doc//tei:revisionDesc
  let $change :=
    <tei:change 
      type="{$change-type}" 
      who="{$who-uri}"
      when="{current-dateTime()}"
      />
  return
    if ($revisionDesc and exists($revisionDesc/*))
    then
      update insert $change preceding $revisionDesc/*[1]
    else if ($revisionDesc)
    then
      update insert $change into $revisionDesc
    else
      update insert 
        <tei:revisionDesc>{
          $change
        }</tei:revisionDesc>
      following $doc//tei:teiHeader/*[last()]
};

(:~ validate 
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @return true() if valid, false() if not
 : @see orig:validate-report
 :) 
declare function orig:validate(
  $doc as item(),
  $old-doc as document-node()?
  ) as xs:boolean {
  validation:jing($doc, xs:anyURI($orig:schema)) and
    jvalidate:validation-boolean(
      jvalidate:validate-iso-schematron-svrl($doc, xs:anyURI($orig:schematron))
    ) and (
      empty($old-doc) or
      jvalidate:validation-boolean(
        orig:validate-changes($doc, $old-doc)
      )
    )
};

(:~ validate, returning a validation report 
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @return true() if valid, false() if not
 : @see orig:validate
 :) 
declare function orig:validate-report(
  $doc as item(),
  $old-doc as document-node()?
  ) as element() {
  jvalidate:concatenate-reports((
    validation:jing-report($doc, xs:anyURI($orig:schema)),
    jvalidate:validate-iso-schematron-svrl($doc, doc($orig:schematron)),
    if (exists($old-doc))
    then orig:validate-changes($doc, $old-doc)
    else ()
  ))
};

(:~ determine if all the changes between an old version and
 : a new version of a document are legal
 : @param $doc new document
 : @param $old-doc old document
 : @return a report element, indicating whether the changes are valid or invalid
 :) 
declare function orig:validate-changes(
  $doc as document-node(),
  $old-doc as document-node()
  ) as element(report) {
  let $messages := ( 
    if (not(xmldiff:compare($doc//tei:revisionDesc, $old-doc//tei:revisionDesc)))
    then <message>You may not alter the revision history</message>
    else (),
    let $authors := 
      distinct-values(
        $old-doc//tei:change/@who/substring-after(., "/user/")
      )
    let $can-change-license := 
      (count($authors) = 1) and 
      $authors = app:auth-user()
    return
      if (not(xmldiff:compare(
        <x>{
          $doc//tei:publicationStmt/
            (* except (
              if ($can-change-license) 
              then () 
              else tei:licence
            ))
        }</x>, 
        <x>{
          $old-doc//tei:publicationStmt/
          (* except (
            if ($can-change-license) 
            then () 
            else tei:licence
          ))
        }</x>)
      ))
      then <message>The information in the tei:publicationStmt is immutable and only the original author can change the text's license.</message>
      else ()
    )
  let $is-valid := empty($messages)
  return
    <report>
      <status>{
        if ($is-valid)
        then "valid"
        else "invalid"
      }</status>
      {$messages}
    </report>
};

(: error message when access is not allowed :)
declare function local:no-access(
  ) as item()+ {
  if (app:auth-user())
  then api:rest-error(403, "Forbidden")
  else api:rest-error(401, "Not authenticated")
};

(:~ Get an XML document by name
 : @param $name Document name as a string
 : @error HTTP 404 Not found (or not available)
 :)
declare
  %rest:GET
  %rest:path("/api/data/original/{$name}")
  %rest:produces("application/xml", "text/xml", "application/tei+xml")
  function orig:get(
    $name as xs:string
  ) as item()+ {
  let $doc := data:doc($orig:data-type, $name)
  return
   if ($doc)
   then $doc
   else api:rest-error(404, "Not found", $name)
};


(:~ List or full-text query original data
 : @param $query text of the query, empty string for all
 : @param $start first document to list
 : @param $max-results number of documents to list 
 : @return a list of documents that match the search. If the documents match a query, return the context.
 : @error HTTP 404 Not found
 :)
declare 
  %rest:GET
  %rest:path("/api/data/original")
  %rest:query-param("q", "{$query}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("html5")  
  function orig:list(
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
        <title>Original data API</title>
        <link rel="search"
               type="application/opensearchdescription+xml" 
               href="/api/data/OpenSearchDescription?source={encode-for-uri($orig:path-base)}"
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
      collection($orig:path-base)//(tei:title|j:streamText)[ft:query(.,$query)]
    order by $doc//tei:title[@type="main"] ascending
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
          <a class="document" href="/api{$orig:path-base}/{$api-name}">{$doc//tei:titleStmt/tei:title[@type="main"]/string()}</a>:
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
  let $all := 
    for $doc in collection($orig:path-base)/tei:TEI
    order by $doc//tei:title[@type="main"] ascending
    return $doc
  return (
    <ul xmlns="http://www.w3.org/1999/xhtml" class="results">{
      for $result in subsequence($all, $start, $count) 
      let $api-name := replace(util:document-name($result), "\.xml$", "")
      return
        <li class="result">
          <a class="document" href="/api{$orig:path-base}/{$api-name}">{$result//tei:titleStmt/tei:title[@type="main"]/string()}</a>
          <a class="alt" property="access" href="/api{$orig:path-base}/{$api-name}/access">access</a>
        </li>
    }</ul>,
    $start,
    $count,
    count($all)
  )
};
  

(:~ Delete am original text
 : @param $name The name of the text
 : @return HTTP 204 (No data) if successful
 : @error HTTP 400 Cannot be deleted and a reason, including existing external references
 : @error HTTP 401 Not authorized
 : @error HTTP 403 Forbidden - logged in as a user who does not have write access to the document
 : @error HTTP 404 Not found 
 :)
declare 
  %rest:DELETE
  %rest:path("/api/data/original/{$name}")
  function orig:delete(
    $name as xs:string
  ) as item()+ {
  let $doc := data:doc($orig:data-type, $name)
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

(:~ Post a new original document 
 : @param $body The JLPTEI document
 : @return HTTP 201 if created successfully
 : @error HTTP 400 Invalid JLPTEI XML
 : @error HTTP 401 Not authorized
 : @error HTTP 500 Storage error
 :
 : Other effects: 
 : * A change record is added to the resource
 : * The new resource is owned by the current user, group owner=current user, and mode is 664
 :)
declare
  %rest:POST("{$body}")
  %rest:path("/api/data/original")
  %rest:consumes("application/xml", "application/tei+xml", "text/xml")
  function orig:post(
    $body as document-node()
  ) as item()+ {
  let $paths := 
    data:new-path-to-resource(
      concat($orig:data-type, "/", $body/tei:TEI/@xml:lang), 
      $body//tei:title[@type="main" or not(@type)][1]
    )
  let $resource := $paths[2]
  let $collection := $paths[1]
  let $user := app:auth-user()
  return 
    if (sm:has-access(xs:anyURI($orig:path-base), "w"))
    then 
      if (orig:validate($body, ()))
      then (
        app:make-collection-path($collection, "/", sm:get-permissions(xs:anyURI($orig:path-base))),
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
                  value="{concat("/api", $orig:path-base, "/", substring-before($resource, ".xml"))}"/>
              </http:response>
            </rest:response>
          else api:rest-error(500, "Cannot store the resource")
      )
      else
        api:rest-error(400, "Input document is not valid JLPTEI", orig:validate-report($body, ()))
    else local:no-access()
};

(:~ Edit/replace a document in the database
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
  %rest:path("/api/data/original/{$name}")
  %rest:consumes("application/xml", "text/xml")
  function orig:put(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  let $doc := data:doc($orig:data-type, $name)
  return
    if ($doc)
    then
      let $resource := util:document-name($doc)
      let $collection := util:collection-name($doc)
      let $uri := document-uri($doc)
      return  
        if (sm:has-access(xs:anyURI($uri), "w"))
        then
          if (orig:validate($body, $doc))
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
          else api:rest-error(400, "Input document is not valid JLPTEI", orig:validate-report($body, $doc)) 
        else local:no-access()
    else 
      (: it is not clear that this is correct behavior for PUT.
       : If the user gives the document a name, maybe it should
       : just keep that resource name and create it?
       :)
      api:rest-error(404, "Not found", $name)
};

(:~ Get access/sharing data for a document
 : @param $name Name of document
 : @return HTTP 200 and an access structure (a:access)
 : @error HTTP 404 Document not found or inaccessible
 :)
declare 
  %rest:GET
  %rest:path("/api/data/original/{$name}/access")
  %rest:produces("application/xml")
  function orig:get-access(
    $name as xs:string
  ) as item()+ {
  let $doc := data:doc($orig:data-type, $name)
  return
   if ($doc)
   then acc:get-access($doc)
   else api:rest-error(404, "Not found", $name)
};

(:~ Set access/sharing data for a document
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
  %rest:path("/api/data/original/{$name}/access")
  %rest:consumes("application/xml", "text/xml")
  function orig:put-access(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  let $doc := data:doc($orig:data-type, $name)
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
