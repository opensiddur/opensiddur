xquery version "3.1";
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
  at "../../modules/api.xqm";
import module namespace crest="http://jewishliturgy.org/modules/common-rest"
  at "../../modules/common-rest.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "../../modules/data.xqm";
import module namespace orig="http://jewishliturgy.org/api/data/original"
  at "original.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "../../modules/paths.xqm";

declare variable $notes:data-type := "notes";
declare variable $notes:schema := concat($paths:schema-base, "/annotation.rnc");
declare variable $notes:schematron := concat($paths:schema-base, "/annotation.xsl2");
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

(:~ Get an XML annotation by resource name and id
 : @param $name Document name
 : @param $id The xml:id of the annotation to get
 : @return The tei:note containing the requested annotation
 : @error HTTP 404 Not found (or not available)
 :)
declare
  %rest:GET
  %rest:path("/api/data/notes/{$name}/{$id}")
  %rest:produces("application/xml", "text/xml", "application/tei+xml")
  %output:method("xml")
  function notes:get-note(
    $name as xs:string,
    $id as xs:string
  ) as item()+ {
  let $notes-doc := crest:get($notes:data-type, $name)
  return
    if ($notes-doc instance of document-node())
    then
      let $note := $notes-doc//tei:note[@xml:id=$id]
      return
        if (exists($note))
        then document { $note }
        else api:rest-error(404, "Note not found", $id)
    else
      (: it's an error condition :)
      $notes-doc
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
  %output:method("xhtml")
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
  let $c := collection($notes:path-base)
  return 
    $c//tei:titleStmt/tei:title[ft:query(.,$query)]|$c/tei:text[ft:query(.,$query)]
};

declare function notes:list-function(
  ) as element()* {
  for $doc in collection($notes:path-base)/tei:TEI
  order by $doc//tei:titleStmt/(tei:title[@type="main"]|tei:title[not(@type)])[1] ascending
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

declare function notes:post(
    $body as document-node()
  ) as item()+ {
  notes:post($body, ())
};

(:~ Post a new annotation document 
 : @param $body The annotation document
 : @param $validate Validate the document instead of posting
 : @return HTTP 200 if posted successfully
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
  %rest:query-param("validate", "{$validate}")
  %rest:consumes("application/xml", "application/tei+xml", "text/xml")
  function notes:post(
    $body as document-node(),
    $validate as xs:string?
  ) as item()+ {
  let $data-path := concat($notes:data-type, "/", $body/tei:TEI/@xml:lang)
  let $api-path-base := api:uri-of($notes:api-path-base)
  return
    if ($validate)
    then
        crest:validation-report(
            $data-path,
            $notes:path-base,
            $api-path-base,
            $body,
            notes:validate#2,
            notes:validate-report#2,
            crest:tei-title-function#1
          )
    else
      crest:post(
        $data-path,
        $notes:path-base,
        $api-path-base,
        $body,
        notes:validate#2,
        notes:validate-report#2,
        crest:tei-title-function#1
      )
};

(:~ transform to insert or replace elements in an in-memory document
 : we do not use XQuery update because it doesn't work on in-memory documents
 :
 : @param $nodes Nodes that are being operated on
 : @param $annotation-to-insert The annotation that will be inserted into j:annotations
 : @param $annotation-to-replace The annotation that should be replaced. If it does not exist, the annotation will be
 :          inserted at the end of j:annotations
 : @return $node with insertions or replacements
 :)
declare function notes:insert-or-replace(
  $nodes as node()*,
  $annotation-to-insert as element(tei:note),
  $annotation-to-replace as element(tei:note)?
) {
  for $node in $nodes
  return
    typeswitch ($node)
    case document-node() return
      document { notes:insert-or-replace($node/node(), $annotation-to-insert, $annotation-to-replace) }
    case element(j:annotations) return
      element { QName(namespace-uri($node), name($node)) } {
        $node/@*,
        if (empty($annotation-to-replace))
        then (
          $node/node(),
          $annotation-to-insert
        )
        else notes:insert-or-replace($node/node(), $annotation-to-insert, $annotation-to-replace)
      }
    case element(tei:note) return
      if (exists($annotation-to-replace) and $annotation-to-replace is $node)
      then $annotation-to-insert
      else $node
    case element() return
      element { QName(namespace-uri($node), name($node)) } {
        $node/@*,
        notes:insert-or-replace($node/node(), $annotation-to-insert, $annotation-to-replace)
      }
    default return $node
};

(:~ Edit or insert a note into a document
 : @param $name Document name
 : @param $body Body of the note
 : @return HTTP 200 if the edit was successful
 : @return HTTP 201 if a new document was created
 : @error HTTP 400 for invalid XML, including missing @xml:id
 : @error HTTP 401 not authorized
 :
 : Other effects:
 : * A change record is added to the resource
 : * If a new resource is created, it is owned by the current user, group owner=current user, and mode is 664
 :)
declare
  %rest:POST
  %rest:path("/api/data/notes/{$name}")
  %rest:consumes("application/xml", "application/tei+xml", "text/xml")
  function notes:post-note(
    $name as xs:string,
    $body as element(tei:note)
  ) as item()+ {
  let $doc := data:doc($notes:data-type, $name)
  return
    if (not($body/@xml:id/string()))
    then
      api:rest-error(400, "Input annotation requires an xml:id")
    else if ($doc)
    then
      let $resource := util:document-name($doc)
      let $collection := util:collection-name($doc)
      let $uri := document-uri($doc)
      return
        if (sm:has-access(xs:anyURI($uri), "w"))
        then
          (: existing document with write access :)
          let $existing-note := $doc//tei:note[@xml:id=$body/@xml:id]
          let $inserted := notes:insert-or-replace($doc, $body, $existing-note)
          return notes:put($name, $inserted)
        else
          crest:no-access()
    else
      (: document does not exist, return HTTP 404 :)
      api:rest-error(404, "Not found", $name)
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
