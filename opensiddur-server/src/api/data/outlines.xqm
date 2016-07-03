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
declare namespace error="http://jewishliturgy.org/errors";

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
  default return (outl:get-outline-path($e/parent::*) || "/" || $e/ol:title || "[" || 
      string(count($e/preceding-sibling::ol:item) + 1) || "]")
};

(:~ find the API paths for the given title :)
declare function outl:title-search(
    $title as xs:string
) as xs:string* {
    let $title-plus := string-join(for $t in tokenize($title, '\s+') return "+" || $t, " ")
    for $doc in collection($orig:path-base)//tei:titleStmt/tei:title[ft:query(., $title-plus)]/root(.) | ()
    return replace(data:db-path-to-api(document-uri($doc)), "^(/exist/restxq)?/api", "")
};

(: get the status of a document, given the outline and uri.
 : If the URI does not exist, return empty :)
declare function outl:get-status(
    $outline as document-node(),
    $uri as xs:string?
    ) as xs:string? {
    let $source := $outline/ol:outline/ol:source
    where exists($uri)
    return data:doc($uri)//tei:sourceDesc/tei:bibl[tei:ptr[@type="bibl"]/@target=$source]/@j:docStatus/string()
};


(:~ given an item definition and a document, check if the referenced pointers in the
 : document pointed to be $same-as-uri are the same and in the same order as the ones in 
 : the item.
 :)
