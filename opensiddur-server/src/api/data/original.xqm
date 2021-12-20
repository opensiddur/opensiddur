xquery version "3.1";
(: Copyright 2012-2016 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(:~ Original data API
 : @author Efraim Feinstein
 :)

module namespace orig = 'http://jewishliturgy.org/api/data/original';

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace http="http://expath.org/ns/http-client";


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
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "../../modules/refindex.xqm";
import module namespace status="http://jewishliturgy.org/modules/status"
  at "../../modules/status.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri"
    at "../../modules/follow-uri.xqm";

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
    (
      if (exists($old-doc)) then orig:validate-changes#2 else (),
      orig:validate-external-links#2,
      orig:validate-external-anchors#2
    )
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
    (
      if (exists($old-doc)) then orig:validate-changes#2 else (),
      orig:validate-external-links#2,
      orig:validate-external-anchors#2
    )
  )
};

declare 
    %private
    function orig:validate-revisionDesc(
    $new as element(tei:revisionDesc)?,
    $old as element(tei:revisionDesc)?
    ) as xs:boolean {
    let $offset := count($new/tei:change) - count($old/tei:change) 
    return
        ($offset = (0,1) ) and (
            $offset=0 or ( (: if the first change record is new, it can;t have @when :)
                empty($new/tei:change[1]/@when)
            )
        ) and not(false()=(
        true(),     (: handle the case of the empty revisionDesc :)
        for $change at $x in $old/tei:change
        (: Putting this line directly below causes an exception, see issue #158 :)
        let $y := $x + $offset
        return xmldiff:compare($new/tei:change[$y], $change)
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

(:~ determine if:
 : 1. the anchors in a document that have type=external or canonical *and* are referenced externally are still present in the new doc
 : @param $doc the document to validate
 : @param $old-doc ignored
 : @return validation messages if the document breaks the rule, otherwise empty sequence if the document is valid
 :)
declare function orig:validate-external-anchor-presence(
    $doc as document-node(),
    $old-doc as document-node()?
) as element(message)* {
    (: this map will have one entry keyed by the xml:id with the value of the referencing document
       for each referenced external anchor that is not present in the new version of the document.
    :)
    let $missing-old-doc-externals as map(xs:string, xs:string) :=
        if (exists($old-doc))
        then map:merge(
            let $external-anchor-ids := $old-doc//tei:anchor[@type=("canonical", "external")]/@xml:id
            let $missing-new-doc-anchors :=
                for $external-anchor-id in $external-anchor-ids
                where empty($doc//tei:anchor[@type=("canonical", "external")][@xml:id=$external-anchor-id])
                return $external-anchor-id
            for $missing-anchor in $missing-new-doc-anchors
            let $missing-anchor-original := $old-doc//tei:anchor[@xml:id=$missing-anchor]
            let $references := ridx:query-all($missing-anchor-original)
            let $reference-docs :=
                for $reference in $references
                where not(root($reference) is $old-doc)
                return data:db-path-to-api(document-uri(root($reference)))
            where exists($reference-docs)
            return map:entry($missing-anchor-original/@xml:id/string(), string-join($reference-docs, ","))
            )
        else map {}
    for $missing-external-anchor in map:keys($missing-old-doc-externals)
    return element message {
        "The anchor " || $missing-external-anchor || " is referenced by " ||
        $missing-old-doc-externals($missing-external-anchor) ||
        " but is not present in the new document."
    }
};

(:~ determine if all anchors that are referenced externally in the new doc have type=external or canonical
 : @param $doc the document to validate
 : @param $old-doc ignored
 : @return a validation report
 :)
declare function orig:validate-internal-anchors(
    $doc as document-node(),
    $old-doc as document-node()?
) as element(message)* {
    for $anchor in $old-doc//tei:anchor
    let $references := ridx:query-all($anchor)
    for $reference in $references
    let $new-doc-equivalent := $doc//tei:anchor[@xml:id=$anchor/@xml:id]
    where not(root($reference) is $old-doc) and
        not($new-doc-equivalent/@type = ("canonical", "external"))
    return element message {
        "The anchor " || $new-doc-equivalent/@xml:id/string() || " is referenced externally by " ||
             data:db-path-to-api(document-uri(root($reference))) ||
            " but is not marked 'external' or 'canonical'."
    }

};

(:~ return all internal references to anchors within the given document :)
declare function orig:internal-references(
    $doc as document-node()
) as map(xs:string, element()*) {
    fold-left( (: eXist does not support map:merge with combine semantics... :)
        for $ptr-element in $doc//*[@target|@targets|@domains|@ref]
        for $reference in tokenize($ptr-element/@target|$ptr-element/@targets|$ptr-element/@domains|$ptr-element/@ref, "\s+")
        where starts-with($reference, "#")
        return
            let $after-hash := substring-after($reference, "#")
            let $target-ids :=
                if (starts-with($after-hash, "range"))
                then
                    let $left := $after-hash => substring-after("(") => substring-before(",")
                    let $right := $after-hash => substring-after(",") => substring-before(")")
                    return ($left, $right)
                else $after-hash
            let $sources := $doc//tei:anchor[@xml:id=$target-ids]
            for $source in $sources
            return map:entry($source/@xml:id/string(), $ptr-element),
        map {},
        function($items as map(xs:string, element()*), $new-item as map(xs:string, element()*)) {
                map:merge(
                for $key in (map:keys($items), map:keys($new-item))
                    return
                        if (map:contains($new-item, $key))
                        then map:entry($key, $items($key) | $new-item($key))
                        else map:entry($key, $items($key))
                )
            }
    )
};

(:~ determine if the anchors in a document follow the single-reference rule,
 : which requires that all anchors that are not canonical have only 1 pointer referencing them,
 : either internally or externally.
 : @param $doc the document to validate
 : @param $old-doc ignored
 : @return validation messages that indicate errors
 :)
declare function orig:validate-anchors-single-reference-rule(
    $doc as document-node(),
    $old-doc as document-node()?
) as element(message)* {
    let $all-internal-references as map(xs:string, element()*) := orig:internal-references($doc)
    let $relevant-anchors := $doc//tei:anchor[not(@type="canonical")]
    for $anchor in $relevant-anchors
    let $id := $anchor/@xml:id/string()
    let $old-doc-equivalent := $old-doc//tei:anchor[@xml:id=$id]
    let $external-references := ridx:query-all($old-doc-equivalent)[not(root(.) is $old-doc)]
    let $internal-references := $all-internal-references($id)
    let $all-references := ($external-references, $internal-references)
    let $count := count($all-references)
    where $count > 1
    return element message {
        "The anchor '" || $id || "' is referenced " || string($count) || " times, but may only be referenced once"
    }
};

(:~ determine if:
 : 1. the anchors in a document that have type=external or canonical *and* are referenced externally are still present in the new doc
 : 2. all anchors that are referenced externally in the new doc have type=external or canonical
 : 3. each anchor that has type=external or internal is referenced once
 : @param $doc the document to validate
 : @param $old-doc ignored
 : @return a validation report
 :)
declare function orig:validate-external-anchors(
    $doc as document-node(),
    $old-doc as document-node()?
) as element(report) {
    let $all-messages := (
        orig:validate-external-anchor-presence($doc, $old-doc),
        orig:validate-internal-anchors($doc, $old-doc),
        orig:validate-anchors-single-reference-rule($doc, $old-doc)
    )
    let $status :=
        if (exists($all-messages))
        then "invalid"
        else "valid"
    return
        element report {
            element status { $status },
            $all-messages
        }
};

(:~ determine if the external links in a document all point to something
 : @param $doc the document to validate
 : @param $old-doc ignored
 : @return a validation report
 :)
declare function orig:validate-external-links(
  $doc as document-node(),
  $old-doc as document-node()?
  ) as element(report) {
  let $bad-ptrs :=
    for $ptr in $doc//*[@target|@targets|@domains|@ref]/(@target|@targets|@domains|@ref)
    let $doc := root($ptr)
    for $target in tokenize($ptr, '\s+')
        [not(starts-with(., 'http:'))]
        [not(starts-with(., 'https:'))]
    let $base := 
        if (contains($target, '#'))
        then substring-before($target, '#')[.]
        else $target
    where exists($base)
    return
      let $fragment := substring-after($target, '#')[.]
      let $dest-doc := data:doc($base)
      let $dest-fragment := uri:follow-uri($target, $ptr/.., uri:follow-steps($ptr/..))
      where empty($dest-doc) or ($fragment and empty($dest-fragment))
      return
        <message>The pointer {$target} is invalid: {
          if (empty($dest-doc))
          then ("The document " || $base || " does not exist")
          else ("The fragment "|| $fragment || " does not exist in the document " || $base)
        }.</message>
  return
    element report {
      element status {
        if (exists($bad-ptrs)) then "invalid" else "valid"
      },
      $bad-ptrs
    }
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
    where (not($can-change-license) and not($doc//tei:availability/tei:licence/@target=$old-doc//tei:availability/tei:licence/@target))
    return
        <message>Only the original author can change a text's license</message>
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
  %output:method("xhtml")
  function orig:list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
  ) as item()+ {
  crest:list($q, $start, $max-results,
    "Original data API", api:uri-of($orig:api-path-base),
    orig:query-function#1, orig:list-function#0,
    (<crest:additional text="access" relative-uri="access"/>,
     <crest:additional text="linkage" relative-uri="linkage"/>,
     <crest:additional text="flat" relative-uri="flat"/>,
     <crest:additional text="combined" relative-uri="combined"/>,
     <crest:additional text="transcluded" relative-uri="combined?transclude=true"/>,
     $crest:additional-validate),
    ()
  )
};

(: support function for queries :)
declare function orig:query-function(
  $query as xs:string
  ) as element()* {
    let $c := collection($orig:path-base)
    return $c//tei:text[ft:query(.,$query)]|$c//tei:title[ft:query(.,$query)]
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

declare function orig:post(
    $doc as document-node()
) as item()+ {
    orig:post($doc, ())
};

(:~ Post a new original document 
 : @param $body The JLPTEI document
 : @param $validate If present, validate the POST-ed document, but do not actually post it
 :
 : @return HTTP 200 if validated
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
  %rest:query-param("validate", "{$validate}")
  %rest:consumes("application/xml", "application/tei+xml", "text/xml")
  function orig:post(
    $body as document-node(),
    $validate as xs:string*
  ) as item()+ {
  let $data-path := concat($orig:data-type, "/", $body/tei:TEI/@xml:lang)
  let $api-path-base := api:uri-of($orig:api-path-base)
  return
      crest:post(
        $data-path,
        $orig:path-base,
        $api-path-base,
        $body,
        orig:validate#2,
        orig:validate-report#2,
        (),
        (),
        $validate[1]
      )
};

declare function orig:put(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  orig:put($name, $body, ())
  };

(:~ Edit/replace a document in the database
 : @param $name Name of the document to replace
 : @param $body New document
 : @param $validate Validate without writing to the database
 : @return HTTP 200 If successfully validated
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
  %rest:query-param("validate", "{$validate}")
  %rest:consumes("application/xml", "text/xml")
  function orig:put(
    $name as xs:string,
    $body as document-node(),
    $validate as xs:string*
  ) as item()+ {
  crest:put(
    $orig:data-type, $name, $body,
    orig:validate#2,
    orig:validate-report#2,
    (),
    $validate[1]
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

(:~ find all linkage documents linked to the given document, conditioned on the query string $q
 : @return j:parallelText elements that map to the linkage
 :)
declare function orig:linkage-query-function(
  $doc as document-node(),
  $q as xs:string?
) as element()* {
  let $collection := collection("/db/data/linkage")
  let $queried :=
    if ($q)
    then $collection//j:parallelText[contains(tei:idno, $q)]
    else $collection//j:parallelText
  return
    ridx:query(
      $queried/tei:linkGrp[@domains],
      $doc//j:streamText)/parent::*
};

(:~ linkage results are given as j:parallelText elements.
 : The title is the translation id
 :)
declare function orig:linkage-title-function(
  $e as element(j:parallelText)
  ) as xs:string {
  $e/tei:idno/string()
};

(:~ Get a list of ids that are linked to this document
 : @param $name The resource to get the linkage list
 : @return HTTP 200 A list of linked resources
 : @error HTTP 404 Not found (or not available)
 :)
declare
  %rest:GET
  %rest:path("/api/data/original/{$name}/linkage")
  %rest:query-param("q", "{$q}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("xhtml")
  function orig:get-linkage(
    $name as xs:string,
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
  ) as item()+ {
  let $doc := crest:get($orig:data-type, $name)
  return
    if ($doc instance of document-node())
    then
      let $query-function := orig:linkage-query-function($doc, ?)
      let $list-function := function() as element()* { orig:linkage-query-function($doc, ()) }
      return
        crest:list($q, $start, $max-results,
          "Linkage to " || $name,
          api:uri-of("/api/data/linkage"),
          $query-function, $list-function,
          (),
           orig:linkage-title-function#1
        )
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
        format:compile($doc, map {}, $doc)
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
  %output:method("xhtml")
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

(:~ Background compile an original data resource with combined hierarchies in HTML.
 : @param $name The resource to background compile
 : @param $format output format: may be 'xml' or 'html' (default).
 : @param $transclude if true(), transclude all pointers, otherwise (default), return the pointers only.
 : @return HTTP 202 A Location header pointing to the job status API
 : @error HTTP 400 Bad output format
 : @error HTTP 404 Not found (or not available)
 :)
declare 
  %rest:POST
  %rest:path("/api/data/original/{$name}/combined")
  %rest:query-param("transclude", "{$transclude}")
  %rest:query-param("format", "{$format}")
  %rest:produces("text/plain")
  %output:method("xml")
  %output:indent("yes")
  function orig:post-combined-job(
    $name as xs:string,
    $transclude as xs:boolean*,
    $format as xs:string*
  ) as item()+ {
  let $doc := crest:get($orig:data-type, $name)
  let $format := 
    if (exists($format))
    then $format[1]
    else 'html'
  return
    if (not($format=('html','xml')))
    then api:rest-error(400, "Bad format. Must be one of 'xml' or 'html'", $format) 
    else if ($doc instance of document-node())
    then
      let $doc-path := "doc('" || document-uri($doc) || "')"
      let $transclude-string := string(($transclude, false())[1]) || "()"
      let $job-id := status:start-job($doc)
      let $params-string := "map { 'format:status-job-id' := '" || $job-id || "' }"
      let $preamble := "xquery version '3.0';
            import module namespace format='http://jewishliturgy.org/modules/format' at '/db/apps/opensiddur-server/modules/format.xqm';
    let $b :=
" 
      let $postamble := "
return util:log-system-out(('compiled ', document-uri($b)))"
      let $async := 
        if ($format = 'html')
        then (:util:eval-async("format:html($doc, map {}, $doc, ($transclude, false())[1])"):)
            status:submit($preamble ||
            "format:html(" || $doc-path || ", " || $params-string || ", " || $doc-path || ", " || $transclude-string || ")" || $postamble)
        else 
            if ($transclude[1])
            then status:submit($preamble || 
                "format:compile(" || $doc-path || ", " || $params-string || ", " || $doc-path || ")" || 
                $postamble)
            else status:submit($preamble ||
                "format:unflatten(" || $doc-path || ", " || $params-string || ", " || $doc-path || ")" || 
                $postamble)
(:
          util:eval-async("
            if ($transclude[1])
            then
              format:compile($doc, map {}, $doc)
            else
              format:unflatten($doc, map {}, $doc)
            ")
:)
      return 
        <rest:response>
            <output:serialization-parameters>
                <output:method>text</output:method>
            </output:serialization-parameters>
            <http:response status="202">
                <http:header name="Location" value="{api:uri-of('/api/jobs')}/{$job-id}"/>
            </http:response> 
        </rest:response>
    else $doc
};


(:~ for debugging only :)
declare 
  %rest:GET
  %rest:path("/api/data/original/{$name}/html")
  %rest:query-param("transclude", "{$transclude}")
  %rest:produces("application/xhtml+xml", "text/html")
  %output:method("xhtml")
  %output:indent("yes")
  function orig:get-combined-html-forced(
    $name as xs:string,
    $transclude as xs:boolean*
  ) as item()+ {
  orig:get-combined-html($name, $transclude)
};