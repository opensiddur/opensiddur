xquery version "3.1";
(: Copyright 2012-2014 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(:~ Dictionary data API
 : @author Efraim Feinstein
 :)

module namespace dict = 'http://jewishliturgy.org/api/data/dictionaries';

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace api="http://jewishliturgy.org/modules/api"
  at "../../modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "../../modules/app.xqm";
import module namespace crest="http://jewishliturgy.org/modules/common-rest"
  at "../../modules/common-rest.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "../../modules/data.xqm";
import module namespace orig="http://jewishliturgy.org/api/data/original"
  at "original.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "../../modules/paths.xqm";

declare variable $dict:data-type := "dictionaries";
declare variable $dict:schema := concat($paths:schema-base, "/dictionary.rnc");
declare variable $dict:schematron := concat($paths:schema-base, "/dictionary.xsl2");
declare variable $dict:path-base := concat($data:path-base, "/", $dict:data-type);
declare variable $dict:api-path-base := concat("/api/data/", $dict:data-type);  

(:~ validate 
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @return true() if valid, false() if not
 : @see orig:validate-report
 :) 
declare function dict:validate(
  $doc as item(),
  $old-doc as document-node()?
  ) as xs:boolean {
  crest:validate(
    $doc, $old-doc, 
    xs:anyURI($dict:schema), xs:anyURI($dict:schematron),
    if (exists($old-doc)) then orig:validate-changes#2 else ()
  )
};

(:~ validate, returning a validation report 
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @return true() if valid, false() if not
 : @see orig:validate
 :) 
declare function dict:validate-report(
  $doc as item(),
  $old-doc as document-node()?
  ) as element() {
  crest:validate-report(
    $doc, $old-doc, 
    xs:anyURI($dict:schema), xs:anyURI($dict:schematron),
    if (exists($old-doc)) then orig:validate-changes#2 else ()
  )
};

(:~ Get an XML document by name
 : @param $name Document name as a string
 : @error HTTP 404 Not found (or not available)
 :)
declare
  %rest:GET
  %rest:path("/api/data/dictionaries/{$name}")
  %rest:produces("application/xml", "text/xml", "application/tei+xml")
  function dict:get(
    $name as xs:string
  ) as item()+ {
  crest:get($dict:data-type, $name)
};

(:~ List or full-text query original data
 : @param $q text of the query, empty string for all
 : @param $start first document to list
 : @param $max-results number of documents to list 
 : @return a list of documents that match the search. If the documents match a query, return the context.
 : @error HTTP 404 Not found
 :)
declare 
  %rest:GET
  %rest:path("/api/data/dictionaries")
  %rest:query-param("q", "{$q}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("xhtml")
  function dict:list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
  ) as item()+ {
  crest:list($q, $start, $max-results,
    "Dictionary data API", api:uri-of($dict:api-path-base),
    dict:query-function#1, dict:list-function#0,
    <crest:additional text="access" relative-uri="access"/>, 
    ()
  )
};

(: support function for queries :)
declare function dict:query-function(
  $query as xs:string
  ) as element()* {
  let $c := collection($dict:path-base)
  return $c//tei:title[ft:query(., $query)]|
        $c//tei:text[ft:query(.,$query)]
};

(: support function for list :) 
declare function dict:list-function(
  ) as element()* {
  for $doc in collection($dict:path-base)/tei:TEI
  order by $doc//tei:title[@type="main"] ascending
  return $doc  
};  

(:~ Delete a dictionary text
 : @param $name The name of the text
 : @return HTTP 204 (No data) if successful
 : @error HTTP 400 Cannot be deleted and a reason, including existing external references
 : @error HTTP 401 Not authorized
 : @error HTTP 403 Forbidden - logged in as a user who does not have write access to the document
 : @error HTTP 404 Not found 
 :)
declare 
  %rest:DELETE
  %rest:path("/api/data/dictionaries/{$name}")
  function dict:delete(
    $name as xs:string
  ) as item()+ {
  crest:delete($dict:data-type, $name)
};

declare function dict:post(
    $body as document-node()
  ) as item()+ {
    dict:post($body, ())
};

(:~ Post a new dictionary document 
 : @param $body The JLPTEI document
 : @param $validate If present, validate instead of posting
 : @return HTTP 200 if validated successfully
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
  %rest:path("/api/data/dictionaries")
  %rest:query-param("validate", "{$validate}")
  %rest:consumes("application/xml", "application/tei+xml", "text/xml")
  function dict:post(
    $body as document-node(),
    $validate as xs:string?
  ) as item()+ {
  let $data-path := concat($dict:data-type, "/", $body/tei:TEI/@xml:lang)
  let $api-path-base := api:uri-of($dict:api-path-base)
  return
    if ($validate)
    then
        crest:validation-report(
                $data-path,
                $dict:path-base,
                $api-path-base,
                $body,
                dict:validate#2,
                dict:validate-report#2,
                ()
              )
    else
      crest:post(
        $data-path,
        $dict:path-base,
        $api-path-base,
        $body,
        dict:validate#2,
        dict:validate-report#2,
        ()
      )
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
  %rest:path("/api/data/dictionaries/{$name}")
  %rest:consumes("application/xml", "text/xml")
  function dict:put(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  crest:put(
    $dict:data-type, $name, $body,
    dict:validate#2,
    dict:validate-report#2
  )
};

(:~ Get access/sharing data for a dictionary document
 : @param $name Name of document
 : @param $user User to get access as
 : @return HTTP 200 and an access structure (a:access) or user access (a:user-access)
 : @error HTTP 400 User does not exist
 : @error HTTP 404 Document not found or inaccessible
 :)
declare 
  %rest:GET
  %rest:path("/api/data/dictionaries/{$name}/access")
  %rest:query-param("user", "{$user}")
  %rest:produces("application/xml")
  function dict:get-access(
    $name as xs:string,
    $user as xs:string*
  ) as item()+ {
  crest:get-access($dict:data-type, $name, $user)
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
  %rest:path("/api/data/dictionaries/{$name}/access")
  %rest:consumes("application/xml", "text/xml")
  function dict:put-access(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  crest:put-access($dict:data-type, $name, $body)
};
