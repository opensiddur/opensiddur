xquery version "3.1";
(: Copyright 2012-2013,2016-2017 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(:~ Conditional data API
 : @author Efraim Feinstein
 :)

module namespace cnd = 'http://jewishliturgy.org/api/data/conditionals';

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace r="http://jewishliturgy.org/ns/results/1.0";
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
  
declare variable $cnd:data-type := "conditionals";
declare variable $cnd:schema := concat($paths:schema-base, "/conditional.rnc");
declare variable $cnd:schematron := concat($paths:schema-base, "/conditional.xsl2");
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
      <message>Type '{$fs-declaration/@type/string()}' is already declared in {crest:tei-title-function($fs-declaration)}
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

declare function cnd:list(
  $q as xs:string*, 
  $start as xs:integer*, 
  $max-results as xs:integer*
  ) as item()+ {
  cnd:list($q, $start, $max-results, (), ())
};

declare function cnd:list(
        $q as xs:string*,
        $start as xs:integer*,
        $max-results as xs:integer*,
        $decls-only as xs:string*
) as item()+ {
  cnd:list($q, $start, $max-results, $decls-only, ())
};

(:~ List or full-text query conditionals data. 
 : Querying conditionals data will search for titles and
 : feature/feature structure descriptions
 : @param $q text of the query, empty string for all
 : @param $start first document to list
 : @param $max-results number of documents to list 
 : @param $decls-only return matching declarations only, not the whole file
 : @param $types-only return (exact) matching types only
 : @return a list of documents (or declarations, as XML) that match the search. If the documents match a query, return the context.
 : @error HTTP 404 Not found
 :)
declare 
  %rest:GET
  %rest:path("/api/data/conditionals")
  %rest:query-param("q", "{$q}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:query-param("decls-only", "{$decls-only}", "false")
  %rest:query-param("types-only", "{$types-only}", "false")
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("xhtml")
  function cnd:list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*,
    $decls-only as xs:string*,
    $types-only as xs:string*
  ) as item()+ {
  if (xs:boolean($decls-only) or xs:boolean($types-only))
  then
    cnd:list-definitions($q[1], $start[1], $max-results[1], xs:boolean($types-only))
  else
    crest:list($q, $start, $max-results,
      "Conditional declaration data API", api:uri-of($cnd:api-path-base),
      cnd:query-function#1, cnd:list-function#0,
      (), (: conditionals should not support access restrictions? :) 
      ()
    )
};

(:~ 
 : return all relevant search results
 : if searching for specific feaures, extract the features from matching feature structures :)
declare %private 
  function cnd:extract-search-results(
  $nodes as element()*
  ) as node()* {
  for $node in $nodes
  return
    typeswitch($node)
    case element(tei:title)
    return
      (: got the title of the file, return all fsDecls :)
      for $decl in root($node)//tei:fsdDecl/tei:fsDecl
      return
        element r:conditional-result {
          attribute resource { data:db-path-to-api(document-uri(root($node))) },
          attribute match { "resource" },
          $decl
        }
    case element(tei:fsDecl)
    return
      (: got a match on type :)
      element r:conditional-result {
        attribute resource { data:db-path-to-api(document-uri(root($node))) },
        attribute match { "type" },
        $node
      }
    case element(tei:fDecl)
    return
      (: got a match on name :)
      element r:conditional-result {
        attribute resource { data:db-path-to-api(document-uri(root($node))) },
        attribute match { "feature" },
        element tei:fsDecl {
          $node/parent::*/@*,
          $node/parent::*/node() except $node/parent::*/tei:fDecl[not(. is $node)]
        }
      }
    default
    return $node
};

(:~ find conditional definitions by type or name :)
declare function cnd:list-definitions(
  $query as xs:string,
  $start as xs:integer,
  $max-results as xs:integer,
  $types-only as xs:boolean?
  ) as item()+ {
  <rest:response>
    <output:serialization-parameters>
      <output:method>xml</output:method>
    </output:serialization-parameters>
  </rest:response>,
  let $c := collection($cnd:path-base)
  let $search-results :=
      if ($types-only)
      then
        $c//tei:fsDecl[lower-case($query)=lower-case(@type)]
      else
        $c//tei:title[ft:query(.,$query)]|
        $c//tei:fsDescr[ft:query(.,$query)]/parent::tei:fsDecl|
        $c//tei:fDescr[ft:query(.,$query)]/parent::tei:fDecl|
        (
          for $qpart in tokenize($query, '\s+')
          let $lqpart := lower-case($qpart)
          return
            $c//tei:fsDecl[contains(lower-case(@type), lower-case($qpart))]|
            $c//tei:fDecl[contains(lower-case(@name), lower-case($qpart))]
        )
  let $extracted as element(r:conditional-result)* :=
      cnd:extract-search-results(
        $search-results
      )
  let $n-total := count($extracted)
  let $subseq := 
      subsequence(
        for $result in $extracted
        order by $result/tei:fsDecl/@type/string() 
        return $result, $start, $max-results)
  let $n-subseq := count($subseq)
  return 
    <r:conditional-results 
      start="{$start}"
      end="{max((0, $start + $n-subseq - 1)) }"
      n-results="{$n-total}">{
      $subseq
    }</r:conditional-results>
};

(: @return (list, start, count, n-results) :) 
declare function cnd:query-function(
    $query as xs:string
  ) as element()* {
  let $c := collection($cnd:path-base)
  return $c//tei:title[ft:query(.,$query)]|
        $c//tei:fsDescr[ft:query(.,$query)]|
        $c//tei:fDescr[ft:query(.,$query)]
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

declare function cnd:post(
    $body as document-node()
  ) as item()+ {
    cnd:post($body, ())
};

(:~ Post a new conditionals document 
 : @param $body The conditionals document
 : @param $validate If present, validate the document instead of posting
 : @return HTTP 200 if validated successfully
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
  %rest:query-param("validate", "{$validate}")
  %rest:consumes("application/xml", "application/tei+xml", "text/xml")
  function cnd:post(
    $body as document-node(),
    $validate as xs:string?
  ) as item()+ {
  let $api-path-base := api:uri-of($cnd:api-path-base)
  return
    if ($validate)
    then
        crest:validation-report(
            $cnd:data-type,
            $cnd:path-base,
            $api-path-base,
            $body,
            cnd:validate#2,
            cnd:validate-report#2,
            ()
        )
    else
      crest:post(
        $cnd:data-type,
        $cnd:path-base,
        $api-path-base,
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
