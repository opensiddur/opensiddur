xquery version "3.0";
(: Copyright 2016 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(:~ Outlines data API
 : @author Efraim Feinstein
 :)

module namespace outl = 'http://jewishliturgy.org/api/data/outlines';

declare namespace ol="http://jewishliturgy.org/ns/outline/1.0";
declare namespace olx="http://jewishliturgy.org/ns/outline/responses/1.0";
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
import module namespace src="http://jewishliturgy.org/api/data/sources"
  at "sources.xqm";

declare variable $outl:data-type := "outlines";
declare variable $outl:schema := concat($paths:schema-base, "/outline.rnc");
declare variable $outl:schematron := ();
declare variable $outl:path-base := concat($data:path-base, "/", $outl:data-type);
declare variable $outl:api-path-base := concat("/api/data/", $outl:data-type);  

(:~ validate 
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @return true() if valid, false() if not
 : @see outl:validate-report
 :) 
declare function outl:validate(
  $doc as item(),
  $old-doc as document-node()?
  ) as xs:boolean {
  crest:validate(
    $doc, $old-doc, 
    xs:anyURI($outl:schema), (),
    ()
  )
};

(:~ validate, returning a validation report 
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @return true() if valid, false() if not
 : @see outl:validate
 :) 
declare function outl:validate-report(
  $doc as item(),
  $old-doc as document-node()?
  ) as element() {
  crest:validate-report(
    $doc, $old-doc, 
    xs:anyURI($outl:schema), (),
    ()
  )
};

(:~ return the outline path to a given item :)
declare function outl:get-outline-path(
  $e as element()
  ) as xs:string {
  typeswitch ($e)
  case element(ol:outline) return $e/ol:title
  default return (outl:get-outline-path($e/parent::*) || "->" || $e/ol:title)
};

(:~ find the API paths for the given title :)
declare function outl:title-search(
    $title as xs:string
) as xs:string* {
    for $doc in collection($orig:path-base)//tei:titleStmt/tei:title[ft:query(., $title)]/root(.) | ()
    return data:db-path-to-api(document-uri($doc))
};

(: get the status of a document, given the item element :)
declare function outl:get-status(
    $e as element(ol:item)
    ) as xs:string? {
    let $source := root($e)/ol:outline/ol:source
    return data:doc($e/olx:sameAs[olx:yes]/olx:uri)//tei:sourceDesc/tei:bibl[tei:ptr[@type="bibl"]/@target=$source]/@j:docStatus/string()
};

(:~ check an outline for duplicate titles.
 : @return olx:sameAs when necessary
 :)
declare function outl:check(
  $nodes as node()*
) as node()* {
  for $node in $nodes
  return
    typeswitch($node)
    case document-node() return outl:check($node/*)
    case element(ol:outline) return
      (: The outline element cannot be a duplicate. If it has a Uri element,
       : the URI is itself.
       :)
        element ol:outline {
            $node/@*,
            outl:check($node/node())
        }
    case element(ol:item) return
        element ol:item {
            $node/@*,
            let $duplicate-titles := outl:title-search($node/ol:title)
            let $status := outl:get-status($node)
            return (
                $node/(ol:title, ol:lang, ol:resp, ol:pages, olx:sameAs),
                for $internal-duplicate-title-item in root($node)//ol:item[ol:title=$node/ol:title][not(. is $node)]
                where (exists($internal-duplicate-title-item/ol:item))
                return 
                    element olx:error {
                        concat("Duplication of a title is only allowed for items with no descendants. This item conflicts with: ", outl:get-outline-path($internal-duplicate-title-item))
                    },
                for $duplicate-title in $duplicate-titles
                where (empty($node/olx:sameAs[olx:yes]))
                return
                    (: only add new duplicates if a uri isn't already confirmed :)
                    element olx:sameAs {
                        element olx:uri { $duplicate-title } 
                    },
                if (exists($status))
                then 
                    element olx:status { $status }
                else (),
                outl:check($node/ol:item)
            )
        }
    default return $node
};

(:~ return whether a document is executable (if empty)
 : otherwise, return messages indicating why not
 : assumes document is checked
 :)
declare function outl:is-executable(
  $doc as document-node()
  ) as element(message)* {
    let $chk := $doc 
    return (
        for $item in $chk//ol:item
        where exists($item/olx:sameAs[not(olx:yes|olx:no)]) and empty($item/olx:sameAs[olx:yes])
        return
            <message>The item has a title that duplicates existing documents, and no confirmation of whether those documents are identical to the one in the outline: {outl:get-outline-path($item)}</message>,
        for $error in $chk//olx:error 
        return <message>{$error/node()}</message>
    )
};

(:~ get a template document specified by the ol:item or ol:ouline
 : Note: the document may have pointers to unknown uris temporarily stored in tei:seg with n="outline:filler"
 : @param $e The item or outline element
 : @param $old-doc If this is an edit to a pre-existing document, the pre-existing doc
 : @return the document content
 :)
declare function outl:template(
  $e as element(),
  $old-doc as document-node()?
  ) as xs:anyURI {
  let $sub-items := $e/ol:item
  let $outline := root($e)/ol:outline
  let $lang := ($outline/ol:lang, $e/ol:lang)[1]/string()
  return
    <tei:TEI xml:lang="{ $lang }">
      <tei:teiHeader>
        <tei:fileDesc>
          <tei:titleStmt>
            <tei:title type="main" xml:lang="{ $lang }">{$e/ol:title/string()}</tei:title>
          </tei:titleStmt>
          <tei:publicationStmt>
            <tei:distributor>
              <tei:ref target="http://opensiddur.org">Open Siddur Project</tei:ref>
            </tei:distributor>
            <tei:availability>
              <tei:licence target="{ ($old-doc//tei:availability/tei:licence/string(), $outline/ol:license)[1]/string() }"/>
            </tei:availability>
            <tei:date>{ format-date(current-date(), '[Y0001]-[M01]-[D01]') }</tei:date>
          </tei:publicationStmt>
          <tei:sourceDesc>
            { $old-doc//tei:sourceDesc/tei:bibl[not(tei:ptr[@type="bibl"][@target=$outline/ol:source])] }
            <tei:bibl j:docStatus="outlined">
              <tei:title>{ src:title-function(data:doc($outline/ol:source)) }</tei:title>
              <tei:ptr type="bibl" target="{ $outline/ol:source/string() } "/>
              <tei:ptr type="bibl-content" target="#stream"/>
              { 
                if ($e/ol:from and $e/ol:to )
                then
                  <tei:biblScope unit="pages" from="{$e/ol:from/string()}" to="{$e/ol:to/string()}"/>
                else ()
              }
            </tei:bibl>
          </tei:sourceDesc>
        </tei:fileDesc>
        <tei:revisionDesc>
          <tei:change type="{if (exists($old-doc)) then 'edited' else 'created'}" who="/user/{app:auth-user()}" when="{current-dateTime()}">{if (exists($old-doc)) then 'Edited' else 'Created'} by the outline tool.</tei:change>
          { $old-doc//tei:revisionDesc/tei:change }
        </tei:revisionDesc>
      </tei:teiHeader>
      <tei:text>
        <j:streamText xml:id="stream">{
          if (exists($sub-items))
          then
            for $sub-item at $n in $sub-items
            let $sub-item-uri :=
                $sub-item/olx:sameAs[olx:yes]/olx:uri/string()
            return
                if ($sub-item-uri)
                then
                    <tei:ptr xml:id="ptr_{$n}" target="{$sub-item-uri}" />
                else
                    <tei:seg xml:id="seg_{$n}" n="outline:filler">{outl:get-outline-path($sub-item)}</tei:seg>
          else (
            <tei:seg xml:id="seg_filler">FILL ME IN</tei:seg>,
            <tei:seg xml:id="seg_title">{$e/ol:title/string()}</tei:seg>
          )
        }</j:streamText>
      </tei:text>
    </tei:TEI>

};

declare function outl:rewrite-outline(
    $nodes as node()*,
    $filler-map as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case document-node() return document { outl:rewrite-outline($node/node(), $filler-map) }
        case element(ol:outline) return 
            element ol:outline {
                $node/(ol:source | ol:license | ol:title | ol:lang | ol:resp | ol:pages),
                element olx:uri { $filler-map(outl:get-outline-path($node)) },
                outl:rewrite-outline($node/ol:item, $filler-map) 
            }
        case element(ol:item) return
            element ol:item {
                $node/(ol:title | ol:lang | ol:resp | ol:pages | olx:sameAs),
                element olx:sameAs {
                    element olx:uri { $filler-map(outl:get-outline-path($node)) },
                    element olx:yes { () }
                },
                $node/(olx:error | olx:status),
                outl:rewrite-outline($node/ol:item, $filler-map)
            }
        default return $node
};

(:~ execute an outline :)
declare function outl:execute(
  $doc as document-node()
  ) {
  let $paths-to-uris :=
    map:new(
        for $item in ($doc//ol:item, $doc/ol:outline)
        group by
            $title := $item/ol:title/string(),
            $forced-uri := ($item/olx:sameAs[olx:yes]/olx:uri, $item/olx:uri)/string()
        return 
            let $old-doc := if ($forced-uri) then data:doc($forced-uri) else ()
            let $template := outl:template($item, $forced-uri) 
            let $result :=
                if ($forced-uri)
                then 
                    orig:put(tokenize($forced-uri, '/')[last()], $template)
                else
                    orig:post($template)
            let $location := $result/self::rest:response/http:response/http:header[@name="Location"]/@value/string()
            for $it in $item
            return
                (: a mapping between outline paths and http location :)
                map:entry(outl:get-outline-path($it), replace($location, '^(.*/api/)', '/'))
    )
  let $rewrite-filler :=
      for $outline-path in map:keys($paths-to-uris)
      let $uri := $paths-to-uris($outline-path)
      return
          orig:put(tokenize($uri, '/')[last()], outl:rewrite-filler(data:doc($uri), $paths-to-uris))
  let $rewritten-outline := outl:rewrite-outline($doc, $paths-to-uris)
  let $outline-doc-name := replace(tokenize(document-uri($doc), '/')[last()], '\.xml$', '')
  let $save := outl:put($outline-doc-name, $rewritten-outline)
  return $rewritten-outline
};

