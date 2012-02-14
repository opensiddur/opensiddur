xquery version "1.0";
(:~ Activity to format a document resource.
 : Required parameters:
 :  to= format
 :  output= group
 :  style=  location of style file
 :
 : Method: POST
 : Status:
 : 	202 Accepted, request is queued for processing
 :	401, 403 Authentication
 :	404 Bad format 
 : Returns Location header
 :
 : Open Siddur Project 
 : Copyright 2011-2012 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace compile="http://jewishliturgy.org/api/data/compile";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
	at "/code/api/modules/data.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
	at "/code/modules/format.xqm";
import module namespace jcache="http://jewishliturgy.org/modules/cache"
	at "/code/modules/cache-controller.xqm";
import module namespace nav="http://jewishliturgy.org/modules/nav"
  at "/code/api/modules/nav.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $compile:valid-compile-targets := ('fragmentation', 'debug-data-compile', 'debug-list-compile', 'xhtml', 'html');

declare variable $compile:allowed-methods := ("GET","POST");
declare variable $compile:accept-content-type := api:html-content-type();
declare variable $compile:request-content-type := api:html-content-type();
declare variable $compile:test-source := "/code/tests/api/data/compile.t.xml";

declare function compile:title(
  $uri as xs:anyAtomicType
  ) as xs:string {
  "Compilation"
};

declare function compile:allowed-methods(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $compile:allowed-methods
};

declare function compile:accept-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $compile:accept-content-type
};

declare function compile:request-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $compile:request-content-type
};

declare function compile:list-entry(
  $uri as xs:anyAtomicType
  ) as element(li) {
  (: this function probably does not have to change :)
  api:list-item(
    element span {compile:title($uri)},
    $uri,
    compile:allowed-methods($uri),
    compile:accept-content-type($uri),
    compile:request-content-type($uri),
    ()
  )
};

declare function local:disallowed() {
  let $d := api:allowed-method($compile:allowed-methods)
  where not($d)
  return api:error((), "Method not allowed")
};

declare function compile:get() {
  let $test-result := api:tests($compile:test-source)
  let $accepted := api:get-accept-format($compile:accept-content-type)
  let $uri := request:get-uri()
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($test-result)
    then $test-result
    else (
      api:serialize-as("xhtml", $accepted),
      let $list-body := (
        <ul class="common">{
          <li>POST to this URL starts the background compilation of the resource {replace($uri, "/-compiled$", "")}. 
          The "to" parameter is required, indicating the output format, which may be one of:
            <ul>
              {
              for $format in $compile:valid-compile-targets
              return
                <li>{$format}</li>
              }
            </ul>
          </li>
        }</ul>,
        (: insert results here :) ()
      )
      return
        api:list(
          <title>{compile:title($uri)}</title>,
          $list-body,
          count($list-body/self::ul[@class="results"]/li),
          false(),
          compile:allowed-methods($uri),
          compile:accept-content-type($uri),
          compile:request-content-type($uri),
          $compile:test-source
        )
    )
};

declare function compile:put() {
  local:disallowed()
};

declare function local:setup-output-share(
  $doc as document-node(),
  $output-share as xs:string
  ) as xs:string {
  let $document-name := util:document-name($doc)
  let $group-collection := concat('/group/', $output-share)
  let $output-share-path := concat($group-collection, '/output/', replace($document-name, '\.xml$', ''))
  let $permissions := sm:get-permissions(xs:anyURI($group-collection))
  return (
    app:make-collection-path(
      $output-share-path, 
      '/db',
      $permissions/*/@owner/string(),
      $permissions/*/@group/string(),
      $permissions/*/@mode/string()
      ),
    $output-share-path
  )
};

declare function compile:post() {
  if (api:require-authentication())
  then
    let $uri := request:get-uri()
    let $doc := nav:api-path-to-sequence($uri)
    let $compile := api:get-parameter("to", ())    
    return
      if (exists($doc))
      then 
        if ($compile = $compile:valid-compile-targets)
        then
          let $user := app:auth-user()
          let $document-uri := document-uri($doc)
          let $output-share-path := local:setup-output-share($doc, $user) 
          let $collection-name := util:collection-name($doc)
          let $document-name := util:document-name($doc)
          let $output-api-path := replace($uri, "original", concat("output/", $user))
          let $status-path := 
            concat($output-api-path, "/status")
          let $style := request:get-parameter("style",())
          return (
            format:enqueue-compile(
              $collection-name,
              $document-name,
              $output-share-path,
              $compile,
              $style
            ),
            response:set-status-code(202),
            response:set-header('Location', $output-api-path),
            api:list(
              element title {concat("Compile ", substring-before(request:get-uri(),"/compile"))},
              element ul {
                api:list-item(
                  "Compile status",
                  $status-path,
                  "GET",
                  api:html-content-type(),
                  ()
                )
              },
              0,
              false(),
              "POST",
              (),
              api:form-content-type()
            )
          )
        else
          api:error(400, "Bad or missing compile target", $compile)
      else
        api:error(404, "Not found")
  else
    api:error((), "Authentication required")
};

declare function compile:delete() {
  local:disallowed()
};

declare function compile:go(
  $sequence as document-node()
  ) {
  let $method := api:get-method()
  return
    if ($method = "GET")
    then compile:get()
    else if ($method = "PUT") 
    then compile:put()
    else if ($method = "POST")
    then compile:post()
    else if ($method = "DELETE")
    then compile:delete()
    else local:disallowed()
};
