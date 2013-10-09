xquery version "1.0";
(:~ api login
 : 
 : Open Siddur Project
 : Copyright 2011-2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
module namespace login="http://jewishliturgy.org/api/login";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "../modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "../modules/app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
	at "../modules/debug.xqm";
	
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace error="http://jewishliturgy.org/errors"; 

(:~ Query who is currently logged in. 
 : @return HTTP 200 with an XML entity with the currently logged in user 
 :)
declare 
  %rest:GET
  %rest:path("/api/login")
  %rest:produces("application/xml", "text/xml")
  function login:get-xml() {
  let $user := app:auth-user()
  return <login xmlns="">{$user}</login>
};

(:~ GET HTML: usually, used as a who am I function, 
 : but may also be used to log in by query params.
 : Please do not use it that way, except for debugging
 : @param $user User to log in via HTTP GET
 : @param $password Password of user to log in via HTTP GET
 : @return Who am I as HTML
 :)
declare 
  %rest:GET
  %rest:path("/api/login")
  %rest:query-param("user", "{$user}", "")
  %rest:query-param("password", "{$password}", "")
  %rest:query-param("auth-only", "{$auth-only}", "")
  %rest:produces("application/xhtml+xml", "text/html")
  function login:get-html(
    $user as xs:string*,
    $password as xs:string*,
    $auth-only as xs:string*
  ) as item()+ {
  let $did-login :=
    if ($user and $password)
    then
      login:post-form($user[1], $password[1], $auth-only[1])
    else ()
  return (
    <rest:response>
      <output:serialization-parameters>
        <output:method value="html5"/>
      </output:serialization-parameters>
    </rest:response>,
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head>
        <title>Login: who am I?</title>
      </head>
      <body>
        <div class="result">{app:auth-user()}</div>
      </body>
    </html>
  )
};

(:~ Log in a user using XML parameters
 : @param $body A document containing login/(user/string(), password/string())
 : @return HTTP 204 Login successful
 : @error HTTP 400 Wrong user name or password
 :)
declare 
  %rest:POST("{$body}")
  %rest:path("/api/login")
  %rest:query-param("auth-only", "{$auth-only}", "")
  %rest:consumes("application/xml", "text/xml")
  %rest:produces("text/plain")
  function login:post-xml(
    $body as document-node(),
    $auth-only as xs:string*
  ) as item()+ {
  login:post-form($body//user, $body//password, $auth-only)
};

(:~ Log in a user using a form
 : @param $user User name
 : @param $password Password
 : @param $auth-only Authenticate only, but do not start a session
 : @return HTTP 204 Login successful
 : @error HTTP 400 Wrong user name or password
 :)
declare 
  %rest:POST
  %rest:path("/api/login")
  %rest:form-param("user", "{$user}")
  %rest:form-param("password", "{$password}")
  %rest:query-param("auth-only", "{$auth-only}", "")
  %rest:consumes("application/x-www-url-formencoded")
  %rest:produces("text/plain")
  function login:post-form(
    $user as xs:string*,
    $password as xs:string*,
    $auth-only as xs:string*
  ) as item()+ {
  let $user := $user[1]
  let $password := $password[1]
  let $auth-only := $auth-only[1]
  return
    if (empty($user) or empty($password))
    then 
      api:rest-error(400, "User name and password are required")
    else
      if (xmldb:authenticate("/db", $user, $password))
      then (
        debug:debug($debug:info, "login",
          ('Logging in ', $user, ':', $password)),
        if (not($auth-only) or lower-case($auth-only) = "false")
        then
          app:login-credentials($user, $password)
        else (),
        <rest:response>
          <output:serialization-parameters>
            <output:method value="text"/>
          </output:serialization-parameters>
          <http:response status="204"/>
        </rest:response>
      )
      else (
        api:rest-error(400,"Wrong user name or password")
      )
};

(:~ log out 
 : @return HTTP 204 
 :)
declare function local:logout(
  ) as element(rest:response) {
  app:logout-credentials(),
  <rest:response>
    <output:serialization-parameters>
      <output:method value="text"/>
    </output:serialization-parameters>
    <http:response status="204"/>
  </rest:response>
};

(:~ request to log out from session-based login
 : @return HTTP 204 on success
 :)
declare 
  %rest:DELETE
  %rest:path("/api/login")
  function login:delete(
  ) as item()+ {
  local:logout()
};

(:~ request to log out from session-based login
 : @see login:delete
 :)
declare 
  %rest:GET
  %rest:path("/api/logout")
  function login:get-logout(
  ) as item()+ {
  local:logout()
};

(:~ request to log out 
 : @see login:delete
 :)
declare 
  %rest:POST
  %rest:path("/api/logout")
  function login:post-logout(
  ) as item()+ {
  local:logout()
};