declare function outl:rewrite-filler(
    $nodes as node()*,
    $filler-map as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case document-node() return document { outl:rewrite-filler($node/node(), $filler-map) }
        case element() return
            if ($node/self::tei:seg and $node/@n="outline:filler")
            then
                <tei:ptr target="{$filler-map($node/string())}"/>
            else 
                element { QName(namespace-uri($node), name($node)) }{
                    $node/@*,
                    outl:rewrite-filler($node/node(), $filler-map)
                }
        default return $node
};

(:~ Get an XML document by name
 : @param $name Document name as a string
 : @error HTTP 404 Not found (or not available)
 :)
declare
  %rest:GET
  %rest:path("/api/data/outlines/{$name}")
  %rest:query-param("check", "{$check}")
  %rest:produces("application/xml", "text/xml", "application/tei+xml")
  function outl:get(
    $name as xs:string,
    $check as xs:string*
  ) as item()+ {
  let $doc := crest:get($outl:data-type, $name)
  return
    if (exists($check) and $doc instance of document-node())
    then outl:check($doc)
    else $doc
};

(:~ List or full-text query outline data
 : @param $q text of the query, empty string for all
 : @param $start first document to list
 : @param $max-results number of documents to list 
 : @return a list of documents that match the search. If the documents match a query, return the context.
 : @error HTTP 404 Not found
 :)
