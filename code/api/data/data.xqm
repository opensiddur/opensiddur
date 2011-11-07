xquery version "1.0";
(: api to check for user existence or list available profile resources
 : 
 : Method: GET
 : Return: 
 :		200 + menu (list available data types)
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
module namespace dindex="http://jewishliturgy.org/api/data";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare namespace err="http://jewishliturgy.org/errors";

declare variable $dindex:allowed-methods := "GET";
declare variable $dindex:accept-content-type := api:html-content-type();
declare variable $dindex:request-content-type := ();
declare variable $dindex:test-source := "/code/tests/api/data/data.t.xml";

declare function dindex:title(
  $uri as xs:anyAtomicType
  ) as xs:string {
  "Data API Index"
};

declare function dindex:allowed-methods(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $dindex:allowed-methods
};

declare function dindex:accept-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $dindex:accept-content-type
};

declare function dindex:request-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $dindex:request-content-type
};

declare function dindex:list-entry(
  $uri as xs:anyAtomicType
  ) as element(li) {
  (: this function probably does not have to change :)
  api:list-item(
    element span {dindex:title($uri)},
    $uri,
    dindex:allowed-methods($uri),
    dindex:accept-content-type($uri),
    dindex:request-content-type($uri),
    ()
  )
};

declare function local:disallowed() {
  (: This probably needs no changes :)
  api:allowed-method($dindex:allowed-methods),
  api:error((), "Method not allowed")
};

declare function dindex:get() {
  let $test-result := api:tests($dindex:test-source)
  let $accepted := api:get-accept-format($dindex:accept-content-type)
  let $uri := request:get-uri()
  let $base := "/code/api/data"
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($test-result)
    then $test-result
    else (
      api:serialize-as("xhtml", $accepted),
      let $list-body := (
        <ul class="common">{
          api:list-item("Contributor lists",
            concat($base, "/contributors"), 
            ("GET", "POST"),
            api:html-content-type(),
            api:tei-content-type("tei:div")
          ),
          api:list-item("Original texts",
            concat($base, "/original"),
            "GET",
            api:html-content-type(),
            ()
          ),
          api:list-item("Parallel text tables",
            concat($base, "/parallel"),
            "GET",
            api:html-content-type(),
            ()
          ),
          api:list-item("Bibliographic data",
            concat($base, "/sources"),
            ("GET", "POST"),
            api:html-content-type(),
            api:tei-content-type("tei:biblStruct")
          ),
          api:list-item("Translation texts",
            concat($base, "/translation"),
            ("GET"),
            api:html-content-type(),
            ()
          ),
          api:list-item("Transliteration tables",
            concat($base, "/transliteration"),
            ("GET"),
            api:html-content-type(),
            ()
          ),
          api:list-item("Generated output",
            concat($base, "/output"),
            ("GET"),
            api:html-content-type(),
            ()
          )
        }</ul>
      )
      return
        api:list(
          <title>{dindex:title($uri)}</title>,
          $list-body,
          count($list-body/self::ul[@class="results"]/li),
          false(),
          dindex:allowed-methods($uri),
          dindex:accept-content-type($uri),
          dindex:request-content-type($uri),
          $dindex:test-source
        )
    )
};

declare function dindex:put() {
  local:disallowed()
};

declare function dindex:post() {
  local:disallowed()
};

declare function dindex:delete() {
  local:disallowed()
};

declare function dindex:go() {
  let $method := api:get-method()
  return
    if ($method = "GET")
    then dindex:get()
    else if ($method = "PUT") 
    then dindex:put()
    else if ($method = "POST")
    then dindex:post()
    else if ($method = "DELETE")
    then dindex:delete()
    else local:disallowed()
};

