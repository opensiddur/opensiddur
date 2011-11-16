xquery version "1.0";
(: api login action
 : 
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
module namespace login="http://jewishliturgy.org/api/user/login";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
	at "/code/modules/debug.xqm";
	
declare namespace err="http://jewishliturgy.org/errors";

declare default element namespace "http://www.w3.org/1999/xhtml"; 

declare variable $login:allowed-methods := ("GET", "PUT", "DELETE");
declare variable $login:accept-content-type := (
  api:html-content-type(),
  api:text-content-type()
  );
declare variable $login:request-content-type := (
  api:xml-content-type(),
  api:form-content-type(),
  api:text-content-type()
  );
declare variable $login:test-source := "/code/tests/api/user/login.t.xml";

declare function login:title(
  $uri as xs:anyAtomicType
  ) as xs:string {
  "Session based login"
};

declare function login:allowed-methods(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $login:allowed-methods
};

declare function login:accept-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $login:accept-content-type
};

declare function login:request-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  $login:request-content-type
};

declare function login:list-entry(
  $uri as xs:anyAtomicType
  ) as element(li) {
  (: this function probably does not have to change :)
  api:list-item(
    element span {login:title($uri)},
    $uri,
    login:allowed-methods($uri),
    login:accept-content-type($uri),
    login:request-content-type($uri),
    ()
  )
};

declare function local:disallowed() {
  let $d := api:allowed-method($login:allowed-methods)
  where not($d)
  return api:error((), "Method not allowed")
};

(:~ GET is usually a query for who is logged in. 
 : Returns HTTP 204 if nobody :)
declare function login:get() {
  let $test-result := api:tests($login:test-source)
  let $accepted := api:get-accept-format($login:accept-content-type)
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
        then 
          if ($user)
          then $user
          else response:set-status-code(204)
        else if ($format = "xhtml")
        then 
          api:list(
            element title { login:title($uri) },
            element ul {
              attribute class { "results" },
              element li { $user }[$user]
            },
            count($user),
            false(),
            login:allowed-methods($uri),
            login:accept-content-type($uri),
            login:request-content-type($uri),
            $login:test-source
          )
        else error(xs:QName("err:INTERNAL"), "An internal error must have occurred. You should never get here.") 
      )
};

(:~ this is a request to log in :)
declare function login:put() {
  let $user-name := request:get-parameter("user-name", ())
  let $password := string(api:get-parameter("password", "", true()))
  return
    if (xmldb:authenticate('/db', $user-name, $password))
    then (
      debug:debug($debug:info, "login",
        ('Logging in ', $user-name, ':', $password)),
      response:set-status-code(204),
      app:login-credentials($user-name, $password)
    )
    else (
      api:error(400,'Wrong username or password')
    )
};

declare function login:post() {
  local:disallowed()
};

(:~ request to log out :)
declare function login:delete() {
  app:logout-credentials(),
  response:set-status-code(204)
};

declare function login:go() {
  let $method := api:get-method()
  return
    if ($method = "GET")
    then login:get()
    else if ($method = "PUT") 
    then login:put()
    else if ($method = "POST")
    then login:post()
    else if ($method = "DELETE")
    then login:delete()
    else local:disallowed()
};