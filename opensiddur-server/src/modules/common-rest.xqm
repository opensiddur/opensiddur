xquery version "3.1";
(: Copyright 2012-2014,2016 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(:~ Common REST API functions
 : @author Efraim Feinstein
 :)

module namespace crest = 'http://jewishliturgy.org/modules/common-rest';

import module namespace acc="http://jewishliturgy.org/modules/access"
  at "access.xqm";
import module namespace api="http://jewishliturgy.org/modules/api"
  at "api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "data.xqm";
import module namespace didx="http://jewishliturgy.org/modules/docindex"
  at "docindex.xqm";
import module namespace jvalidate="http://jewishliturgy.org/modules/jvalidate"
  at "jvalidate.xqm";
import module namespace mirror="http://jewishliturgy.org/modules/mirror"
  at "mirror.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "paths.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "refindex.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "debug.xqm";

import module namespace magic="http://jewishliturgy.org/magic"
  at "../magic/magic.xqm";
  
import module namespace kwic="http://exist-db.org/xquery/kwic";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace o="http://a9.com/-/spec/opensearch/1.1/";
declare namespace error="http://jewishliturgy.org/errors";
declare namespace http="http://expath.org/ns/http-client";

(: additional URI representing validate query params for crest:list() :)
declare variable $crest:additional-validate := <crest:additional text="validation (PUT)" relative-uri="?validate=true"/>;

(:~ @return true() if validation should be disabled (during deployment) :)
declare 
    %private 
    function crest:validation-disabled(
    ) as xs:boolean {
    contains(
        system:as-user("admin", $magic:password, 
            system:get-running-xqueries()
        )//system:sourceKey/string(), 
    "post-install.xql")
};

(:~ @return REST error message when access is not allowed :)
declare function crest:no-access(
  ) as item()+ {
  if (app:auth-user())
  then api:rest-error(403, "Forbidden")
  else api:rest-error(401, "Not authenticated")
};

(:~ record that a change occurred in a TEI document
 : @param $doc TEI document where the change should be recorded
 : @param $change-type the type of the change
 : @return On return, the document is updated.
 :
 : If the document has no teiHeader, we do nothing
 : If the document has no existing revisionDesc, one is created
 : New changes are positioned as the first element in the revisionDesc
 : If the first change record lacks @when, it is considered to be the commit log for this change.
 :)
declare function crest:record-change(
  $doc as document-node(),
  $change-type as xs:string
  ) as empty-sequence() {
  if (exists($doc//tei:teiHeader))
  then
      let $who := app:auth-user()
      let $who-uri := substring-after(data:user-api-path($who), api:uri-of("/api"))
      let $revisionDesc := $doc//tei:revisionDesc
      let $commit-log := $revisionDesc/tei:change[1][not(@when)]
      let $change :=
        <tei:change
          type="{$change-type}"
          who="{$who-uri}"
          when="{current-dateTime()}"
          >{$commit-log/(@xml:lang, @xml:id, node())}</tei:change>
      return
        if (exists($commit-log))
        then
          update replace $commit-log with $change
        else if (exists($revisionDesc) and exists($revisionDesc/*))
        then
          update insert $change preceding $revisionDesc/*[1]
        else if (exists($revisionDesc))
        then
          update insert $change into $revisionDesc
        else
          update insert
            <tei:revisionDesc>{
              $change
            }</tei:revisionDesc>
          following $doc//tei:teiHeader/*[last()]
  else ()
};

(:~ validation function to invalidate duplicated xml:ids, which are not automatically rejected :)
declare function crest:invalidate-duplicate-xmlid(
    $doc as document-node(),
    $old-doc as document-node()?
) as element(report) {
    let $ids := $doc//@xml:id/string()
    let $distinct-ids := distinct-values($doc//@xml:id)
    let $is-valid := count($ids) = count($distinct-ids)
    return
        element report {
            element status {
                if ($is-valid) then 'valid'
                else 'invalid'
            },
            if (not($is-valid))
            then
                for $xid in $ids
                group by $grouped := $xid
                where count($xid) > 1
                return element message {
                    "xml:id must be unique. The xml:id '" || $grouped || "' is duplicated"
                }
            else ()
        }
};

(:~ validate a document based on a given schema 
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @param $schema-path path to RelaxNG schema
 : @param $schematron-path path to Schematron schema
 : @param $xquery-functions A sequence of functions to be used as additional validations.
 :              The functions take 2 parameters: $doc, $old-doc and return a validation report element
 :              With @status='valid' or 'invalid'. The element may also contain human-readable message elements
 :              indicating a reason for invalidity
 : @return true() if valid, false() if not
 : @see crest:validate-report
 :) 
declare function crest:validate(
  $doc as item(),
  $old-doc as document-node()?,
  $schema-path as xs:anyURI,
  $schematron-path as xs:anyURI?,
  $xquery-functions as (
      function(item(), document-node()?) as element()
    )*
  ) as xs:boolean {
  let $all-xquery-functions := ($xquery-functions, crest:invalidate-duplicate-xmlid#2)
  return
      crest:validation-disabled() or (
        validation:jing($doc, $schema-path) and (
          empty($schematron-path) or
          jvalidate:validation-boolean(
            jvalidate:validate-iso-schematron-svrl($doc, doc($schematron-path))
        )) and (
          empty($all-xquery-functions) or
            (
              every $xquery-function in $all-xquery-functions
              satisfies
                jvalidate:validation-boolean(
                  $xquery-function($doc, $old-doc)
                )
            )
        )
      )
};

(:~ validate, returning a validation report 
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @param $schema-path path to RelaxNG schema
 : @param $schematron-path path to Schematron schema
 : @param $schema-xquery XQuery function schema
 : @return true() if valid, false() if not
 : @see crest:validate
 :) 
declare function crest:validate-report(
  $doc as item(),
  $old-doc as document-node()?,
  $schema-path as xs:anyURI,
  $schematron-path as xs:anyURI?,
  $xquery-functions as ( 
      function(item(), document-node()?) as element()
    )*
  ) as element() {
  let $all-xquery-functions := ($xquery-functions, crest:invalidate-duplicate-xmlid#2)
  return
      jvalidate:concatenate-reports((
        validation:jing-report($doc, $schema-path),
        if (exists($schematron-path)) then jvalidate:validate-iso-schematron-svrl($doc, doc($schematron-path)) else (),
        for $xquery-function in $all-xquery-functions
        return $xquery-function($doc, $old-doc)
      ))
};

(:~ Get an XML document by name
 : @param $data-type data type 
 : @param $name Document name as a string
 : @error HTTP 404 Not found (or not available)
 :)
declare function crest:get(
    $data-type as xs:string,
    $name as xs:string
  ) as item()+ {
  let $doc := data:doc($data-type, $name)
  return
   if ($doc)
   then $doc
   else api:rest-error(404, "Not found", $name)
};

(:~ List or full-text query the given data
 : @param $query text of the query, empty string for all
 : @param $start first document to list
 : @param $count number of documents to list
 : @param $path-base API base path of the data type (/api/...)
 : @param $query-function function that performs a query for a string
 : @param $list-function function that lists all resources for the data type
 : @param $additional-uris additional sub-uris that are supported in the form: <additional relative-uri="" text=""/>+
 : @param $title-function function that finds the title of a document
 : @return a list of documents that match the search. If the documents match a query, return the context.
 : @error HTTP 404 Not found
 :)
declare function crest:list(
    $query as xs:string*,
    $start as xs:integer*,
    $count as xs:integer*,
    $title as xs:string,
    $path-base as xs:string,
    $query-function as function(xs:string) as element()*,
    $list-function as function() as element()*,
    $additional-uris as element(crest:additional)*,
    $title-function as (function(node()) as xs:string)?
  ) as item()+ {
  <rest:response>
    <output:serialization-parameters>
      <output:method>xhtml</output:method>
    </output:serialization-parameters>
  </rest:response>,
  let $query := string-join($query[.], " ")
  let $start := $start[1]
  let $count := $count[1]
  let $results as item()+ :=
    if ($query)
    then crest:do-query($query, $start, $count, $path-base, $query-function, $title-function)
    else crest:do-list($start, $count, $path-base, $list-function, $additional-uris, $title-function)
  let $result-element := $results[1]
  let $max-results := $results[3]
  let $total := $results[4]
  return
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head> {((: profile="http://a9.com/-/spec/opensearch/1.1/" is deprecated in html5 :))}
        <title>{$title}</title>
        <link rel="search"
               type="application/opensearchdescription+xml" 
               href="{api:uri-of('/api/data/OpenSearchDescription')}?source={$path-base}"
               title="Full text search" />
        <meta name="startIndex" content="{if ($total eq 0) then 0 else $start}"/>
        {((:<meta name="endIndex" content="{min(($start + $max-results - 1, $total))}"/>:)) (: endIndex is not in the Open Search spec and is illegal in meta tags in html5 :)}
        <meta name="itemsPerPage" content="{$max-results}"/>
        <meta name="totalResults" content="{$total}"/>
      </head>
      <body>{
        $result-element
      }</body>
    </html>
};

declare function crest:tei-title-function(
  $n as node()
  ) as xs:string {
  normalize-space(
    root($n)//tei:titleStmt/string-join((
        tei:title["main"=@type]/string(), 
        tei:title["sub"=@type]/string()
        ), ": ")
  )
};

(: @return (list, start, count, n-results) :) 
declare function crest:do-query(
    $query as xs:string,
    $start as xs:integer,
    $count as xs:integer,
    $path-base as xs:string,
    $query-function as (function(xs:string) as element()?),
    $title-function as (function(node()) as xs:string)?
  ) as item()+ {
  let $title-function as (function(node()) as xs:string) :=
    ($title-function, crest:tei-title-function#1)[1]
  let $all-results := $query-function($query)
  (: the ridiculous organization of this code is a workaround
   : for a bug in eXist ~r18071
   :)
  let $list-of-results :=
    for $result in  
        subsequence($all-results, $start, $count)
      group by $document-uri := document-uri(root($result))
      order by max(for $r in $result return ft:score($r)) descending
      return
        let $doc := doc($document-uri)
        let $api-name := replace(util:document-name($doc), "\.xml$", "")
        return
          <li xmlns="http://www.w3.org/1999/xhtml" class="result">
            <a class="document" href="{$path-base}/{$api-name}">{$title-function($doc)}</a>:
            <ol class="contexts">{
              for $hit in $result
              for $p in 
                kwic:summarize($hit, <config xmlns="" width="40" />)
              return
                <li class="context">
                  <span class="previous">{$p/*[@class="previous"]/string()}</span>
                  <span class="match">{$p/*[@class="hi"]/string()}</span>
                  <span class="following">{$p/*[@class="following"]/string()}</span>
                </li>
            }</ol>
          </li>
  let $listed-results := 
    <ol xmlns="http://www.w3.org/1999/xhtml" class="results">{
      $list-of-results
    }</ol>
  return (
    $listed-results,
    $start,
    $count, 
    count($all-results)
  )
};

declare function crest:do-list(
  $start as xs:integer,
  $count as xs:integer,
  $path-base as xs:string,
  $list-function as (function() as element()*),
  $additional-uris as element(crest:additional)*,
  $title-function as (function(node()) as xs:string)?
  ) {
  let $title-function as function(node()) as xs:string :=
    ($title-function, crest:tei-title-function#1)[1]
  let $all := $list-function()
  return (
    <ul xmlns="http://www.w3.org/1999/xhtml" class="results">{
      for $result in subsequence($all, $start, $count) 
      let $api-name := replace(util:document-name($result), "\.xml$", "")
      return
        <li class="result">
          <a class="document" href="{$path-base}/{$api-name}">{$title-function($result)}</a>
          {
            for $additional in $additional-uris
            return
              <a class="alt" property="{$additional/@text}"
                href="{$path-base}/{$api-name}{if (starts-with($additional/@relative-uri, '?')) then '' else '/'}{$additional/@relative-uri}">{string($additional/@text)}</a>
          }
        </li>
    }</ul>,
    $start,
    $count,
    count($all)
  )
};

(:~ Delete an original text
 : #param $data-type data-type
 : @param $name The name of the resource
 : @return HTTP 204 (No data) if successful
 : @error HTTP 400 Cannot be deleted and a reason, including existing external references
 : @error HTTP 401 Not authorized
 : @error HTTP 403 Forbidden - logged in as a user who does not have write access to the document
 : @error HTTP 404 Not found 
 :)
declare function crest:delete(
    $data-type as xs:string,
    $name as xs:string
  ) as item()+ {
  let $doc := data:doc($data-type, $name)
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
        then
            let $doc-references := ridx:query-document($doc)/root(.)[not(. is $doc)]
            return
                if (exists($doc-references))
                then 
                    api:rest-error(400, "The document cannot be deleted because other documents reference this document.",
                      <documents>{
                          for $other-doc in $doc-references
                          group by $other-doc-uri := document-uri(root($other-doc))
                          return
                              <document>{data:db-path-to-api($other-doc-uri)}</document>
                      }</documents>)
                else
                    (
                      (: TODO: check for references! :)
                      let $r1 := xmldb:remove($collection, $resource)
                      let $r2 := ridx:remove($collection, $resource)
                      let $r3 := didx:remove($collection, $resource)
                      return
                        <rest:response>
                            <output:serialization-parameters>
                              <output:method>text</output:method>
                            </output:serialization-parameters>
                            <http:response status="204"/>
                        </rest:response>
                    )
        else
          crest:no-access()
    else
      api:rest-error(404, "Not found", $name)
};

declare function crest:post(
    $data-path as xs:string,
    $path-base as xs:string,
    $api-path-base as xs:string,
    $body as document-node(),
    $validation-function-boolean as 
      function(item(), document-node()?) as xs:boolean,
    $validation-function-report as 
      function(item(), document-node()?) as element(),
    $title-function as (function(node()) as xs:string)?
  ) as item()+ {
  crest:post($data-path, $path-base, $api-path-base, $body, $validation-function-boolean, $validation-function-report,
    $title-function, true(), ())
};

(:~ Post a new document
 : @param $data-path document data type and additional database path
 : @param $path-base base path for document type in the db
 : @param $api-path-base Base path of the API (/api/...)
 : @param $body The document
 : @param $validation-function-boolean function used to validate that returns a boolean
 : @param $validation-function-report function used to validate that returns a full report
 : @param $title-function Function that derives the title text from a document
 : @param $use-reference-index true() [default] if the reference index should be updated, false() or empty() otherwise
 : @return HTTP 201 if created successfully
 : @error HTTP 400 Invalid JLPTEI XML
 : @error HTTP 401 Not authorized
 : @error HTTP 500 Storage error
 :
 : Other effects: 
 : * A change record is added to the resource
 : * The new resource is owned by the current user, group owner=current user, and mode is 664
 : * A reference index is created for the resource
 :)
declare function crest:post(
    $data-path as xs:string,
    $path-base as xs:string,
    $api-path-base as xs:string,
    $body as document-node(),
    $validation-function-boolean as 
      function(item(), document-node()?) as xs:boolean,
    $validation-function-report as 
      function(item(), document-node()?) as element(),
    $title-function as (function(node()) as xs:string)?,
    $use-reference-index as xs:boolean?,
    $validate as xs:boolean?
  ) as item()+ { 
  if (sm:has-access(xs:anyURI($path-base), if ($validate) then "r" else "w"))
  then
    if ($validation-function-boolean($body, ()))
    then 
      let $title-function := 
        ($title-function, crest:tei-title-function#1)[1]
      let $paths := 
        data:new-path-to-resource(
          $data-path, 
          data:normalize-resource-title($title-function($body), false())
        )
      let $resource := $paths[2]
      let $collection := $paths[1]
      let $user := app:auth-user()
      return 
        if ($resource) 
        then
            if ($validate)
            then crest:validation-success()
            else (
                app:make-collection-path($collection, "/", sm:get-permissions(xs:anyURI($path-base))),
                let $db-path := xmldb:store($collection, $resource, $body)
                return
                  if ($db-path)
                  then
                    <rest:response>
                      <output:serialization-parameters>
                        <output:method>text</output:method>
                      </output:serialization-parameters>
                      <http:response status="201">
                        {
                          let $uri := xs:anyURI($db-path)
                          let $doc := doc($db-path)
                          let $change-record := crest:record-change($doc, "created")
                          return (
                            system:as-user("admin", $magic:password, (
                                sm:chown($uri, $user),
                                sm:chgrp($uri, "everyone"),
                                sm:chmod($uri, "rw-rw-r--")
                            )),
                            didx:reindex($doc),
                            if ($use-reference-index) then ridx:reindex($doc) else ()
                          )
                        }
                        <http:header
                          name="Location"
                          value="{concat($api-path-base, "/", substring-before($resource, ".xml"))}"/>
                      </http:response>
                    </rest:response>
                  else api:rest-error(500, "Cannot store the resource")
                )
        else
            let $message := "A title element with non-whitespace content is required"
            return
                if ($validate)
                then crest:validation-failure(<message>{$message}</message>)
                else api:rest-error(400, $message)
    else
        let $report := $validation-function-report($body, ())
        return
            if ($validate)
            then $report
            else api:rest-error(400, "Input document is not valid", $report)
  else crest:no-access()
};

declare function crest:put(
    $data-type as xs:string,
    $name as xs:string,
    $body as document-node(),
    $validation-function-boolean as 
      function(item(), document-node()?) as xs:boolean,
    $validation-function-report as 
      function(item(), document-node()?) as element()
  ) as item()+ {
  crest:put($data-type, $name, $body, $validation-function-boolean, $validation-function-report, true(), ())
};

(:~ Edit/replace a document in the database
 : or Validate a document as if editing (without writing the result)
 : Side effect: update the reference index, update document index
 : @param $data-type data type of document
 : @param $name Name of the document to replace
 : @param $body New document
 : @param $validation-function-boolean function used to validate that returns a boolean
 : @param $validation-function-report function used to validate that returns a full report
 : @param $use-reference-index true() [default] if reference index should be updated, else no reference index
 : @param $validate true() for validation only
 : @return HTTP 200 If successfully validated (but not written)
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
declare function crest:put(
    $data-type as xs:string,
    $name as xs:string,
    $body as document-node(),
    $validation-function-boolean as 
      function(item(), document-node()?) as xs:boolean,
    $validation-function-report as 
      function(item(), document-node()?) as element(),
    $use-reference-index as xs:boolean?,
    $validate as xs:boolean?
  ) as item()+ {
  let $doc := data:doc($data-type, $name)
  return
    if ($doc)
    then
      let $resource := util:document-name($doc)
      let $collection := util:collection-name($doc)
      let $uri := document-uri($doc)
      return  
        if (sm:has-access(xs:anyURI($uri), if ($validate) then "r" else "w"))
        then
            let $validation-result := $validation-function-boolean($body, $doc)
            return
                if ($validation-result)
                then
                    if ($validate)
                    then crest:validation-success()
                    else (: actual post :)
                        if (xmldb:store($collection, $resource, $body))
                        then
                          <rest:response>
                            {
                              let $doc := doc($uri)
                              return (
                                crest:record-change($doc, "edited"),
                                didx:reindex($doc),
                                if ($use-reference-index) then ridx:reindex($doc) else ()

                              )
                            }
                            <output:serialization-parameters>
                              <output:method>text</output:method>
                            </output:serialization-parameters>
                            <http:response status="204"/>
                          </rest:response>
                        else api:rest-error(500, "Cannot store the resource")
                else (: document is invalid :)
                    let $report :=  $validation-function-report($body, $doc)
                    return
                        if ($validate)
                        then $report (: not an error :)
                        else api:rest-error(400, "Input document is not valid",
                      $report)
        else crest:no-access()
    else 
      (: it is not clear that this is correct behavior for PUT.
       : If the user gives the document a name, maybe it should
       : just keep that resource name and create it?
       :)
      api:rest-error(404, "Not found", $name)
};


(:~ Get access/sharing data for a document
 : @param $name Name of document
 : @param $user Get access permissions as the given user 
 : @return HTTP 200 and an access structure (a:access), 
 :    or if $user is given, a:user-access 
 : @error HTTP 400 Requested user does not exist
 : @error HTTP 404 Document not found or inaccessible
 :)
declare function crest:get-access(
    $data-type as xs:string,
    $name as xs:string,
    $user as xs:string*
  ) as item()+ {
  let $doc := data:doc($data-type, $name)
  return
    if ($doc)
    then 
      if (exists($user))
      then
        try {
          acc:get-access-as-user($doc, $user[1])
        }
        catch error:BAD_REQUEST {
          api:rest-error(400, "User not found", $user[1])
        }
      else acc:get-access($doc)
    else api:rest-error(404, "Not found", $name)
};

(:~ Set access/sharing data for a document
 : Side effect: change access of refindex.
 : @param $name Name of document
 : @param $body New sharing rights, as an a:access structure 
 : @return HTTP 204 No data, access rights changed
 : @error HTTP 400 Access structure is invalid
 : @error HTTP 401 Not authorized
 : @error HTTP 403 Forbidden
 : @error HTTP 404 Document not found or inaccessible
 :)
declare function crest:put-access(
    $data-type as xs:string,
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  let $doc := data:doc($data-type, $name)
  let $access := $body/*
  let $uri := document-uri($doc)
  return
    if ($doc)
    then 
      try {
        acc:set-access($doc, $access),
        let $ridx-uri :=  mirror:mirror-path($ridx:ridx-path, $uri)
        where doc($ridx-uri)
        return
            mirror:mirror-permissions($ridx:ridx-path, $uri, $ridx-uri), 
        <rest:response>
          <output:serialization-parameters>
            <output:method>text</output:method>
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

declare function crest:validation-success(
    ) as element(report) {
    <report>
        <status>valid</status>
    </report>
};

declare function crest:validation-failure(
    $messages as element(message)+
    ) as element(report) {
    <report>
        <status>invalid</status>
        {$messages}
    </report>
    };