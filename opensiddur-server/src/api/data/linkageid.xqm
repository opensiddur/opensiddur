xquery version "3.1";
(: Copyright 2021 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(:~ Linkage ID data API
 :
 : A linkage ID is not a document type. Linkage ids exist as tei:idno inside linkage documents.
 : This API allows:
 : * Listing linkage ids as if they were a primary resource
 : * Finding resources that are linked with a given linkage id
 : * Finding linkage ids that link a given resource
 :
 : @author Efraim Feinstein
 :)

module namespace lnkid = 'http://jewishliturgy.org/api/data/linkageid';

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace api="http://jewishliturgy.org/modules/api"
  at "../../modules/api.xqm";
import module namespace crest="http://jewishliturgy.org/modules/common-rest"
  at "../../modules/common-rest.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "../../modules/data.xqm";
import module namespace lnk="http://jewishliturgy.org/api/data/linkage"
  at "linkage.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "../../modules/follow-uri.xqm";

declare variable $lnkid:api-path-base := "/api/data/linkageid";

(:~ query for ids that match :)
declare function lnkid:query-function(
    $query as xs:string
) {
    (: this should use a range index, I think :)
    for $result in collection($lnk:path-base)//tei:idno[contains(., $query)]
    order by $result/string()
    return $result
};

(:~ list all linkage ids :)
declare function lnkid:list-function() as element()* {
  for $id in distinct-values(collection($lnk:path-base)//j:parallelText/tei:idno/normalize-space(.))
  order by $id ascending
  return element tei:idno { $id }
};

(:~ title of a linkage id from an id node :)
declare function lnkid:title-function(
    $idno as node()
) as xs:string {
    $idno/string()
};

declare
  %rest:GET
  %rest:path("/api/data/linkageid")
  %rest:query-param("q", "{$q}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("xhtml")
  function lnkid:list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
  ) as item()+ {
  crest:list($q, $start, $max-results,
    "Linkage ID data API", api:uri-of($lnkid:api-path-base),
    lnkid:query-function#1, lnkid:list-function#0,
    (),
    lnkid:title-function#1
  )
};

(:~ (internal function) get all the original resources linked to by an id.
 : The format is:
 : <result>
 :  <linkage-doc>(document-name)</linkage-doc>
 :  <left-doc>(left side doc path)</left-doc>
 :  <right-doc>(right side doc path)</right-doc>
 : </result>
 :)
declare function lnkid:list-by-id(
    $id as xs:string
) as element(lnkid:result)* {
    for $id-element in collection($lnk:path-base)//tei:idno[. = $id]
    let $parallel-domains := tokenize($id-element/parent::j:parallelText/tei:linkGrp/@domains/string(), "\s+")
    let $left-domain := uri:uri-base-path($parallel-domains[1])
    let $right-domain := uri:uri-base-path($parallel-domains[2])
    return
        element lnkid:result {
            element lnkid:linkage { data:db-path-to-api(document-uri(root($id-element))) },
            element lnkid:left { "/api" || $left-domain }, (: I am assuming here that the domains contain api-like paths, but lack /api prepended :)
            element lnkid:right { "/api" || $right-domain }
        }
};

(:~ Get a list of documents that are linked to by a given linkage ID
 : There is no actual "linkageid" document - it is really a search and just supports the GET verb.
 : @param $name Document name as a string
 : @error HTTP 404 Not found (or not available)
 :)
declare
  %rest:GET
  %rest:path("/api/data/linkageid/{$name}")
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("xhtml")
  function lnkid:get(
    $name as xs:string
  ) as item()+ {
    <rest:response>
      <output:serialization-parameters>
        <output:method>xhtml</output:method>
      </output:serialization-parameters>
    </rest:response>,
    let $results := lnkid:list-by-id($name)
    return
        if (empty($results))
        then api:rest-error(404, "Not found", $name)
        else
            <html xmlns="http://www.w3.org/1999/xhtml">
                <head>
                    <title>{$name}</title>
                </head>
                <body>
                    <ul class="results">{
                        for $result in $results
                        let $linkage := $result/lnkid:linkage/string()
                        let $left := $result/lnkid:left/string()
                        let $right := $result/lnkid:right/string()
                        let $log := util:log("INFO", ("***linkage=", $linkage, " left=", $left, " right=", $right))
                        return
                            <li class="result">
                                <a class="document linkage" href="{$linkage}">{crest:tei-title-function(data:doc($linkage))}</a>
                                { ": " }
                                <a class="document left" href="{$left}">{crest:tei-title-function(data:doc($left))}</a>
                                { " = " }
                                <a class="document right" href="{$right}">{crest:tei-title-function(data:doc($right))}</a>
                            </li>
                    }</ul>
                </body>
            </html>
};