declare function outl:check-sameas-pointers(
  $e as element(ol:item),
  $same-as-uri as xs:string
  ) as element(olx:warning)? {
  let $warning := 
    <olx:warning>This outline item has subordinate items that are either not referenced in the resource or are referenced and are a different order than they are presented in the outline.</olx:warning>
  let $doc := data:doc($same-as-uri)
  (: if the document doesn't exist, it's new, so we can ignore it... :)
  where exists($doc)
  return
    let $in-document-pointers := $doc//j:streamText/tei:ptr
    let $has-warning :=
      if (count($in-document-pointers) ne count($e/ol:item))
      then 1
      else
        for $item at $n in $e/ol:item
        let $item-title := normalize-space($item/ol:title)
        let $target :=
            if (contains($in-document-pointers[$n]/@target, '#'))
            then substring-before($in-document-pointers[$n]/@target, '#')
            else $in-document-pointers[$n]/@target/string()
        let $pointer-target := if ($target) then data:doc($target) else ()
        let $pointer-title := normalize-space($pointer-target//tei:titleStmt/tei:title["main"=@type or not(@type)]/string())
        where not($pointer-title=$item-title)
        return 1
    where exists($has-warning)
    return $warning
};

(:~ @return true() if $node1 and $node2 have the same (direct) subordinates by title :)
declare function outl:has-same-subordinates(
  $node1 as element(ol:item),
  $node2 as element(ol:item)
  ) as xs:boolean {
  if (empty($node1/ol:item) and empty($node2/ol:item))
  then true()
  else if (count($node1/ol:item) != count($node2/ol:item))
  then false()
  else (
    every $value in ( 
      for $item at $n in $node1/ol:item
      return normalize-space($item/ol:title)=normalize-space($node2/ol:item[$n]/ol:title)
      ) satisfies $value
  )
};

(:~ check an outline for duplicate titles:
 : (0) For each item without a duplicate title:
 :  return the item as-is.
 : (1) For each item with a duplicate title external to this outline:
 :  (a) If there is no confirmation of it being duplicate:
 :      add an olx:sameAs entry with olx:uri for each duplicate entry
 :  (b) If there is a confirmation of it being duplicate:
 :      maintain the existing olx:sameAs entry
 :      add an olx:sameAs entry for other duplicates
 :  (c) If there are subordinate ol:item elements and olx:sameAs is present:
 :      for each sameAs element:
 :          (i) if the item does not point to the same items, issue an olx:warning with a textual message
 :          (ii) if the item does not point to the same items in the same order, issue an olx:warning with a textual message
 :  (d) If the document has a status with respect to this source and a confirmed sameAs, an olx:status element is returned
 : (2) For each item with a duplicate title internal to this outline:
 :  (a) If one is empty and the other is empty or has ol:item, do nothing
 :  (b) If both have identically titled and ordered ol:items, do nothing
 :  (c) If both have ol:item that are not identically titled or identically ordered, issue olx:error
 : @return olx:sameAs when necessary
 :)
declare function outl:check(
  $nodes as node()*
) as node()* {
  for $node in $nodes
  return
    typeswitch($node)
    case document-node() return document { outl:check($node/*) }
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
            let $status := outl:get-status(root($node), $node/olx:sameAs[olx:yes]/olx:uri/string())
            return (
                $node/(ol:title, ol:lang, ol:resp, ol:from|ol:to),
                for $internal-duplicate-title-item in root($node)//ol:item[ol:title=$node/ol:title][not(. is $node)]
                where
                  (: ignorable duplicates :)
                  not(
                    count($node/ol:item)=0 or 
                    count($internal-duplicate-title-item/ol:item)=0  or 
                    outl:has-same-subordinates($internal-duplicate-title-item, $node) )
                return 
                    element olx:error {
                        concat("Duplication of a title is only allowed for items that have exactly the same subordinates or where one of the items has no subordinates. The duplicate outline item is: ", outl:get-outline-path($internal-duplicate-title-item))
                    },
                for $duplicate-title in $duplicate-titles
                order by $duplicate-title
                return
                    element olx:sameAs {
                        element olx:uri { $duplicate-title },
                        (: copy the remaining elements (yes, no, etc) :)
                        $node/olx:sameAs[olx:uri=$duplicate-title]/(* except (olx:uri, olx:warning)),
                        (: add appropriate warnings :)
                        outl:check-sameas-pointers($node, $duplicate-title)
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

declare variable $outl:responsibilities := map {
    "ann" := "Annotated by",
    "fac" := "Scanned by",
    "fnd" := "Funded by",
    "mrk" := "Markup edited by",
    "pfr" := "Proofread by",
    "spn" := "Sponsored by",
    "trc" := "Transcribed by",
    "trl" := "Translated by"
};

(:~ get the name of a contributor by uri :)
declare function outl:contributor-lookup(
  $uri as xs:string
  ) as xs:string? {
  data:doc($uri)/j:contributor/(tei:name, tei:orgName)[1]
};

(:~ get a template document specified by the ol:item or ol:outline
 : Note: the document may have pointers to unknown uris temporarily stored in tei:seg with n="outline:filler"
 : @param $e The item(s) or outline element that represent a single title
 : @param $old-doc If this is an edit to a pre-existing document, the pre-existing doc
 : @return the document content
 :)
declare function outl:template(
  $e as element()+,
  $old-doc as document-node()?
  ) as document-node() {
  let $f := $e[1]
  let $sub-items := $e[ol:item][1]/ol:item  (: first entry that has items :)
  let $outline := root($f)/ol:outline
  let $lang := ($outline/ol:lang, $e/ol:lang)[1]/string()
  return
    document {
      <tei:TEI xml:lang="{ $lang }">
        <tei:teiHeader>
          <tei:fileDesc>
            <tei:titleStmt>
              <tei:title type="main" xml:lang="{ $lang }">{$f/ol:title/string()}</tei:title>
              {
                for $resp in $e/ol:resp
                group by 
                  $contributor := $resp/ol:contributor/string(),
                  $responsibility := $resp/ol:responsibility/string()
                return
                  <tei:respStmt>
                    <tei:resp key="{$responsibility}">{ $outl:responsibilities($responsibility) }</tei:resp>
                    <tei:name ref="{$contributor}">{ outl:contributor-lookup($contributor) }</tei:name>
                  </tei:respStmt>
              }
            </tei:titleStmt>
            <tei:publicationStmt>
              <tei:distributor>
                <tei:ref target="http://opensiddur.org">Open Siddur Project</tei:ref>
              </tei:distributor>
              <tei:availability>
                <tei:licence target="{ ($old-doc//tei:availability/tei:licence/@target, $outline/ol:license)[1]/string() }"/>
              </tei:availability>
              <tei:date>{ format-date(current-date(), '[Y0001]-[M01]-[D01]') }</tei:date>
            </tei:publicationStmt>
            <tei:sourceDesc>
              { $old-doc//tei:sourceDesc/tei:bibl[not(tei:ptr[@type="bibl"][@target=$outline/ol:source])] }
              <tei:bibl j:docStatus="outlined">
                <tei:title>{ src:title-function(data:doc($outline/ol:source)) }</tei:title>
                <tei:ptr type="bibl" target="{ $outline/ol:source/string() }"/>
                <tei:ptr type="bibl-content" target="#{($old-doc//j:streamText/@xml:id, 'stream')[1]}"/>
                { 
                  for $it in $e[ol:from][ol:to] 
                  return
                    <tei:biblScope unit="pages" from="{$it/ol:from/string()}" to="{$it/ol:to/string()}"/>
                }
              </tei:bibl>
            </tei:sourceDesc>
          </tei:fileDesc>
          <tei:revisionDesc>
            <tei:change type="{if (exists($old-doc)) then 'edited' else 'created'}">{if (exists($old-doc)) then 'Edited' else 'Created'} by the outline tool.</tei:change>
            { $old-doc//tei:revisionDesc/tei:change }
          </tei:revisionDesc>
        </tei:teiHeader>
        <tei:text>
          <j:streamText xml:id="{($old-doc//j:streamText/@xml:id, 'stream')[1]}">{
            if (exists($sub-items))
            then
              for $sub-item at $n in $sub-items
              let $sub-item-uri :=
                  $sub-item/olx:sameAs[olx:yes]/olx:uri/string()
              return
                  if ($sub-item-uri)
                  then
                        let $target := (data:doc($sub-item-uri)//j:streamText/@xml:id/string(), "stream")[1]
                        return
                            <tei:ptr xml:id="ptr_{$n}" target="{$sub-item-uri}#{$target}" />
                  else
                      <tei:seg xml:id="seg_{$n}" n="outline:filler">{outl:get-outline-path($sub-item)}</tei:seg>
            else (
              <tei:seg xml:id="seg_filler">FILL ME IN</tei:seg>,
              <tei:seg xml:id="seg_title">{$f/ol:title/string()}</tei:seg>
            )
          }</j:streamText>
        </tei:text>
      </tei:TEI>
    }
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
            let $uri := $filler-map(outl:get-outline-path($node))
            return 
              element ol:outline {
                  $node/(ol:source | ol:license | ol:title | ol:lang | ol:resp | ol:from | ol:to),
                  element olx:uri { $uri },
                  element olx:status { outl:get-status(root($node), $uri) },
                  outl:rewrite-outline($node/ol:item, $filler-map) 
              }
        case element(ol:item) return
            let $uri := $filler-map(outl:get-outline-path($node))
            return 
              element ol:item {
                  $node/(ol:title | ol:lang | ol:resp | ol:from | ol:to | olx:sameAs[not(olx:uri=$uri)]),
                  element olx:sameAs {
                      element olx:uri { $uri },
                      element olx:yes { () },
                      $node/olx:sameAs/olx:warning
                  },
                  $node/olx:error,
                  element olx:status { outl:get-status(root($node), $uri) },
                  outl:rewrite-outline($node/ol:item, $filler-map)
              }
        default return $node
};

(:~ transform an existing document by adding a source, pages or change record, if necessary :)
declare function outl:transform-existing(
  $nodes as node()*,
  $item as item()+
  ) as node()* {
  let $source := root($item[1])//ol:source/string()
  for $node in $nodes
  return
    typeswitch($node)
    case document-node() return 
      (: short circuit if we don't need to do anything :)
      if (
          every $it in $item
          satisfies exists($node//tei:sourceDesc[
            tei:bibl
              [@j:docStatus]
              [tei:ptr[@type="bibl"][$source=@target]]
              [tei:biblScope[@unit="pages"][@from le $it/ol:from][@to ge $it/ol:to]]
          ])
      ) then $node
      else document { outl:transform-existing($node/node(), $item) }
    case element(tei:sourceDesc) return
      element tei:sourceDesc {
        $node/@*,
        if (empty(
            $node/tei:bibl
              [tei:ptr[@type="bibl"][$source=@target]]))
        then
          <tei:bibl j:docStatus="outlined">
            <tei:title>{ src:title-function(data:doc($source)) }</tei:title>
            <tei:ptr type="bibl" target="{ $source }"/>
            <tei:ptr type="bibl-content" target="#{(root($node)//j:streamText/@xml:id, 'stream')[1]}"/>
            { 
              for $it in $item[ol:from][ol:to]
              return
                <tei:biblScope unit="pages" from="{$it/ol:from/string()}" to="{$it/ol:to/string()}"/>
            }
          </tei:bibl>
        else outl:transform-existing($node/node(), $item)
      }
    case element(tei:bibl) return
      if ($node/tei:ptr[@type="bibl"]/@target=$source)
      then
        element tei:bibl {
          $node/@*,
          if (not($node/@j:docStatus))
          then attribute j:docStatus { "outlined" }
          else (),
          $node/node(),
          for $it in $item[ol:from][ol:to]
          where empty($node/tei:biblScope[@unit="pages"][@from le $it/ol:from][@to ge $it/ol:to])
          return
            <tei:biblScope unit="pages" from="{$it/ol:from/string()}" to="{$it/ol:to/string()}"/>
           
        }
      else $node
    case element(tei:teiHeader) return
      element tei:teiHeader {
        $node/@*,
        outl:transform-existing($node/node(), $item),
        if (empty($node/tei:revisionDesc))
        then
          element tei:revisionDesc {
            element tei:change { attribute type { "edited" }, "Edited by the outline tool." }
          }
        else ()
          
      }
    case element(tei:revisionDesc) return
      element tei:revisionDesc {
        $node/@*,
        element tei:change { attribute type { "edited" }, "Edited by the outline tool." },
        $node/node()
      }
    case element() return
      element { QName(namespace-uri($node), name($node)) }{
        $node/@*,
        outl:transform-existing($node/node(), $item)
      }
    case text() return $node
    case comment() return $node
    default return outl:transform-existing($node/node(), $item)
};
(:~ execute an outline document, assuming it has been checked and is found to be executable, see also outl:is-executable
 : Execution pattern:
 : (1) for each title in an ol:outline or ol:item:
 :  (a) find the item that has subordinate items and execute that item; otherwise choose the first one
 :  (b) if multiple items exist with the same titles, all of their scopes must be represented
 :  (c) if the item has an olx:sameAs[olx:yes], record the title=uri connection, but do not edit the file
 :      otherwise create a file template referencing each item
 : (.) rewrite the outline with all the uris and statuses present
 :)
declare function outl:execute(
  $name as xs:string,
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
            let $template := 
              if ($old-doc)
              then outl:transform-existing($old-doc, $item)
              else outl:template($item, $old-doc)
            let $result :=
                if ($forced-uri)
                then
                    if ($old-doc is $template)
                    then ()
                    else orig:put(tokenize($forced-uri, '/')[last()], $template)
                else
                    orig:post($template)
            let $null :=
              if ($result/self::rest:response/http:response/@status >= 400)
              then error(xs:QName("error:OUTLINE"), ("While writing from template " || ($forced-uri) || " received an error:" || $result/message) )
              else ()
            let $location := ($result/self::rest:response/http:response/http:header[@name="Location"]/@value/string(), $forced-uri)[1]
            for $it in $item
            return
                (: a mapping between outline paths and http location :)
                map:entry(outl:get-outline-path($it), replace($location, '^(.*/api/)', '/'))
    )
  let $all-uris := 
    distinct-values(for $outline-path in map:keys($paths-to-uris) return $paths-to-uris($outline-path))
  let $rewrite-filler :=
      for $uri in $all-uris
      let $doc-uri := data:doc($uri)
      let $rewritten := outl:rewrite-filler($doc-uri, $paths-to-uris)
      where not($rewritten is $doc-uri)
      return
        let $put := orig:put(tokenize($uri, '/')[last()], $rewritten)
        where $put/self::rest:response/http:response/@status >= 400
        return error(xs:QName("error:OUTLINE"), ("While writing " || $uri || "received an error:" || $put/message) )
  let $rewritten-outline := outl:rewrite-outline($doc, $paths-to-uris)
  let $outline-doc-name := replace(tokenize(document-uri($doc), '/')[last()], '\.xml$', '')
  let $save := outl:put($name, $rewritten-outline)
  return $rewritten-outline
};

declare function outl:rewrite-filler(
    $nodes as node()*,
    $filler-map as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case document-node() return 
          if (exists($node//tei:seg[@n="outline:filler"])) 
          then document { outl:rewrite-filler($node/node(), $filler-map) }
          else $node
        case element(tei:revisionDesc) return
            element tei:revisionDesc {
              $node/@*,
              element tei:change { 
                attribute type { "edited" },
                text { "Rewritten by the outline tool." }
              },
              $node/tei:change
            }
        case element() return
              if ($node/self::tei:seg and $node/@n="outline:filler")
              then
                let $uri := $filler-map($node/string())
                let $streamText-id := (data:doc($uri)//j:streamText[1]/@xml:id/string(), "stream")[1] (: if the document doesn't exist, we are about to create it :)
                return
                  <tei:ptr xml:id="ptr_{count($node/preceding-sibling::*[@n='outline:filler']) + 1}" target="{$uri}#{$streamText-id}"/>
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
    outl:title-function#1
  )
};

(: support function for queries :)
declare function outl:query-function(
  $query as xs:string
  ) as element()* {
    let $c := collection($outl:path-base)
    return $c//ol:outline[ft:query(.,$query)]|$c//ol:outline/ol:title[ft:query(.,$query)]
};

declare function outl:title-function(
  $doc as document-node()
  ) as xs:string {
  $doc/ol:outline/ol:title/string()
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
    outl:title-function#1,
    false()
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
  %rest:POST
  %rest:path("/api/data/outlines/{$name}/execute")
  %rest:consumes("application/xml", "application/tei+xml", "text/xml")
  function outl:post-execute(
    $name as xs:string
  ) as item()+ {
  let $document := outl:get($name, "check")
  return 
    if ($document instance of document-node())
    then 
        let $executable-errors := outl:is-executable($document)
        return
            if (exists($executable-errors))
            then api:rest-error(400, $executable-errors)
            else outl:execute($name, $document)
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
    outl:validate-report#2,
    false()
  )
};

