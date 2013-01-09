xquery version "3.0";
(: Copyright 2012-2013 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(:~ Translation data API
 : @author Efraim Feinstein
 :)

module namespace xlat = 'http://jewishliturgy.org/api/data/translation';

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace o="http://a9.com/-/spec/opensearch/1.1/";

import module namespace acc="http://jewishliturgy.org/modules/access"
  at "/db/code/api/modules/access.xqm";
import module namespace api="http://jewishliturgy.org/modules/api"
  at "/db/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "/db/code/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "/db/code/api/modules/data.xqm";
import module namespace jvalidate="http://jewishliturgy.org/modules/jvalidate"
  at "/db/code/modules/jvalidate.xqm";
import module namespace orig="http://jewishliturgy.org/api/data/original"
  at "/db/code/api/data/original.xqm";
import module namespace user="http://jewishliturgy.org/api/user"
  at "/db/code/api/user.xqm";

import module namespace magic="http://jewishliturgy.org/magic"
  at "/db/code/magic/magic.xqm";
  
import module namespace kwic="http://exist-db.org/xquery/kwic";

declare variable $xlat:data-type := "translation";
declare variable $xlat:schema := "/schema/jlptei.rnc";
declare variable $xlat:schematron := "/schema/jlptei.xsl2";
declare variable $xlat:path-base := concat($data:path-base, "/", $xlat:data-type);
declare variable $xlat:introduction-document-name := "introduction.xml";


(:~ validate 
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @return true() if valid, false() if not
 : @see xlat:validate-report
 :) 
declare function xlat:validate(
  $doc as item(),
  $old-doc as document-node()?
  ) as xs:boolean {
  validation:jing($doc, xs:anyURI($xlat:schema)) and
    jvalidate:validation-boolean(
      jvalidate:validate-iso-schematron-svrl($doc, xs:anyURI($xlat:schematron))
    ) and (
      empty($old-doc) or
      jvalidate:validation-boolean(
        orig:validate-changes($doc, $old-doc)
      )
    )
};

(:~ validate, returning a validation report 
 : @param $doc The document to be validated
 : @param $old-doc The document it is replacing, if any
 : @return true() if valid, false() if not
 : @see xlat:validate
 :) 
declare function xlat:validate-report(
  $doc as item(),
  $old-doc as document-node()?
  ) as element() {
  jvalidate:concatenate-reports((
    validation:jing-report($doc, xs:anyURI($xlat:schema)),
    jvalidate:validate-iso-schematron-svrl($doc, doc($xlat:schematron)),
    if (exists($old-doc))
    then xlat:validate-changes($doc, $old-doc)
    else ()
  ))
};

(:~ determine if all the changes between an old version and
 : a new version of a document are legal
 : @param $doc new document
 : @param $old-doc old document
 : @return a report element, indicating whether the changes are valid or invalid
 :) 
declare function xlat:validate-changes(
  $doc as document-node(),
  $old-doc as document-node()
  ) as element(report) {
  orig:validate-changes($doc, $old-doc)
};

(: error message when access is not allowed :)
declare function local:no-access(
  ) as item()+ {
  if (app:auth-user())
  then api:rest-error(403, "Forbidden")
  else api:rest-error(401, "Not authenticated")
};

(: 
 : @param $path-base base path relative to $xlat:path-base
 : @return (list, start, count, n-results) :) 
declare function local:query(
    $path-base as xs:string,
    $query as xs:string,
    $start as xs:integer,
    $count as xs:integer
  ) as item()+ {
  let $all-results := 
    for $doc in
      collection(concat($xlat:path-base, "/", $path-base))//
        (tei:title|j:streamText)[ft:query(.,$query)]
    order by $doc//tei:title[@type="main"] ascending
    return $doc
  let $listed-results := 
    <ol xmlns="http://www.w3.org/1999/xhtml" class="results">{
      for $result in  
        subsequence($all-results, $start, $count)
      let $document := root($result)
      group $result as $hit by $document as $doc
      order by max(for $h in $hit return ft:score($h))
      return
        let $api-name := replace(util:document-name($doc), "\.xml$", "")
        return
        <li class="result">
          <a class="document" href="/api{$xlat:path-base}/{$api-name}">{$doc//tei:titleStmt/tei:title[@type="main"]/string()}</a>:
          <ol class="contexts">{
            for $p in 
              kwic:summarize($hit, <config xmlns="" width="40" />)
            return
              <li class="context">{
                $p/*
              }</li>
          }</ol>
        </li>
    }</ol>
  return (
    $listed-results,
    $start,
    $count, 
    count($all-results)
  )
};


(:~ get a list of available translation languages or search all translations
 : @param $query Search query or empty string for none
 : @param $start start listing results at. Ignored when $query is empty
 : @param $count maximum number of results. Ignored when $query is empty
 :)
declare 
  %rest:GET
  %rest:path("/api/data/translation")
  %rest:produces("application/xhtml+xml", "application/xml", "text/html")
  %rest:query-param("q", "{$query}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$count}", 100)
  %output:method("html5")
  function xlat:get-lang-list(
    $query as xs:string,
    $start as xs:integer,
    $count as xs:integer
  ) as item()+ {
  <rest:response>
    <output:serialization-parameters>
      <output:method value="html5"/>
    </output:serialization-parameters>
  </rest:response>,
  let $results as item()+ :=
    if ($query)
    then 
      local:query("", $query, $start, $count)
    else (
      <ul xmlns="http://www.w3.org/1999/xhtml" class="apis">
      {
      let $lang-collection := $xlat:path-base
      let $lang-collections := 
        if (xmldb:collection-available($lang-collection))
        then xmldb:get-child-collections($lang-collection)
        else ( (: no translations have been created yet:) )
      for $collection in $lang-collections
      order by lower-case($collection)
      return
        <li class="api">
          <a class="discovery" href="{$xlat:data-type}/{$collection}">{$collection}</a>
        </li>
      }
      </ul>
    )
  let $result-element := $results[1]
  let $max-results := $results[3]
  let $total := $results[4]
  return
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head profile="http://a9.com/-/spec/opensearch/1.1/">
        <title>Translation data API</title>
        <link rel="search"
           type="application/opensearchdescription+xml" 
           href="/api/data/OpenSearchDescription?source={encode-for-uri($xlat:path-base)}"
           title="Full text search" />
            
        {
          if ($query)
          then (
            <meta name="startIndex" content="{if ($total eq 0) then 0 else $start}"/>,
            <meta name="endIndex" content="{min(($start + $max-results - 1, $total))}"/>,
            <meta name="itemsPerPage" content="{$max-results}"/>,
            <meta name="totalResults" content="{$total}"/>
          )
          else ()
        }
      </head>
      <body>{
        $results
      }</body>
    </html>
};

(:~ get or search a list of available translations in a given language
 : By convention, the translation has a file called 
 :  introduction.xml that describes the translation philosophy
 : @param $lang The langauge directory to search
 : @param $query Search query or empty string for none
 : @param $start start listing results at. Ignored when $query is empty
 : @param $count maximum number of results. Ignored when $query is empty
 :)
declare 
  %rest:GET
  %rest:path("/api/data/translation/{$lang}")
  %rest:produces("application/xhtml+xml", "application/xml", "text/html")
  %rest:query-param("q", "{$query}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$count}", 100)
  %output:method("html5")
  function xlat:get-xlat-list(
    $lang as xs:string,
    $query as xs:string,
    $start as xs:integer,
    $count as xs:integer
  ) as item()+ {
  <rest:response>
    <output:serialization-parameters>
      <output:method value="html5"/>
    </output:serialization-parameters>
  </rest:response>,
  let $results as item()+ :=
    if ($query)
    then 
      local:query($lang, $query, $start, $count)
    else (
      <ul xmlns="http://www.w3.org/1999/xhtml" class="apis">
      {
      let $lang-collection := concat($xlat:path-base, "/", $lang)
      let $lang-collections := 
        if (xmldb:collection-available($lang-collection))
        then xmldb:get-child-collections($lang-collection)
        else ( (: no translations have been created yet:) )
      for $collection in $lang-collections
      let $translation-title := 
        doc(
          concat($lang-collection, "/", $collection, "/", $xlat:introduction-document-name)
        )/tei:TEI/tei:teiHeader//tei:title
          [@type="main" or not(@type)][1]
      let $title-lang := $translation-title/ancestor-or-self::*[@xml:lang][1]/@xml:lang
      let $link-text := ($translation-title/string(), $collection)[1]
      let $null := util:log-system-out(($collection, ":", $translation-title, ":", $link-text))
      order by lower-case($link-text)
      return
        <li class="api">
          <a class="discovery" href="{$lang}/{$collection}">{
            if (empty($translation-title) 
              (:or $translation-title/lang("en"):))
            then ()
            else (
              attribute xml:lang { $title-lang },
              attribute lang { $title-lang }
            ),
            $link-text
          }</a>
        </li>
      }
      </ul>
    )
  let $result-element := $results[1]
  let $max-results := $results[3]
  let $total := $results[4]
  return
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head profile="http://a9.com/-/spec/opensearch/1.1/">
        <title>Translation data API for {$lang}</title>
        <link rel="search"
           type="application/opensearchdescription+xml" 
           href="/api/data/OpenSearchDescription?source={encode-for-uri($xlat:path-base)}"
           title="Full text search" />
            
        {
          if ($query)
          then (
            <meta name="startIndex" content="{if ($total eq 0) then 0 else $start}"/>,
            <meta name="endIndex" content="{min(($start + $max-results - 1, $total))}"/>,
            <meta name="itemsPerPage" content="{$max-results}"/>,
            <meta name="totalResults" content="{$total}"/>
          )
          else ()
        }
      </head>
      <body>{
        $results
      }</body>
    </html>
};

(: TODO: 
[add /access to translation list getter]

POST /api/data/translation/{$lang}
  new translation 

GET /api/data/translation/{$lang}/{$tr}
  return introduction document

GET /api/data/translation/{$lang}/{$tr}/access
  get access restrictions on a translation

PUT /api/data/translation/{$lang}/{$tr}/access
  set access restrictions on a translation
 
PUT /api/data/translation/{$lang}/{$tr}
  edit introduction document

DELETE /api/data/translation/{$lang}/{$tr}
  delete a translation in its entirety
  
GET /api/data/translation/{$lang}/{$tr}/{$doc}
POST /api/data/translation/{$lang}/{$tr}
PUT /api/data/translation/{$lang}/{$tr}/{$doc}
DELETE /api/data/translation/{$lang}/{$tr}/{$doc}
GET /api/data/translation/{$lang}/{$tr}/{$doc}/access
PUT /api/data/translation/{$lang}/{$tr}/{$doc}/access
:)