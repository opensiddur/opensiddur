(:~ 
 : Profile API
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace prof = 'http://jewishliturgy.org/api/user/profile';

import module namespace api="http://jewishliturgy.org/modules/api" 
  at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "/code/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "/code/api/modules/data.xqm";
import module namespace name="http://jewishliturgy.org/modules/name"
  at "/code/modules/name.xqm";
import module namespace user="http://jewishliturgy.org/modules/user"
  at "/code/modules/user.xqm";  
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "/code/modules/debug.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace err="http://jewishliturgy.org/errors";

declare variable $prof:allowed-methods := ("GET", "PUT", "DELETE");
declare variable $prof:accept-content-type := (
  api:html-content-type(),
  api:xml-content-type(),
  api:tei-content-type(),
  api:text-content-type()
  );
declare variable $prof:request-content-type := (
  api:xml-content-type(),
  api:tei-content-type(),
  api:text-content-type()
  );
declare variable $prof:test-source := "/code/tests/api/user/profile.t.xml";

declare function local:parse-path(
  $uri as xs:string
  ) as element() {
  let $tokens := tokenize(replace($uri, "^(/code/api/user)?/", ""), "/")
  return
    element prof:path {
      element prof:user-name { $tokens[1] },
      element prof:resource { $tokens[2] }
    }
};

declare function local:user-name(
  ) as xs:string? {
  local:user-name(request:get-uri())
};

declare function local:user-name(
  $uri as xs:string?
  ) as xs:string? {
  local:parse-path($uri)/prof:user-name/string()
};

declare function local:property-name(
  ) as xs:string? {
  local:property-name(request:get-uri())
};

declare function local:property-name(
  $uri as xs:string?
  ) as xs:string? {
  let $p := local:parse-path($uri)/prof:resource/string()
  return
    if (contains($p, "."))
    then substring-before($p, ".")
    else $p  
};

declare function local:format(
  ) as xs:string? { 
  local:format(request:get-uri())
};

declare function local:format(
  $uri as xs:string?
  ) as xs:string? {
  local:format($uri, request:get-header("Accept"))
};

declare function local:format(
  $uri as xs:string,
  $format as xs:string
  ) as xs:string? {
  let $p := local:parse-path($uri)/prof:resource/string()
  let $accepted := api:get-accept-format($prof:accept-content-type, $format)
  let $simple := api:simplify-format($accepted, "xml")
  let $fmt :=
    if (contains($p, "."))
    then substring-after($p, ".")
    else $simple
  return (
    api:serialize-as($fmt, $accepted),
    $fmt
  )
};

(:~ return a reference to a property in the user profile.
 : if the profile doesn't exist, cause an error (and attempt to create a profile
 : so the request can be retried successfully)
 :)
