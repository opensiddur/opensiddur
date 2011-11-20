(:~ 
 : navigation API for a document
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace navdoc = 'http://jewishliturgy.org/api/data/navdoc';

import module namespace api="http://jewishliturgy.org/modules/api" 
  at "/code/api/modules/api.xqm";
import module namespace nav="http://jewishliturgy.org/modules/nav"
  at "/code/api/modules/nav.xqm";
import module namespace navel="http://jewishliturgy.org/api/data/navel"
  at "navel.xqm";
import module namespace navat="http://jewishliturgy.org/api/data/navat"
  at "navat.xqm";
import module namespace compile="http://jewishliturgy.org/api/data/compile"
  at "compile.xqm";
import module namespace lic="http://jewishliturgy.org/api/data/license"
  at "license.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

declare variable $navdoc:allowed-methods := ("GET","PUT","DELETE");
declare variable $navdoc:accept-content-type := (
  api:html-content-type(),
  api:xml-content-type(),
  api:tei-content-type()
  );
declare variable $navdoc:request-content-type := (
  api:xml-content-type(),
  api:tei-content-type()
  );
declare variable $navdoc:test-source := "/code/tests/api/data/original/navdoc.t.xml";

declare function navdoc:title(
  $uri-or-doc-node as item()
  ) as xs:string {
  let $doc := 
    if ($uri-or-doc-node instance of document-node())
    then $uri-or-doc-node
    else nav:api-path-to-sequence($uri-or-doc-node)
  return
    string($doc//tei:title[@type="main"])
};

declare function navdoc:allowed-methods(
  $uri as item()
  ) as xs:string* {
  $navdoc:allowed-methods
};

declare function navdoc:accept-content-type(
  $uri as item()
  ) as xs:string* {
  $navdoc:accept-content-type
};

declare function navdoc:request-content-type(
  $uri as item()
  ) as xs:string* {
  $navdoc:request-content-type
};

declare function navdoc:list-entry(
  $uri as item()
  ) as element(li) {
  api:list-item(
    element span {navdoc:title($uri)},
    if ($uri instance of document-node())
    then nav:sequence-to-api-path($uri)
    else $uri,
    navdoc:allowed-methods($uri),
    navdoc:accept-content-type($uri),
    navdoc:request-content-type($uri),
    ()
  )
};

declare function local:disallowed() {
  let $d := api:allowed-method($navdoc:allowed-methods)
  where not($d)
  return api:error((), "Method not allowed")
};

(: check if we have access to the document and if it exists 
 : if it doesn't exist, use error 404. If we do not have access
 : send 401 (if not logged in) or 403 (if logged in as a different user)
 :)
declare function local:unauthorized-read(
  $uri as xs:string
  ) as element()? {
  let $document := nav:api-path-to-sequence($uri)
  where empty($document) 
  return
    api:error(404, "Document cannot be found", $uri)
};

(: check if the user has write access to a document :)
declare function local:unauthorized-write(
  $uri as xs:string
  ) as element()? {
  let $document := nav:api-path-to-sequence($uri)
  where empty($document) 
  return
    api:error(404, "Document cannot be found", $uri)
};

declare function navdoc:get() {
  let $test-result := api:tests($navdoc:test-source)
  let $accepted := api:get-accept-format($navdoc:accept-content-type)
  let $format := api:simplify-format($accepted, "xhtml")
  let $uri := request:get-uri()
  let $doc := nav:api-path-to-sequence($uri)
  let $unauthorized := local:unauthorized-read($uri)
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($test-result)
    then $test-result
    else if ($unauthorized)
    then $unauthorized
    else if ($format = ("tei", "xml"))
    then (
      api:serialize-as("xml", $accepted),
      $doc
    )
    else (
      api:serialize-as("xhtml", $accepted),
      let $list-body := (
        <ul class="common">{
          for $entry-point in $nav:shortcuts/*[string(@to)]
          let $entry-point-uri := concat($uri, "/", $entry-point/@path)
          let $ep := nav:api-path-to-sequence($entry-point-uri)
          let $allowed-methods := 
            typeswitch($ep)
            case element() return navel:allowed-methods($ep)
            case element()+ return "GET"
            case attribute() return navat:allowed-methods($ep)
            default return ()
          let $accept-content-types :=
            typeswitch($ep)
            case element() return navel:accept-content-type($ep)
            case element()+ return (api:html-content-type(), api:xml-content-type(), api:tei-content-type())
            case attribute() return navat:accept-content-type($ep)
            default return ()
          let $request-content-types :=
            typeswitch($ep)
            case element() return navel:request-content-type($ep)
            case element()+ return ()
            case attribute() return navat:request-content-type($ep)
            default return ()
          return
            api:list-item(
              <span>{$entry-point/nav:name/string()}</span>,
              $entry-point-uri,
              $allowed-methods,
              $accept-content-types,
              $request-content-types,
              ()
            ),
          let $compile-link := concat($uri, "/-compiled")
          let $license-link := concat($uri, "/-license")
          return (
            compile:list-entry($compile-link),
            lic:list-entry($license-link)
          )
        }</ul>,
        <ul class="results">{
          navel:list-entry($doc/*)
        }</ul>
      )
      return
        api:list(
          <title>{navdoc:title($uri)}</title>,
          $list-body,
          count($list-body/self::ul[@class="results"]/li),
          true(),
          navdoc:allowed-methods($uri),
          navdoc:accept-content-type($uri),
          navdoc:request-content-type($uri),
          $navdoc:test-source
        )
    )
};

declare function navdoc:put() {
  let $uri := request:get-uri()
  let $unauthorized := local:unauthorized-write($uri)
  let $doc := nav:api-path-to-sequence($uri)
  let $root := $doc/*
  let $replacement := api:get-data()
  let $accepted := api:get-accept-format($navdoc:request-content-type)
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($unauthorized)
    then $unauthorized
    else if (not(local-name($replacement)=local-name($root))
      and (namespace-uri($replacement)=namespace-uri($root)))
    then
      api:error(400, "The new document must have the same root element as the one it is replacing.", name($replacement))
    else 
      if (xmldb:store(util:collection-name($doc), util:document-name($doc),
        $replacement))
      then (
        response:set-status-code(204)
        )
      else 
        api:error(500, "The document could not be stored.")
};

declare function navdoc:post() {
  local:disallowed()
};

declare function navdoc:delete() {
  let $uri := request:get-uri()
  let $unauthorized := local:unauthorized-write($uri)
  return
    if ($unauthorized)
    then $unauthorized
    else 
      let $doc := nav:api-path-to-sequence($uri)
      let $collection := util:collection-name($doc)
      let $name := util:document-name($doc)
      return (
        xmldb:remove($collection, $name),
        response:set-status-code(204)
      )
};

declare function navdoc:go(
  ) {
  navdoc:go(nav:api-path-to-sequence(request:get-uri()))
};

declare function navdoc:go(
  $doc as document-node()
  ) {
  let $method := api:get-method()
  return
    if ($method = "GET")
    then navdoc:get()
    else if ($method = "PUT") 
    then navdoc:put()
    else if ($method = "POST")
    then navdoc:post()
    else if ($method = "DELETE")
    then navdoc:delete()
    else local:disallowed()
};