declare 
  %rest:GET
  %rest:path("/api/data/outlines")
  %rest:query-param("q", "{$q}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("html5")  
  function outl:list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
  ) as item()+ {
  crest:list($q, $start, $max-results,
    "Outline data API", api:uri-of($outl:api-path-base),
    outl:query-function#1, outl:list-function#0,
    (<crest:additional text="check" relative-uri="?check=1"/>, 
     <crest:additional text="execute" relative-uri="execute"/>), 
    ()
  )
};

(: support function for queries :)
declare function outl:query-function(
  $query as xs:string
  ) as element()* {
    let $c := collection($outl:path-base)
    return $c//ol:outline[ft:query(.,$query)]|$c//ol:outline/ol:title[ft:query(.,$query)]
};

(: support function for list :) 
declare function outl:list-function(
  ) as element()* {
  for $doc in collection($outl:path-base)/ol:outline
  order by $doc/ol:outline/ol:title ascending
  return $doc
};  

(:~ Delete an outline text
 : @param $name The name of the text
 : @return HTTP 204 (No data) if successful
 : @error HTTP 400 Cannot be deleted and a reason, including existing external references
 : @error HTTP 401 Not authorized
 : @error HTTP 403 Forbidden - logged in as a user who does not have write access to the document
 : @error HTTP 404 Not found 
 :)
declare 
  %rest:DELETE
  %rest:path("/api/data/outlines/{$name}")
  function outl:delete(
    $name as xs:string
  ) as item()+ {
  crest:delete($outl:data-type, $name)
};

(:~ Post a new outline document 
 : @param $body The outline document
 : @return HTTP 201 if created successfully
 : @error HTTP 400 Invalid outline XML
 : @error HTTP 401 Not authorized
 : @error HTTP 500 Storage error
 :
 : Other effects: 
 : * The new resource is owned by the current user, group owner=current user, and mode is 664
 :)
declare
  %rest:POST("{$body}")
  %rest:path("/api/data/outlines")
  %rest:consumes("application/xml", "application/tei+xml", "text/xml")
  function outl:post(
    $body as document-node()
  ) as item()+ {
  crest:post(
    $outl:data-type,
    $outl:path-base,
    api:uri-of($outl:api-path-base),
    $body,
    outl:validate#2,
    outl:validate-report#2,
    ()
  )
};

(:~ Execute an outline document 
 : @param $body Anything...
 : @return HTTP 201 if created successfully
 : @error HTTP 400 Invalid outline XML or outline is not executable
 : @error HTTP 401 Not authorized
 : @error HTTP 500 Storage error
 :
 : Other effects: 
 : The outline file is saved with the URIs
 :)
declare
  %rest:POST("{$body}")
  %rest:path("/api/data/outlines/{$name}/execute")
  %rest:consumes("application/xml", "application/tei+xml", "text/xml")
  function outl:post-execute(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  let $document := outl:get($name, "check")
  return 
    if ($document instance of document-node())
    then 
        let $executable-errors := outl:is-executable($document)
        return
            if (exists($executable-errors))
            then api:rest-error(400, $executable-errors)
            else outl:execute($document)
    else $document
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
 :)
declare
  %rest:PUT("{$body}")
  %rest:path("/api/data/outlines/{$name}")
  %rest:consumes("application/xml", "text/xml")
  function outl:put(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  crest:put(
    $outl:data-type, $name, $body,
    outl:validate#2,
    outl:validate-report#2
  )
};

