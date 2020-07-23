xquery version "3.1";
(: Copyright 2012-2014 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(:~ Linkage data API
 : @author Efraim Feinstein
 :)

module namespace lnk = 'http://jewishliturgy.org/api/data/linkage';

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace api="http://jewishliturgy.org/modules/api"
  at "../../modules/api.xqm";
import module namespace crest="http://jewishliturgy.org/modules/common-rest"
  at "../../modules/common-rest.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "../../modules/data.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "../modules/format.xqm";
import module namespace orig="http://jewishliturgy.org/api/data/original"
  at "original.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "../../modules/paths.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "../../modules/follow-uri.xqm";
  
declare variable $lnk:data-type := "linkage";
declare variable $lnk:no-lang := "none";  (: no language :)
declare variable $lnk:schema := concat($paths:schema-base, "/linkage.rnc");
declare variable $lnk:schematron := concat($paths:schema-base, "/linkage.xsl2");
declare variable $lnk:path-base := concat($data:path-base, "/", $lnk:data-type);
declare variable $lnk:api-path-base := concat("/api/data/", $lnk:data-type);

(:~ @return the documents that are linked by $doc :)
declare function lnk:get-linked-documents(
  $doc as document-node()
  ) as xs:string+ {
  distinct-values(
    for $ptr in j:parallelText//tei:ptr
    for $target in tokenize($ptr/@target, "\s+")
    return uri:absolutize-uri(uri:uri-base-path($target), $ptr)
  )
};

(:~ validate 
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @return true() if valid, false() if not
 : @see lnk:validate-report
 :) 
declare function lnk:validate(
  $doc as item(),
  $old-doc as document-node()?
  ) as xs:boolean {
  crest:validate(
    $doc, $old-doc, 
    xs:anyURI($lnk:schema), xs:anyURI($lnk:schematron),
    if (exists($old-doc)) then orig:validate-changes#2 else ()
  )
};

(:~ validate, returning a validation report 
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @return true() if valid, false() if not
 : @see lnk:validate
 :) 
declare function lnk:validate-report(
  $doc as item(),
  $old-doc as document-node()?
  ) as element() {
  crest:validate-report(
    $doc, $old-doc, 
    xs:anyURI($lnk:schema), xs:anyURI($lnk:schematron),
    if (exists($old-doc)) then orig:validate-changes#2 else ()
  )
};

(:~ Get an XML linkage document by name
 : @param $name Document name as a string
 : @error HTTP 404 Not found (or not available)
 :)
declare
  %rest:GET
  %rest:path("/api/data/linkage/{$name}")
  %rest:produces("application/xml", "text/xml", "application/tei+xml")
  function lnk:get(
    $name as xs:string
  ) as item()+ {
  crest:get($lnk:data-type, $name)
};

(:~ Get a version of the linkage data resource with unflattened/combined hierarchies
 : @param $name The resource to get
 : @return HTTP 200 A TEI header with a combined hierarchy version of the resource as XML
 : @error HTTP 404 Not found (or not available)
 :)
declare
  %rest:GET
  %rest:path("/api/data/linkage/{$name}/combined")
  %rest:produces("application/xml", "text/xml")
  %output:method("xml")
  function lnk:get-combined(
    $name as xs:string
  ) as item()+ {
  let $doc := crest:get($lnk:data-type, $name)
  return
    if ($doc instance of document-node())
    then
        let $deps := format:unflatten-dependencies($doc, map {})
        return format:unflatten($doc, map {}, $doc)
    else $doc
};

(:~ List or full-text query linkage data. Note that querying
 : linkage data is not super-useful.
 : @param $q text of the query, empty string for all
 : @param $start first document to list
 : @param $max-results number of documents to list 
 : @return a list of documents that match the search. If the documents match a query, return the context.
 : @error HTTP 404 Not found
 :)
declare 
  %rest:GET
  %rest:path("/api/data/linkage")
  %rest:query-param("q", "{$q}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("xhtml")
  function lnk:list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
  ) as item()+ {
  crest:list($q, $start, $max-results,
    "Linkage data API", api:uri-of($lnk:api-path-base),
    lnk:query-function#1, lnk:list-function#0,
    (<crest:additional text="access" relative-uri="access"/>,
    <crest:additional text="combined" relative-uri="combined"/>),
    ()
  )
};

(: @return (list, start, count, n-results) :) 
declare function lnk:query-function(
    $query as xs:string
  ) as element()* {
  let $c := collection($lnk:path-base)
  return $c//tei:title[ft:query(.,$query)]|$c//tei:idno[ft:query(.,$query)]|$c//tei:text[ft:query(.,$query)]
};

declare function lnk:list-function(
  ) as element()* {
  for $doc in collection($lnk:path-base)/tei:TEI
  order by $doc//tei:title[@type="main"] ascending
  return $doc
};

(:~ Delete a linkage text
 : @param $name The name of the text
 : @return HTTP 204 (No data) if successful
 : @error HTTP 400 Cannot be deleted and a reason, including existing external references
 : @error HTTP 401 Not authorized
 : @error HTTP 403 Forbidden - logged in as a user who does not have write access to the document
 : @error HTTP 404 Not found 
 :)
declare 
  %rest:DELETE
  %rest:path("/api/data/linkage/{$name}")
  function lnk:delete(
    $name as xs:string
  ) as item()+ {
  crest:delete($lnk:data-type, $name)
};

(:~ Post a new linkage document 
 : @param $body The linkage document
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
  %rest:path("/api/data/linkage")
  %rest:consumes("application/xml", "application/tei+xml", "text/xml")
  function lnk:post(
    $body as document-node()
  ) as item()+ {
  crest:post(
    concat($lnk:data-type, "/", 
        ($body/tei:TEI/@xml:lang/string()[.], $lnk:no-lang)[1]
        ),
    $lnk:path-base,
    api:uri-of($lnk:api-path-base),
    $body,
    lnk:validate#2,
    lnk:validate-report#2,
    ()
  )
};

(:~ Edit/replace a linkage document in the database
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
  %rest:path("/api/data/linkage/{$name}")
  %rest:consumes("application/xml", "text/xml")
  function lnk:put(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  crest:put(
    $lnk:data-type, $name, $body,
    lnk:validate#2,
    lnk:validate-report#2
  )
};

(:~ Get access/sharing data for a document
 : @param $name Name of document
 : @param $user User to get access as
 : @return HTTP 200 and an access structure (a:access) or user access (a:user-access)
 : @error HTTP 400 User does not exist
 : @error HTTP 404 Document not found or inaccessible
 :)
declare 
  %rest:GET
  %rest:path("/api/data/linkage/{$name}/access")
  %rest:query-param("user", "{$user}")
  %rest:produces("application/xml")
  function lnk:get-access(
    $name as xs:string,
    $user as xs:string*
  ) as item()+ {
  crest:get-access($lnk:data-type, $name, $user)
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
  %rest:path("/api/data/linkage/{$name}/access")
  %rest:consumes("application/xml", "text/xml")
  function lnk:put-access(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  (: TODO: a linkage document cannot have looser read access
   : restrictions than any of the documents it links
   :)
  crest:put-access($lnk:data-type, $name, $body)
};
