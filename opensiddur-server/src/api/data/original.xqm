xquery version "3.0";
(: Copyright 2012-2014 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(:~ Original data API
 : @author Efraim Feinstein
 :)

module namespace orig = 'http://jewishliturgy.org/api/data/original';

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace api="http://jewishliturgy.org/modules/api"
  at "../../modules/api.xqm";
import module namespace acc="http://jewishliturgy.org/modules/access"
  at "../../modules/access.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "../../modules/app.xqm";
import module namespace crest="http://jewishliturgy.org/modules/common-rest"
  at "../../modules/common-rest.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "../../modules/data.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "../../modules/format.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "../../modules/paths.xqm";

declare variable $orig:data-type := "original";
declare variable $orig:schema := concat($paths:schema-base, "/jlptei.rnc");
declare variable $orig:schematron := concat($paths:schema-base, "/jlptei.xsl2");
declare variable $orig:path-base := concat($data:path-base, "/", $orig:data-type);
declare variable $orig:api-path-base := concat("/api/data/", $orig:data-type);  

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
  crest:validate(
    $doc, $old-doc, 
    xs:anyURI($orig:schema), xs:anyURI($orig:schematron),
    if (exists($old-doc)) then orig:validate-changes#2 else ()
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
  crest:validate-report(
    $doc, $old-doc, 
    xs:anyURI($orig:schema), xs:anyURI($orig:schematron),
    if (exists($old-doc)) then orig:validate-changes#2 else ()
  )
};

declare 
    %private
    function orig:validate-revisionDesc(
    $new as element(tei:revisionDesc),
    $old as element(tei:revisionDesc)
    ) as xs:boolean {
    let $offset := count($new/tei:change) - count($old/tei:change) 
    return
        ($offset = (0,1) ) and not(false()=( 
        for $change at $x in $old/tei:change
        return xmldiff:compare($new/tei:change[$x + $offset], $change)
        ))
};

(:~ remove ignorable text nodes :)
declare function orig:remove-whitespace(
    $nodes as node()*
    ) as node()* {
    for $node in $nodes
    return
        typeswitch ($node)
        case document-node() return
            document { orig:remove-whitespace($node/node()) }
        case comment() return ()
        case text() return
            if (normalize-space($node)='')
            then ()
            else $node
        case element() return
            element { QName(namespace-uri($node), name($node)) }{
                $node/@*,
                orig:remove-whitespace($node/node())
            }
        default return orig:remove-whitespace($node/node())
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
  (: TODO: check for missing externally referenced xml:id's :)
  let $messages := ( 
    if (not(orig:validate-revisionDesc($doc//tei:revisionDesc, $old-doc//tei:revisionDesc)))
    then <message>You may not alter the existing revision history. You may add one change log entry.</message>
    else (),
    let $can-change-license := 
      acc:can-relicense($doc, app:auth-user())
    return
      if (not(xmldiff:compare(
        <x>{
          orig:remove-whitespace(
            $doc//tei:publicationStmt/
            (* except (
              if ($can-change-license) 
              then () 
              else tei:licence
            ))
          )
        }</x>, 
        <x>{
          orig:remove-whitespace(
            $old-doc//tei:publicationStmt/
            (* except (
              if ($can-change-license) 
              then () 
              else tei:licence
            ))
          )
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
  crest:get($orig:data-type, $name)
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
  %rest:path("/api/data/original")
  %rest:query-param("q", "{$q}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("html5")  
  function orig:list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
  ) as item()+ {
  crest:list($q, $start, $max-results,
    "Original data API", api:uri-of($orig:api-path-base),
    orig:query-function#1, orig:list-function#0,
    (<crest:additional text="access" relative-uri="access"/>,
     <crest:additional text="flat" relative-uri="flat"/>,
     <crest:additional text="combined" relative-uri="combined"/>,
     <crest:additional text="transcluded" relative-uri="combined?transclude=true"/>), 
    ()
  )
};

(: support function for queries :)
declare function orig:query-function(
  $query as xs:string
  ) as element()* {
  for $doc in
      collection($orig:path-base)//(tei:title|tei:front|tei:back|j:streamText)[ft:query(.,$query)]
  order by $doc//tei:title[@type="main"] ascending
  return $doc
};

(: support function for list :) 
declare function orig:list-function(
  ) as element()* {
  for $doc in collection($orig:path-base)/tei:TEI
  order by $doc//tei:title[@type="main"] ascending
  return $doc  
};  

(:~ Delete an original text
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
  crest:delete($orig:data-type, $name)
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
  crest:post(
    concat($orig:data-type, "/", $body/tei:TEI/@xml:lang),
    $orig:path-base,
    api:uri-of($orig:api-path-base),
    $body,
    orig:validate#2,
    orig:validate-report#2,
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
  %rest:path("/api/data/original/{$name}")
  %rest:consumes("application/xml", "text/xml")
  function orig:put(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  crest:put(
    $orig:data-type, $name, $body,
    orig:validate#2,
    orig:validate-report#2
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
  %rest:path("/api/data/original/{$name}/access")
  %rest:query-param("user", "{$user}")
  %rest:produces("application/xml")
  function orig:get-access(
    $name as xs:string,
    $user as xs:string*
  ) as item()+ {
  crest:get-access($orig:data-type, $name, $user)
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
  crest:put-access($orig:data-type, $name, $body)
};

(:~ Get a flattened version of the original data resource
 : @param $name The resource to get
 : @return HTTP 200 A TEI header with a flattened version of the resource as XML
 : @error HTTP 404 Not found (or not available)
 :)
declare 
  %rest:GET
  %rest:path("/api/data/original/{$name}/flat")
  %rest:produces("application/xml", "text/xml")
  function orig:get-flat(
    $name as xs:string
  ) as item()+ {
  let $doc := crest:get($orig:data-type, $name)
  return
    if ($doc instance of document-node())
    then format:display-flat($doc, map {}, $doc)
    else $doc
};

(:~ Save a flattened version of the original data resource.
 : The resource must already exist.
 : @param $name The resource to get
 : @return HTTP 204 Success
 : @error HTTP 400 Flat XML cannot be reversed; Invalid XML; Attempt to edit a read-only part of the document
 : @error HTTP 401 Unauthorized - not logged in
 : @error HTTP 403 Forbidden - the document can be found, but is not writable by you
 : @error HTTP 404 Not found
 : @error HTTP 500 Storage error
 :)
declare 
  %rest:PUT("{$body}")
  %rest:path("/api/data/original/{$name}/flat")
  %rest:consumes("application/xml", "text/xml")
  function orig:put-flat(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  let $doc := orig:get($name)
  return
    if ($doc instance of document-node())
    then
      let $reversed := format:reverse($body, map {})
      return
        orig:put($name, $reversed)
    else
      (: error in get (eg, 404) :)
      $doc
};


(:~ Get a version of the original data resource with combined hierarchies
 : @param $name The resource to get
 : @param $transclude If true(), transclude all pointers, otherwise (default), return the pointers only.
 : @return HTTP 200 A TEI header with a combined hierarchy version of the resource as XML
 : @error HTTP 404 Not found (or not available)
 :)
declare 
  %rest:GET
  %rest:path("/api/data/original/{$name}/combined")
  %rest:query-param("transclude", "{$transclude}")
  %rest:produces("application/xml", "text/xml")
  %output:method("xml")
  function orig:get-combined(
    $name as xs:string,
    $transclude as xs:boolean*
  ) as item()+ {
  let $doc := crest:get($orig:data-type, $name)
  return
    if ($doc instance of document-node())
    then
      if ($transclude[1])
      then
        format:combine($doc, map {}, $doc)
      else
        format:unflatten($doc, map {}, $doc)
    else $doc
};

(:~ Get a version of the original data resource with combined hierarchies in HTML
 : @param $name The resource to get
 : @param $transclude If true(), transclude all pointers, otherwise (default), return the pointers only.
 : @return HTTP 200 An HTML file
 : @error HTTP 404 Not found (or not available)
 :)
declare 
  %rest:GET
  %rest:path("/api/data/original/{$name}/combined")
  %rest:query-param("transclude", "{$transclude}")
  %rest:produces("application/xhtml+xml", "text/html")
  %output:method("html5")
  %output:indent("yes")
  function orig:get-combined-html(
    $name as xs:string,
    $transclude as xs:boolean*
  ) as item()+ {
  let $doc := crest:get($orig:data-type, $name)
  return
    if ($doc instance of document-node())
    then
      format:html($doc, map {}, $doc, ($transclude, false())[1])
    else $doc
};

(:~ for debugging only :)
declare 
  %rest:GET
  %rest:path("/api/data/original/{$name}/html")
  %rest:query-param("transclude", "{$transclude}")
  %rest:produces("application/xhtml+xml", "text/html")
  %output:method("html5")
  %output:indent("yes")
  function orig:get-combined-html-forced(
    $name as xs:string,
    $transclude as xs:boolean*
  ) as item()+ {
  orig:get-combined-html($name, $transclude)
};