declare function local:get-reference(
  $user-name as xs:string,
  $property as xs:string
  ) as node()? {
  debug:debug($debug:detail, "/api/user/profile", 
    ('get-reference(): user-profile-uri=', 
      app:concat-path(xmldb:get-user-home($user-name), 'profile.xml'),
      ' I am:', xmldb:get-current-user())),
  let $user-profile-uri := app:concat-path(xmldb:get-user-home($user-name), 'profile.xml')
  let $user-profile := 
    if (doc-available($user-profile-uri))
    then doc($user-profile-uri)/*
    else 
      if (user:new-profile($user-name))
      then (
        response:redirect-to(request:get-uri()),
        api:error((), "User profile did not exist and I successfully created it. Retry the request.")
      )
      else
        api:error(500, "User profile did not exist and could not be created")
  return
    if (root($user-profile) instance of document-node())
    then
      if ($property = 'name')
      then $user-profile/tei:name
      else if ($property = 'email')
      then $user-profile/tei:email
      else if ($property = 'orgname')
      then $user-profile/tei:orgName
      else
        api:error(404, 'Unknown property', $property)
    else (: $user-profile contains the error message :)
      $user-profile
};

(:
 : set a property in the profile
 :)
declare function local:put-property(
  $user-name as xs:string,
  $property as xs:string,
  $format as xs:string
  ) as element()? {
  let $reference := local:get-reference($user-name, $property)
  return
    if ($reference instance of element(error))
    then $reference
    else
      let $data := api:get-data()
      let $value := 
        typeswitch ($data)
        case xs:string return text { $data }
        default return $data
      let $new-value := 
        if ($property = 'name' and empty($value/element()))
        then
          (: name has to be converted :)
          element tei:name {
            $value/@*,
            name:string-to-name(string($value))
          }
        else
          (: take the value as-is :)
          $value
      return (
        debug:debug($debug:detail,
          "/api/user/profile",
          ('set ', $property, ' original:', $reference, ' replace:', $new-value, " format:", $format)
        ),
        if (not($new-value instance of element()) and not($property = 'name'))
        then 
          update value $reference with $new-value
        else 
          update replace $reference with $new-value,
        response:set-status-code(204)
      )
};

(:~ return the current value of a property or format a given new value
 : in the format requested by format parameter
 :)
declare function local:get-property(
  $user-name as xs:string,
  $property as xs:string,
  $format as xs:string, 
  $value as item()?
  ) as item()? {
  let $reference := ($value, local:get-reference($user-name, $property))[1]
  return 
    (: return the property :)
    if ($reference instance of element(error))
    then $reference
    else if ($format = ('txt','xhtml'))
    then 
      if ($property = 'name')
      then
        name:name-to-string($reference) 
      else
        string($reference) 
    else
      $reference
};

declare function local:get-property(
  $user-name as xs:string,
  $property as xs:string,
  $format as xs:string 
  ) as item()? {
  local:get-property($user-name, $property, $format, ())
};

declare function local:delete-property(
  $user-name as xs:string,
  $property as xs:string
  ) as item()? {
  let $reference := local:get-reference($user-name, $property)
  return
    if ($reference instance of element(error))
    then $reference
    else (
      update delete $reference/node(),
      response:set-status-code(204)
    )
};

(: check if the property exists, if not, set error code 404 
 : the caller has to provide an error message
 :)
declare function local:has-property(
  $property as xs:string
  ) as xs:boolean {
  let $valid-properties := ('name', 'orgname', 'email')
  return 
    if (not($property) or $property = $valid-properties)
    then true()
    else ( 
      response:set-status-code(404),
      false()
    )
};

declare function prof:title(
  $uri as xs:anyAtomicType
  ) as xs:string {
  let $property := local:property-name($uri)
  let $property-map := 
    <properties>
      <property name="name" map="Name"/>
      <property name="orgname" map="Organization name"/>
      <property name="email" map="Email address"/>
    </properties>
  return
    ($property-map/*[@name=$property]/@map/string(), local:user-name($uri))[1]
};

declare function prof:allowed-methods(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  let $property := local:property-name($uri)
  return
    if ($property)
    then $prof:allowed-methods
    else ("GET", "PUT")
};

declare function prof:accept-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  let $property := local:property-name($uri)
  return
    if ($property)
    then $prof:accept-content-type
    else api:html-content-type()
};

declare function prof:request-content-type(
  $uri as xs:anyAtomicType
  ) as xs:string* {
  let $property := local:property-name($uri)
  return
    if ($property)
    then $prof:request-content-type
    else ()
};

declare function prof:list-entry(
  $uri as xs:anyAtomicType
  ) as element(li) {
  api:list-item(
    element span {prof:title($uri)},
    $uri,
    prof:allowed-methods($uri),
    prof:accept-content-type($uri),
    prof:request-content-type($uri),
    ()
  )
};

declare function local:disallowed() {
  api:allowed-method(prof:allowed-methods(request:get-uri())),
  api:error((), "Method not allowed")
};

(: determine authorization. If not authorized, return an error element. :)
declare function local:unauthorized(
  ) as element()? {
  let $user-name := local:user-name()
  let $property := local:property-name()
  return
    if (api:require-authentication-as($user-name, true()))
    then 
      if (local:has-property($property))
      then ()
      else 
        api:error(404, concat('The property ', $property, ' is not found.'))
    else 
      if (xmldb:exists-user($user-name))
      then
        (: not authenticated correctly. let require-authentication-as() set the error code :)
        api:error((), concat('You must be authenticated as ', $user-name, ' to access ', request:get-uri()))
      else 
        api:error(404, "The user does not exist.", $user-name)
};

declare function local:get-menu(
  ) {
  let $user-name := local:user-name()
  let $base := concat('/code/api/user/', $user-name)
  let $list-body := 
    <ul class="common">
      {
      prof:list-entry(concat($base, '/name')),
      prof:list-entry(concat($base, '/orgname')),
      prof:list-entry(concat($base, '/email'))
      }
    </ul>
  return
    api:list(
      <title>{prof:title($base)}</title>,
      $list-body,
      0, 
      false(),
      prof:allowed-methods($base),
      prof:accept-content-type($base),
      prof:request-content-type($base), 
      $prof:test-source
    )
};


declare function prof:get() {
  let $test-result := api:tests($prof:test-source)
  let $accepted := api:get-accept-format($prof:accept-content-type)
  let $uri := request:get-uri()
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($test-result)
    then $test-result
    else 
      let $logged-in := app:auth-user()
      let $user-name := local:user-name()
      let $property := local:property-name()
      let $format := local:format()
      return
        if (not($property))
        then 
          if (xmldb:exists-user($user-name)) 
          then 
            if ($logged-in=$user-name or not($logged-in))
            then local:get-menu()
            else api:error(403, concat("Only ", app:auth-user(), " can access his own profile"))
          else api:error(404, "User name not found", $user-name)
        else
          let $unauthorized := local:unauthorized()
          return
            if ($unauthorized)
            then $unauthorized
            else 
              let $prop := local:get-property($user-name, $property, $format)
              return
                if ($format = ("txt", "tei", "xml") or $prop instance of element(error))
                then $prop
                else if ($format = "xhtml")
                then
                  let $list-body := (
                    <ul class="common">
                      <li>{$prop}</li>
                    </ul>
                  )
                  return
                    api:list(
                      <title>{prof:title($uri)}</title>,
                      $list-body,
                      count($list-body/self::ul[@class="results"]/li),
                      false(),
                      prof:allowed-methods($uri),
                      prof:accept-content-type($uri),
                      prof:request-content-type($uri),
                      $prof:test-source
                    )
                else error(xs:QName("err:INTERNAL"), "This should never happen.")
};

declare function prof:put() {
  let $user-name := local:user-name()
  let $property := local:property-name()
  let $format := local:format(request:get-header("Content-Type"))
  let $unauthorized := local:unauthorized()
  return 
    if ($property)
    then
      if ($unauthorized)
      then $unauthorized
      else
          local:put-property($user-name, $property, $format)
    else
      let $password := string(api:get-parameter("password", (), true()))
      return
        (: this is either a request for a new user or a request 
         : to change a password :)
        if (xmldb:exists-user($user-name))
        then
          (: this is a request to change password :)
          if (api:require-authentication-as($user-name, true()))
          then (
            (: same user requests, so we change it :)
            xmldb:change-user($user-name, $password, (), ())
          )
          else 
            (: change password for a different user: that's an error :)
            ()
         else
          (: this is a request for a new user :)
          if (user:create($user-name, $password))
          then (
            (: user created :)
            app:login-credentials($user-name, $password),
            response:set-status-code(201)
          )
          else (
            (: error :)
            api:error(500, concat('Could not create the user ', $user-name, '.'))
          )
};

declare function prof:post() {
  local:disallowed()
};

declare function prof:delete() {
  let $unauthorized := local:unauthorized()
  let $user-name := local:user-name()
  let $property := local:property-name()
  return
    if ($unauthorized)
    then $unauthorized
    else local:delete-property($user-name,$property)
};

declare function prof:go() {
  let $method := api:get-method()
  return
    if (not($method=prof:allowed-methods(request:get-uri())))
    then local:disallowed()
    else if ($method = "GET")
    then prof:get()
    else if ($method = "PUT") 
    then prof:put()
    else if ($method = "POST")
    then prof:post()
    else if ($method = "DELETE")
    then prof:delete()
    else local:disallowed()
};

