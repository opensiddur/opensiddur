xquery version "3.0";
(: Copyright 2012-2013 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(:~ Styles data API
 : @author Efraim Feinstein
 :)

module namespace sty = 'http://jewishliturgy.org/api/data/styles';

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

declare variable $sty:data-type := "styles";
declare variable $sty:schema := concat($crest:schema-base, "/style.rnc");
declare variable $sty:schematron := concat($crest:schema-base, "/style.xsl2");
declare variable $sty:path-base := concat($data:path-base, "/", $sty:data-type);
declare variable $sty:api-path-base := concat("/api/data/", $sty:data-type);  

(:~ validate 
 : @param $doc The style document to be validated
 : @param $old-doc The style document it is replacing, if any
 : @return true() if valid, false() if not
 : @see orig:validate-report
 :) 
declare function sty:validate(
  $doc as item(),
  $old-doc as document-node()?
  ) as xs:boolean {
  crest:validate(
    $doc, $old-doc, 
    xs:anyURI($sty:schema), xs:anyURI($sty:schematron),
    if (exists($old-doc)) then orig:validate-changes#2 else ()
  )
};

(:~ validate, returning a validation report 
 : @param $doc The style document to be validated
 : @param $old-doc The style document it is replacing, if any
 : @return true() if valid, false() if not
 : @see orig:validate
 :) 
declare function sty:validate-report(
  $doc as item(),
  $old-doc as document-node()?
  ) as element() {
  crest:validate-report(
    $doc, $old-doc, 
    xs:anyURI($sty:schema), xs:anyURI($sty:schematron),
    if (exists($old-doc)) then orig:validate-changes#2 else ()
  )
};

(:~ Get a style document by name as XML
 : @param $name Document name as a string
 : @error HTTP 404 Not found (or not available)
 :)
declare
  %rest:GET
  %rest:path("/api/data/styles/{$name}")
  %rest:produces("application/xml", "text/xml", "application/tei+xml")
  function sty:get-xml(
    $name as xs:string
  ) as item()+ {
  crest:get($sty:data-type, $name)
};

declare 
  %rest:GET
  %rest:path("/api/data/styles/{$name}")
  %rest:produces("text/css", "text/plain")
  %output:method("text")
  %output:media-type("text/css")
  function sty:get-css(
    $name as xs:string
  ) as item()+ {
  let $xml := sty:get-xml(replace($name, "\.css$", ""))
  return
    if ($xml instance of document-node())
    then
      $xml//j:stylesheet[@scheme="css"]/string()
    else
      $xml
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
  %rest:path("/api/data/styles")
  %rest:query-param("q", "{$q}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("html5")  
  function sty:list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
  ) as item()+ {
  crest:list($q, $start, $max-results,
    "Styles API", api:uri-of($sty:api-path-base),
    sty:query-function#1, sty:list-function#0,
    <crest:additional text="access" relative-uri="access"/>, 
    ()
  )
};

(: support function for queries :)
declare function sty:query-function(
  $query as xs:string
  ) as element()* {
  for $doc in
      collection($sty:path-base)//(tei:title|tei:text)[ft:query(.,$query)]
  order by $doc//tei:title[@type="main"] ascending
  return $doc
};

(: support function for list :) 
declare function sty:list-function(
  ) as element()* {
  for $doc in collection($sty:path-base)/tei:TEI
  order by $doc//tei:title[@type="main"] ascending
  return $doc  
};  

(:~ Delete a style
 : @param $name The name of the text
 : @return HTTP 204 (No data) if successful
 : @error HTTP 400 Cannot be deleted and a reason, including existing external references
 : @error HTTP 401 Not authorized
 : @error HTTP 403 Forbidden - logged in as a user who does not have write access to the document
 : @error HTTP 404 Not found 
 :)
declare 
  %rest:DELETE
  %rest:path("/api/data/styles/{$name}")
  function sty:delete(
    $name as xs:string
  ) as item()+ {
  crest:delete($sty:data-type, $name)
};

(:~ Post a new style document 
 : @param $body The style document
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
  %rest:path("/api/data/styles")
  %rest:consumes("application/xml", "application/tei+xml", "text/xml")
  function sty:post(
    $body as document-node()
  ) as item()+ {
  crest:post(
    concat($sty:data-type, "/", ($body/tei:TEI/@xml:lang/string(), "none")[1]),
    $sty:path-base,
    api:uri-of($sty:api-path-base),
    $body,
    sty:validate#2,
    sty:validate-report#2,
    ()
  )
};

(:~ Edit/replace a style document in the database
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
  %rest:path("/api/data/styles/{$name}")
  %rest:consumes("application/xml", "text/xml")
  function sty:put-xml(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  crest:put(
    $sty:data-type, $name, $body,
    sty:validate#2,
    sty:validate-report#2
  )
};

declare
  %private
  function sty:replace-stylesheet(
    $nodes as node()*,
    $replacement as item(),
    $scheme as xs:string
    ) as node()* {
  for $n in $nodes
  return
    typeswitch($n)
    case document-node() 
    return
      document { sty:replace-stylesheet($n/node(), $replacement, $scheme) }
    case element(j:stylesheet)
    return
      <j:stylesheet scheme="{$scheme}">{
        $replacement
      }</j:stylesheet>
    case element()
    return 
      element {QName(namespace-uri($n), name($n))}{
        $n/@*,
        sty:replace-stylesheet($n/node(), $replacement, $scheme)
      }
    default
    return $n
};

(:~ Edit/replace the CSS in a style document in the database
 : All other metadata stays the same
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
 :)
declare
  %rest:PUT("{$body}")
  %rest:path("/api/data/styles/{$name}")
  %rest:consumes("text/css")
  function sty:put-css(
    $name as xs:string,
    $body as xs:string
  ) as item()+ {
  let $adj-name := replace($name, "\.css$", "")
  let $old-xml := sty:get-xml($adj-name)
  return
    if ($old-xml instance of document-node())
    then
      crest:put(
        $sty:data-type, $adj-name, 
        sty:replace-stylesheet($old-xml, $body, "css"),
        sty:validate#2,
        sty:validate-report#2
      )
    else $old-xml
};

(:~ Get access/sharing data for a style document
 : @param $name Name of document
 : @param $user User to get access as
 : @return HTTP 200 and an access structure (a:access) or user access (a:user-access)
 : @error HTTP 400 User does not exist
 : @error HTTP 404 Document not found or inaccessible
 :)
declare 
  %rest:GET
  %rest:path("/api/data/styles/{$name}/access")
  %rest:query-param("user", "{$user}")
  %rest:produces("application/xml")
  function sty:get-access(
    $name as xs:string,
    $user as xs:string*
  ) as item()+ {
  crest:get-access($sty:data-type, $name, $user)
};


(:~ Set access/sharing data for a style document
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
  %rest:path("/api/data/styles/{$name}/access")
  %rest:consumes("application/xml", "text/xml")
  function sty:put-access(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  crest:put-access($sty:data-type, $name, $body)
};
