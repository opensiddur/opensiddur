xquery version "3.0";
(: Copyright 2012-2013 Efraim Feinstein <efraim@opensiddur.org>
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
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace api="http://jewishliturgy.org/modules/api"
  at "/db/code/api/modules/api.xqm";
import module namespace crest="http://jewishliturgy.org/modules/common-rest"
  at "/db/code/api/modules/common-rest.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "/db/code/api/modules/data.xqm";
import module namespace orig="http://jewishliturgy.org/api/data/original"
  at "/db/code/api/data/original.xqm";

declare variable $notes:data-type := "notes";
declare variable $notes:schema := "/db/schema/annotation.rnc";
declare variable $notes:schematron := "/db/schema/annotation.xsl2";
declare variable $notes:path-base := concat($data:path-base, "/", $notes:data-type);
declare variable $notes:api-path-base := concat("/api/data/", $notes:data-type);

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
  crest:validate($doc, $old-doc,
    xs:anyURI($notes:schema), xs:anyURI($notes:schematron),
    if (exists($old-doc)) then orig:validate-changes#2 else ()
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
  crest:validate-report($doc, $old-doc,
    xs:anyURI($notes:schema), xs:anyURI($notes:schematron),
    if (exists($old-doc)) then orig:validate-changes#2 else ()
  )
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
  crest:get($notes:data-type, $name)
};

(:~ List or full-text query annotation documents
 : @param $q text of the query, empty string for all
 : @param $start first document to list
 : @param $max-results number of documents to list 
 : @return a list of documents that match the search. If the documents match a query, return the context.
 : @error HTTP 404 Not found
 :)
declare 
  %rest:GET
  %rest:path("/api/data/notes")
  %rest:query-param("q", "{$q}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("html5")  
  function notes:list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
  ) as item()+ {
  crest:list(
    $q, $start, $max-results,
    "Annotation data API",
    api:uri-of($notes:api-path-base),
    notes:query-function#1,
    notes:list-function#0,
    <crest:additional text="access" relative-uri="access"/>, 
    ()
  )
};

(: support function :) 
declare function notes:query-function(
    $query as xs:string
  ) as element()* {
  for $doc in
    collection($notes:path-base)//(tei:title|j:annotations)[ft:query(.,$query)]
  order by $doc//(tei:title[@type="main"]|tei:title[not(@type)])[1] ascending
  return $doc
};

declare function notes:list-function(
  ) as element()* {
  for $doc in collection($notes:path-base)/tei:TEI
  order by $doc//(tei:title[@type="main"]|tei:title[not(@type)])[1] ascending
  return $doc
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
  crest:delete($notes:data-type, $name)
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
  crest:post(
    concat($notes:data-type, "/", $body/tei:TEI/@xml:lang), 
    $notes:path-base,
    api:uri-of($notes:api-path-base),
    $body,
    notes:validate#2,
    notes:validate-report#2,
    ()
  )
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
  crest:put(
    $notes:data-type, 
    $name,
    $body,
    notes:validate#2, notes:validate-report#2)
};

(:~ Get access/sharing data for an annotation document
 : @param $name Name of document
 : @param $user User to get access as
 : @return HTTP 200 and an access structure (a:access) or user access (a:user-access)
 : @error HTTP 400 User does not exist
 : @error HTTP 404 Document not found or inaccessible
 :)
declare 
  %rest:GET
  %rest:path("/api/data/notes/{$name}/access")
  %rest:query-param("user", "{$user}")
  %rest:produces("application/xml")
  function notes:get-access(
    $name as xs:string,
    $user as xs:string*
  ) as item()+ {
  crest:get-access($notes:data-type, $name, $user)
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
  crest:put-access($notes:data-type, $name, $body)
};
