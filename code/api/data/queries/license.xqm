xquery version "1.0";
(:~ Represents the URI of the license
 :
 : Open Siddur Project 
 : Copyright 2011 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace lic="http://jewishliturgy.org/api/data/license";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "/code/modules/app.xqm";
import module namespace nav="http://jewishliturgy.org/modules/nav"
	at "/code/api/modules/nav.xqm";
import module namespace resp="http://jewishliturgy.org/modules/resp"
  at "/code/modules/resp.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "/code/modules/debug.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $lic:allowed-methods := ("GET","PUT");
declare variable $lic:accept-content-type := (
  api:html-content-type(),
  api:text-content-type()
  );
declare variable $lic:request-content-type := (
  api:text-content-type(),
  api:form-content-type()
  );
declare variable $lic:test-source := "/code/tests/api/data/license.t.xml";

declare function lic:title(
  $uri as xs:anyAtomicType
  ) as xs:string {
  "License"
};

declare function lic:allowed-methods(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $lic:allowed-methods
};

declare function lic:accept-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $lic:accept-content-type
};

declare function lic:request-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $lic:request-content-type
};

declare function lic:list-entry(
  $uri as xs:anyAtomicType
  ) as element(li) {
  api:list-item(
    element span {lic:title($uri)},
    $uri,
    lic:allowed-methods($uri),
    lic:accept-content-type($uri),
    lic:request-content-type($uri),
    ()
  )
};

declare function local:disallowed() {
  let $d := api:allowed-method($lic:allowed-methods)
  where not($d)
  return api:error((), "Method not allowed")
};

declare function lic:get() {
  let $test-result := api:tests($lic:test-source)
  let $accepted := api:get-accept-format($lic:accept-content-type)
  let $uri := request:get-uri()
  let $doc := nav:api-path-to-sequence($uri)
  let $license-uri := $doc//tei:ref[@type="license"]/@target/string()
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($test-result)
    then $test-result
    else 
      (: TODO: determine write authorization... :)
      let $format := api:simplify-format($accepted, "txt")
      return
        if ($format="xhtml")
        then (
          api:serialize-as("xhtml", $accepted),
          let $list-body :=
            <ul class="common">{
              <li>{$license-uri}</li>
            }</ul>
          return
            api:list(
              <title>{lic:title($uri)}</title>,
              $list-body,
              0,
              false(),
              lic:allowed-methods($uri),
              lic:accept-content-type($uri),
              lic:request-content-type($uri),
              $lic:test-source
            )
        )
        else (
          api:serialize-as("txt", $accepted),
          $license-uri
        )
};

declare function lic:put() {
  if (api:require-authentication())
  then 
    let $uri := request:get-uri()
    let $license-templates := doc('/code/modules/code-tables/licenses.xml')/code-table
    let $data := api:get-parameter("license", (), true())
    let $new-lic := string($data)
    let $boilerplate :=
      $license-templates/license[id=$new-lic]/tei:availability
    let $doc := nav:api-path-to-sequence($uri)
    let $node := $doc//tei:availability
    return 
      if (exists($boilerplate))
      then (
        response:set-status-code(204),
        resp:remove($node),
        update replace $node with $boilerplate,
        resp:add($doc//id($boilerplate/@xml:id), "editor", app:auth-user(), "value")
      )
      else 
        api:error(400, "The given license URI is not allowed.", $new-lic) 
  else api:error((), "Authentication required.")
};

declare function lic:post() {
  local:disallowed()
};

declare function lic:delete() {
  local:disallowed()
};

declare function lic:go(
  $d as document-node()
  ) {
  let $method := api:get-method()
  return
    if ($method = "GET")
    then lic:get()
    else if ($method = "PUT") 
    then lic:put()
    else if ($method = "POST")
    then lic:post()
    else if ($method = "DELETE")
    then lic:delete()
    else local:disallowed()
};