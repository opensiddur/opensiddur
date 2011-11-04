xquery version "1.0";
(:~ index for the whole API
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)

module namespace index='http://jewishliturgy.org/api';

import module namespace api="http://jewishliturgy.org/modules/api" 
  at "/code/api/modules/api.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 

declare variable $index:test-source := "/code/tests/api/api.t.xml"; 
declare variable $index:allowed-methods := "GET";
declare variable $index:accept-content-type := api:html-content-type();
declare variable $index:request-content-type := ();

declare function local:disallowed() {
  api:allowed-method($index:allowed-methods),
  api:error((), "Method not allowed")
};

declare function index:get(
  ) as element() {
  let $accepted := api:get-accept-format($index:accept-content-type)
  let $test-result := api:tests($index:test-source)
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($test-result)
    then $test-result
    else
      let $base := '/code/api'
      let $list-body := 
        <ul class="common">{
          api:list-item(
            "User management",
            concat($base, "/user"),
            "GET",
            api:html-content-type(), ()
          ),
          api:list-item(
            "Data",
            concat($base, "/data"),
            "GET",
            api:html-content-type(), ()
          )
        }</ul>
      return (
        api:serialize-as('xhtml', $accepted),
        api:list(
          <title>Open Siddur API</title>,
          $list-body,
          0,
          false(),
          $index:allowed-methods,
          $index:accept-content-type, 
          $index:request-content-type,
          $index:test-source
        )
      )
};

declare function index:put() {
  local:disallowed()
};

declare function index:post() {
  local:disallowed()
};

declare function index:delete() {
  local:disallowed()
};

declare function index:go() {
  let $method := api:get-method()
  return
    if ($method="GET")
    then index:get()
    else local:disallowed()
};