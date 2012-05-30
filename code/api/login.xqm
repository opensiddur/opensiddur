xquery version "1.0";
(: api login
 : 
 : Open Siddur Project
 : Copyright 2011-2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
module namespace login="http://jewishliturgy.org/api/login";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
	at "/code/modules/debug.xqm";
	
declare namespace rest="http://exquery.org/ns/rest/annotation/";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace error="http://jewishliturgy.org/errors"; 

(:~ GET is a query for who is logged in. 
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
 :)
declare 
  %rest:GET
  %rest:path("/api/login")
  %rest:query-param("user", "{$user}")
  %rest:query-param("password", "{$password}")
  %rest:produces("application/xhtml+xml", "text/html")
  function login:get-html(
    $user as xs:string?,
    $password as xs:string?
  ) as item()+ {
  let $did-login :=
    if ($user and $password)
    then
      login:post-form($user, $password)
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

declare 
  %rest:POST("{$body}")
  %rest:path("/api/login")
  %rest:consumes("application/xml", "text/xml")
  %rest:produces("text/plain")
  function login:post-xml(
    $body as document-node()
  ) as item()+ {
  login:post-form($body//user, $body//password)
};

declare 
  %rest:POST
  %rest:path("/api/login")
  %rest:form-param("user", "{$user}")
  %rest:form-param("password", "{$password}")
  %rest:consumes("application/x-www-url-formencoded")
  %rest:produces("text/plain")
  function login:post-form(
    $user as xs:string?,
    $password as xs:string?
  ) as item()+ {
  if (not($user) or not($password))
  then 
    api:rest-error(400, "User name and password are required")
  else
    if (xmldb:authenticate("/db", $user, $password))
    then (
      debug:debug($debug:info, "login",
        ('Logging in ', $user, ':', $password)),
      app:login-credentials($user, $password),
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

(:~ log out :)
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

(:~ request to log out :)
declare 
  %rest:DELETE
  %rest:path("/api/login")
  function login:delete(
  ) as item()+ {
  local:logout()
};

(:~ request to log out :)
declare 
  %rest:GET
  %rest:path("/api/logout")
  function login:get-logout(
  ) as item()+ {
  local:logout()
};

(:~ request to log out :)
declare 
  %rest:POST
  %rest:path("/api/logout")
  function login:post-logout(
  ) as item()+ {
  local:logout()
};

