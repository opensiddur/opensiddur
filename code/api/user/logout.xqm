xquery version "1.0";
(: api logout action
 : 
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
module namespace logout="http://jewishliturgy.org/api/user/logout";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
	at "/code/modules/debug.xqm";
	
declare namespace err="http://jewishliturgy.org/errors";

declare default element namespace "http://www.w3.org/1999/xhtml"; 

declare variable $logout:allowed-methods := ("GET", "POST");
declare variable $logout:accept-content-type := (
    api:html-content-type(), 
    api:text-content-type()
  );
declare variable $logout:request-content-type := ();
declare variable $logout:test-source := "/code/tests/api/user/logout.t.xml";

declare function logout:title(
  $uri as xs:anyAtomicType
  ) as xs:string {
  "Session based logout"
};

declare function logout:allowed-methods(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $logout:allowed-methods
};

declare function logout:accept-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $logout:accept-content-type
};

declare function logout:request-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $logout:request-content-type
};

declare function logout:list-entry(
  $uri as xs:anyAtomicType
  ) as element(li) {
  (: this function probably does not have to change :)
  api:list-item(
    element span {logout:title($uri)},
    $uri,
    logout:allowed-methods($uri),
    logout:accept-content-type($uri),
    logout:request-content-type($uri),
    ()
  )
};

declare function local:disallowed() {
  (: This probably needs no changes :)
  api:allowed-method($logout:allowed-methods),
  api:error((), "Method not allowed")
};

(:~ GET is either a request to log out or a discovery request. 
 :)
declare function logout:get() {
  let $test-result := api:tests($logout:test-source)
  let $accepted := api:get-accept-format($logout:accept-content-type)
  let $uri := request:get-uri()
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($test-result)
    then $test-result
    else 
      let $user := app:auth-user()
      let $format := api:simplify-format($accepted, "xhtml")
      return (
        api:serialize-as($format, $accepted),
        if ($format = "txt")
        then logout:post()
        else if ($format = "xhtml")
        then 
          api:list(
            element title { logout:title($uri) },
            element ul {
              attribute class { "common" },
              element li { "Logout service" }
            },
            0,
            false(),
            logout:allowed-methods($uri),
            logout:accept-content-type($uri),
            logout:request-content-type($uri),
            $logout:test-source
          )
        else error(xs:QName("err:INTERNAL"), "An internal error must have occurred. You should never get here.") 
      )
};

(:~ this is a request to log in :)
declare function logout:put() {
  local:disallowed()
};

declare function logout:post() {
  app:logout-credentials(),
  response:set-status-code(204)
};

(:~ request to log out :)
declare function logout:delete() {
  local:disallowed()
};

declare function logout:go() {
  let $method := api:get-method()
  return
    if ($method = "GET")
    then logout:get()
    else if ($method = "PUT") 
    then logout:put()
    else if ($method = "POST")
    then logout:post()
    else if ($method = "DELETE")
    then logout:delete()
    else local:disallowed()
};