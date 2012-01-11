(:~ 
 : Serve the -combined activity, which GETs the cached version
 : of a given document or element (which must have an id!)
 : and PUTs back a combined version using the roundtrip transform
 : May GET/PUT in either XML or transformed XHTML. 
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace combine = 'http://jewishliturgy.org/api/data/combine';

import module namespace app="http://jewishliturgy.org/modules/app" 
  at "/code/modules/app.xqm";
import module namespace api="http://jewishliturgy.org/modules/api" 
  at "/code/api/modules/api.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "/code/modules/format.xqm";
import module namespace jcache="http://jewishliturgy.org/modules/cache"
  at "/code/modules/cache-controller.xqm";
import module namespace nav="http://jewishliturgy.org/modules/nav"
  at "nav.xqm";
import module namespace reverse="http://jewishliturgy.org/modules/reverse"
  at "/code/transforms/reverse-to-db/reverse.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";

declare variable $combine:allowed-methods := ("GET", "PUT");
declare variable $combine:accept-content-type := (
  api:html-content-type(true()),
  api:xml-content-type(),
  api:tei-content-type()
  );
declare variable $combine:request-content-type := (
  api:html-content-type(true()),
  api:xml-content-type(),
  api:tei-content-type()
  );
declare variable $combine:test-source := "/code/tests/api/data/original/combine.t.xml";

declare function combine:title(
  $uri as xs:anyAtomicType
  ) as xs:string {
  "Combined mode"
};

declare function combine:allowed-methods(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $combine:allowed-methods
};

declare function combine:accept-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $combine:accept-content-type
};

declare function combine:request-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $combine:request-content-type
};

(:~ indicates if the selected URI or node can be represented 
 : in the combine state 
 :)
declare function combine:is-combinable(
  $uri-or-node as item()
  ) as xs:boolean {
  let $item := 
    typeswitch($uri-or-node)
    case xs:anyAtomicType return nav:api-path-to-sequence($uri-or-node) 
    default return $uri-or-node
  return (
    $item instance of document-node() or
    ($item instance of element() and exists($item/@xml:id))
  )
};

declare function combine:list-entry(
  $uri as xs:anyAtomicType
  ) as element(li) {
  (: this function probably does not have to change :)
  if (combine:is-combinable($uri))
  then
    api:list-item(
      element span {combine:title($uri)},
      $uri,
      combine:allowed-methods($uri),
      combine:accept-content-type($uri),
      combine:request-content-type($uri),
      ()
    )
  else ()
};

declare function local:disallowed() {
  (: This probably needs no changes :)
  let $d := api:allowed-method($combine:allowed-methods)
  where not($d)
  return api:error((), "Method not allowed")
};

declare function combine:get() {
  let $test-result := api:tests($combine:test-source)
  let $accepted := api:get-accept-format($combine:accept-content-type)
  let $uri := request:get-uri()
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($test-result)
    then $test-result
    else 
      let $format := api:simplify-format($accepted, "none")
      let $sequence := nav:api-path-to-sequence($uri)
      let $doc-root := root($sequence)
      let $doc-uri := document-uri($doc-root)
      let $null := 
        (: make sure the cache is up to date :)
        jcache:cache-all($doc-uri)
      let $cached-document-path := jcache:cached-document-path($doc-uri)
      let $cached-document := doc($cached-document-path)
      let $cached-xml := 
        let $cached-content :=
          typeswitch($sequence)
          case document-node() return $cached-document/*
          default return $cached-document//*[@jx:id=$sequence/@xml:id][1]
        return
          (: add @xml:base so the pointers will point to the right place
           : the likely URI for here is .../-id/***/-combined
           : the base URI is ...
           :)
          element { QName(namespace-uri($cached-content), name($cached-content) ) } {
            if ($cached-content/@xml:base)
            then ()
            else attribute xml:base { base-uri($cached-content) },
            if ($cached-content/@jx:document-uri)
            then ()
            else $cached-content/ancestor::*[@jx:document-uri][1]/@jx:document-uri,
            if ($cached-content/@xml:lang)
            then ()
            else $cached-content/ancestor::*[@xml:lang][1]/@xml:lang,
            $cached-content/(@*|*)
          }
      return (
        api:serialize-as($format, $accepted),
        if ($format = ("xml", "tei"))
        then $cached-xml
        else (
          (: html :)
          format:format-xhtml($cached-xml, ()),
          util:declare-option("exist:serialize", "indent=no")
        )
      )
};

(: check if the user has write access to a document :)
declare function local:unauthorized-write(
  $uri as xs:string
  ) as element()? {
  let $element := nav:api-path-to-sequence($uri)
  where empty($element) 
  return
    api:error(404, "Not found", $uri)
};

declare function combine:put() {
  let $accepted := api:get-request-format($combine:request-content-type)
  let $uri := request:get-uri()
  let $unauthorized := local:unauthorized-write($uri)
  let $data := api:get-data()
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($unauthorized)
    then $unauthorized
    else
      let $format := api:simplify-format($accepted, "none")
      let $tei-data :=
        if ($format = ("xhtml", "html"))
        then 
          format:reverse-xhtml($data, app:auth-user(), app:auth-password())/*
        else $data
      return
        if (not($tei-data[@jx:document-uri]))
        then (
          api:error(400, "Combined data must make reference to its origin (@jx:document-uri) in the root element"),
          util:log-system-out(("Combined data: ", $tei-data))
        )
        else (
          reverse:merge(reverse:reverse($tei-data, $uri)),
          api:serialize-as("none"),
          response:set-status-code(204)
        )
};

declare function combine:post() {
  local:disallowed()
};

declare function combine:delete() {
  local:disallowed()
};

declare function combine:go(
  ) {
  combine:go(())
};

declare function combine:go(
  $sequence as item()*
  ) {
  let $method := api:get-method()
  let $uri := request:get-uri()
  let $combinable := combine:is-combinable(($sequence, $uri)[1])
  return
    if (not($combinable))
    then api:error(404, "Not found")
    else if ($method = "GET")
    then combine:get()
    else if ($method = "PUT") 
    then combine:put()
    else if ($method = "POST")
    then combine:post()
    else if ($method = "DELETE")
    then combine:delete()
    else local:disallowed()
};

