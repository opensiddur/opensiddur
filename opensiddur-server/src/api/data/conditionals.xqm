xquery version "3.0";
(: Copyright 2012-2013 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(:~ Conditional data API
 : @author Efraim Feinstein
 :)

module namespace cnd = 'http://jewishliturgy.org/api/data/conditionals';

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
  
declare variable $cnd:data-type := "conditionals";
declare variable $cnd:schema := "/db/schema/conditional.rnc";
declare variable $cnd:schematron := "/db/schema/conditional.xsl2";
declare variable $cnd:path-base := concat($data:path-base, "/", $cnd:data-type);
declare variable $cnd:api-path-base := concat("/api/data/", $cnd:data-type);

(:~ special validation for conditionals
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @return A report element, indicating validity
 :)
declare function cnd:validate-conditionals(
  $doc as item(),
  $old-doc as document-node()?
  ) as element() {
  let $types-declared := $doc//tei:fsDecl/@type/string()
  let $messages := 
    for $fs-declaration in 
      collection($cnd:path-base)[not(. is $old-doc)]//
        tei:fsDecl[@type=$types-declared] 
    return
      <message>Type '{$fs-declaration/@type/string()}' is already declared in {crest:tei-title-function(root($fs-declaration))}
      $old-doc={exists($old-doc)}={document-uri($old-doc)}
      root($fs-declaration)={document-uri(root($fs-declaration))}
      </message>
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

(:~ validate 
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @return true() if valid, false() if not
 : @see lnk:validate-report
 :) 
declare function cnd:validate(
  $doc as item(),
  $old-doc as document-node()?
  ) as xs:boolean {
  crest:validate(
    $doc, $old-doc, 
    xs:anyURI($cnd:schema), xs:anyURI($cnd:schematron),
    (
    cnd:validate-conditionals#2,
    if (exists($old-doc)) then orig:validate-changes#2 else ()
    )
  )
};

(:~ validate, returning a validation report 
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @return true() if valid, false() if not
 : @see lnk:validate
 :) 
declare function cnd:validate-report(
  $doc as item(),
  $old-doc as document-node()?
  ) as element() {
  crest:validate-report(
    $doc, $old-doc, 
    xs:anyURI($cnd:schema), xs:anyURI($cnd:schematron),
    (
    cnd:validate-conditionals#2,
    if (exists($old-doc)) then orig:validate-changes#2 else ()
    )
  )
};

(:~ Get a conditional declaration document by name
 : @param $name Document name as a string
 : @error HTTP 404 Not found (or not available)
 :)
declare
  %rest:GET
  %rest:path("/api/data/conditionals/{$name}")
  %rest:produces("application/xml", "text/xml", "application/tei+xml")
  function cnd:get(
    $name as xs:string
  ) as item()+ {
  crest:get($cnd:data-type, $name)
};


(:~ List or full-text query conditionals data. 
 : Querying conditionals data will search for titles and
 : feature/feature structure descriptions
 : @param $q text of the query, empty string for all
 : @param $start first document to list
 : @param $max-results number of documents to list 
 : @return a list of documents that match the search. If the documents match a query, return the context.
 : @error HTTP 404 Not found
 :)
declare 
  %rest:GET
  %rest:path("/api/data/conditionals")
  %rest:query-param("q", "{$q}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("html5")  
  function cnd:list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
  ) as item()+ {
  crest:list($q, $start, $max-results,
    "Conditional declaration data API", api:uri-of($cnd:api-path-base),
    cnd:query-function#1, cnd:list-function#0,
    (), (: conditionals should not support access restrictions? :) 
    ()
  )
};

(: @return (list, start, count, n-results) :) 
declare function cnd:query-function(
    $query as xs:string
  ) as element()* {
  for $doc in
      collection($cnd:path-base)//(tei:title|tei:fsDescr|tei:fDescr)[ft:query(.,$query)]
  order by $doc//tei:title[@type="main"] ascending
  return $doc
};

declare function cnd:list-function(
  ) as element()* {
  for $doc in collection($cnd:path-base)/tei:TEI
  order by $doc//tei:title[@type="main"] ascending
  return $doc
};

(:~ Delete a conditionals text
 : @param $name The name of the text
 : @return HTTP 204 (No data) if successful
 : @error HTTP 400 Cannot be deleted and a reason, including existing external references
 : @error HTTP 401 Not authorized
 : @error HTTP 403 Forbidden - logged in as a user who does not have write access to the document
 : @error HTTP 404 Not found 
 :)
declare 
  %rest:DELETE
  %rest:path("/api/data/conditionals/{$name}")
  function cnd:delete(
    $name as xs:string
  ) as item()+ {
  crest:delete($cnd:data-type, $name)
};

(:~ Post a new conditionals document 
 : @param $body The conditionals document
 : @return HTTP 201 if created successfully
 : @error HTTP 400 Invalid linkage XML
 : @error HTTP 401 Not authorized
 : @error HTTP 500 Storage error
 :
 : Other effects: 
 : * A change record is added to the resource
 : * The new resource is owned by the current user, group owner=current user, and mode is 664
 :)
declare
  %rest:POST("{$body}")
  %rest:path("/api/data/conditionals")
  %rest:consumes("application/xml", "application/tei+xml", "text/xml")
  function cnd:post(
    $body as document-node()
  ) as item()+ {
  crest:post(
    $cnd:data-type,
    $cnd:path-base,
    api:uri-of($cnd:api-path-base),
    $body,
    cnd:validate#2,
    cnd:validate-report#2,
    ()
  )
};

(:~ Edit/replace a conditionals document in the database
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
  %rest:path("/api/data/conditionals/{$name}")
  %rest:consumes("application/xml", "text/xml")
  function cnd:put(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  crest:put(
    $cnd:data-type, $name, $body,
    cnd:validate#2,
    cnd:validate-report#2
  )
};
