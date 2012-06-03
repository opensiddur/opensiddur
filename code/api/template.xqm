(:~ 
 : template for API modules
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace apit = 'http://jewishliturgy.org/api/template';

import module namespace api="http://jewishliturgy.org/modules/api" 
  at "/code/api/modules/api.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 

declare variable $apit:allowed-methods := "GET";
declare variable $apit:accept-content-type := api:html-content-type();
declare variable $apit:request-content-type := ();
declare variable $apit:test-source := "LINK TO TEST SOURCE HERE";

declare function apit:title(
  $uri as xs:anyAtomicType
  ) as xs:string {
  "Insert title here. This function can check languages too."
};

declare function apit:allowed-methods(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $apit:allowed-methods
};

declare function apit:accept-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $apit:accept-content-type
};

declare function apit:request-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $apit:request-content-type
};

declare function apit:list-entry(
  $uri as xs:anyAtomicType
  ) as element(li) {
  (: this function probably does not have to change :)
  api:list-item(
    element span {apit:title($uri)},
    $uri,
    apit:allowed-methods($uri),
    apit:accept-content-type($uri),
    apit:request-content-type($uri),
    ()
  )
};

declare function local:disallowed() {
  (: This probably needs no changes :)
  let $d := api:allowed-method($apit:allowed-methods)
  where not($d)
  return api:error((), "Method not allowed")
};

declare function apit:get() {
  let $test-result := api:tests($apit:test-source)
  let $accepted := api:get-accept-format($apit:accept-content-type)
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
          ((: insert common list items here :))
        }</ul>,
        (: insert results here :) ()
      )
      return
        api:list(
          <title>{apit:title($uri)}</title>,
          $list-body,
          count($list-body/self::ul[@class="results"]/li),
          false(),
          apit:allowed-methods($uri),
          apit:accept-content-type($uri),
          apit:request-content-type($uri),
          $apit:test-source
        )
    )
};

declare function apit:put() {
  local:disallowed()
};

declare function apit:post() {
  local:disallowed()
};

declare function apit:delete() {
  local:disallowed()
};

declare function apit:go() {
  let $method := api:get-method()
  return
    if ($method = "GET")
    then apit:get()
    else if ($method = "PUT") 
    then apit:put()
    else if ($method = "POST")
    then apit:post()
    else if ($method = "DELETE")
    then apit:delete()
    else local:disallowed()
};

