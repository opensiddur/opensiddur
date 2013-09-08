xquery version "3.0";
(: Copyright 2012-2013 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(:~ Sources (bibliographic) data API
 : @author Efraim Feinstein
 :)

module namespace src = 'http://jewishliturgy.org/api/data/sources';

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace api="http://jewishliturgy.org/modules/api"
  at "/db/code/api/modules/api.xqm";
import module namespace crest="http://jewishliturgy.org/modules/common-rest"
  at "/db/code/api/modules/common-rest.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "/db/code/api/modules/data.xqm";

declare variable $src:data-type := "sources";
declare variable $src:schema := "/db/schema/bibliography.rnc";
declare variable $src:schematron := "/db/schema/bibliography.xsl2";
declare variable $src:path-base := concat($data:path-base, "/", $src:data-type);
declare variable $src:api-path-base := concat("/api/data/", $src:data-type);

(:~ validate 
 : @param $doc The document to be validated
 : @return true() if valid, false() if not
 : @see src:validate-report
 :) 
declare function src:validate(
  $doc as item(),
  $old-doc as document-node()?
  ) as xs:boolean {
  crest:validate($doc, $old-doc, 
    xs:anyURI($src:schema), xs:anyURI($src:schematron), ())
};

(:~ validate, returning a validation report 
 : @param $doc The document to be validated
 : @return true() if valid, false() if not
 : @see src:validate
 :) 
declare function src:validate-report(
  $doc as item(),
  $old-doc as document-node()?
  ) as element() {
  crest:validate-report($doc, $old-doc, 
    xs:anyURI($src:schema), xs:anyURI($src:schematron), ())
};

(:~ Get an XML document by name
 : @param $name Document name as a string
 : @error HTTP 404 Not found (or not available)
 :)
declare
  %rest:GET
  %rest:path("/api/data/sources/{$name}")
  %rest:produces("application/xml", "text/xml", "application/tei+xml")
  function src:get(
    $name as xs:string
  ) as item()+ {
  crest:get($src:data-type, $name)
};

(:~ List or full-text query bibliographic data
 : @param $q text of the query, empty string for all
 : @param $start first document to list
 : @param $max-results number of documents to list 
 : @return a list of documents that match the search. If the documents match a query, return the context.
 : @error HTTP 404 Not found
 :)
declare 
  %rest:GET
  %rest:path("/api/data/sources")
  %rest:query-param("q", "{$q}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("html5")  
  function src:list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
  ) as item()+ {
  crest:list($q, $start, $max-results,
    "Bibliographic data API", api:uri-of($src:api-path-base),
    src:query-function#1, src:list-function#0,
    (), src:title-function#1
  )
};

(: Support function :) 
declare function src:query-function(
    $query as xs:string
    ) as element()* {
  for $doc in
    collection($src:path-base)//tei:biblStruct[ft:query(.,$query)]
  order by $doc//tei:title(:[@type="main" or not(@type)]:) ascending
  return $doc
};

declare function src:list-function(
  ) as element()* {
  for $doc in collection($src:path-base)/tei:biblStruct
  order by $doc//tei:title(:[@type="main" or not(@type)]:) ascending
  return $doc
};

declare function src:title-function(
  $doc as document-node()
  ) as xs:string {
  $doc//tei:title/string()
};

(:~ Delete a bibliographic entry text
 : @param $name The name of the text
 : @return HTTP 204 (No data) if successful
 : @error HTTP 400 Cannot be deleted and a reason, including existing external references
 : @error HTTP 401 Not authorized
 : @error HTTP 403 Forbidden - logged in as a user who does not have write access to the document
 : @error HTTP 404 Not found 
 :)
declare 
  %rest:DELETE
  %rest:path("/api/data/sources/{$name}")
  function src:delete(
    $name as xs:string
  ) as item()+ {
  crest:delete($src:data-type, $name)
};

(:~ Post a new bibliographic document 
 : @param $body The bibliographic document
 : @return HTTP 201 if created successfully
 : @error HTTP 400 Invalid bibliographic XML
 : @error HTTP 401 Not authorized
 : @error HTTP 500 Storage error
 :
 : Other effects: 
 : * The new resource is owned by the current user, group owner=everyone, and mode is 664
 :)
declare
  %rest:POST("{$body}")
  %rest:path("/api/data/sources")
  %rest:consumes("application/xml", "application/tei+xml", "text/xml")
  function src:post(
    $body as document-node()
  ) as item()+ {
  crest:post(
      $src:data-type,
      $src:path-base,
      api:uri-of($src:api-path-base),
      $body,
      src:validate#2,
      src:validate-report#2,
      src:title-function#1
    )
};

(:~ Edit/replace a bibliographic document in the database
 : @param $name Name of the document to replace
 : @param $body New document
 : @return HTTP 204 If successful
 : @error HTTP 400 Invalid XML
 : @error HTTP 401 Unauthorized - not logged in
 : @error HTTP 403 Forbidden - the document can be found, but is not writable by you
 : @error HTTP 404 Not found
 : @error HTTP 500 Storage error
 :
 :)
declare
  %rest:PUT("{$body}")
  %rest:path("/api/data/sources/{$name}")
  %rest:consumes("application/xml", "text/xml")
  function src:put(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  crest:put(
    $src:data-type, $name, $body,
    src:validate#2,
    src:validate-report#2
    )
};
