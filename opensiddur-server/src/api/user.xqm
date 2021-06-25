xquery version "3.1";
(:~ User management API
 :
 : Copyright 2012-2014 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later 
 :)
module namespace user="http://jewishliturgy.org/api/user";

import module namespace acc="http://jewishliturgy.org/modules/access"
  at "../modules/access.xqm";
import module namespace api="http://jewishliturgy.org/modules/api"
  at "../modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "../modules/app.xqm";
import module namespace crest="http://jewishliturgy.org/modules/common-rest"
  at "../modules/common-rest.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "../modules/data.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "../modules/debug.xqm";
import module namespace didx="http://jewishliturgy.org/modules/docindex"
  at "../modules/docindex.xqm";
import module namespace jvalidate="http://jewishliturgy.org/modules/jvalidate"
  at "../modules/jvalidate.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "../magic/magic.xqm";
import module namespace name="http://jewishliturgy.org/modules/name"
  at "../modules/name.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "../modules/paths.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "../modules/refindex.xqm";
import module namespace kwic="http://exist-db.org/xquery/kwic";
  
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace error="http://jewishliturgy.org/errors";
declare namespace http="http://expath.org/ns/http-client";

(: path to user profile data :)
declare variable $user:path := "/db/data/user";
declare variable $user:api-path := "/api/user";
declare variable $user:data-type := "user";
(: path to schema :)
declare variable $user:schema := concat($paths:schema-base, "/contributor.rnc");

declare function user:result-title(
    $result as node()
    ) as xs:string {
    let $c := root($result)/j:contributor
    return
        if (exists($c/tei:name))
        then name:name-to-string($c/tei:name)
        else ($c/tei:orgName, $c/tei:idno)[1]/string()
};

declare function user:query-function(
    $query as xs:string
    ) as element()* {
    for $doc in collection($user:path)/j:contributor[ft:query(.,$query)]
    order by user:result-title($doc) ascending
    return $doc
};

declare function user:list-function(
    ) as element()* {
    for $doc in collection($user:path)/j:contributor
    order by user:result-title($doc) ascending
    return $doc
};

(:~ List or query users and contributors
 : @param $q text of the query, empty string for all
 : @param $start first user to list
 : @param $max-results number of users to list 
 : @return a list of users whose full names or user names match the query 
 :)
declare 
  %rest:GET
  %rest:path("/api/user")
  %rest:query-param("q", "{$q}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("xhtml")
  function user:list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
    ) as item()+ {
    crest:list($q, $start, $max-results,
        "User and contributor API", api:uri-of($user:api-path),
        user:query-function#1, user:list-function#0,
        (
            <crest:additional text="access" relative-uri="access"/>,
            <crest:additional text="groups" relative-uri="groups"/>,
            $crest:additional-validate
        ),
        user:result-title#1
    )
};

(:~ Get a user profile
 : @param $name Name of user to profile
 : @return The profile, if available. Otherwise, return error 404 (not found) 
 :)
declare
  %rest:GET
  %rest:path("/api/user/{$name}")
  %rest:produces("application/xml", "application/tei+xml", "text/xml")
  %output:method("xml")
  function user:get(
    $name as xs:string
  ) as item()+ {
  let $resource := concat($user:path, "/", $name, ".xml")
  return
    if (doc-available($resource))
    then doc($resource)
    else api:rest-error(404, "Not found")
};

(:~ Create a new user or edit a user's password, using XML
 : @param $body The user XML, <new><user>{name}</user><password>{}</password></new>
 : @return  if available. Otherwise, return errors
 :  201 (created): A new user was created, a location link points to the profile
 :  400 (bad request): User or password missing  
 :  401 (not authorized): Attempt to change a password for a user and you are not authenticated, 
 :  403 (forbidden): Attempt to change a password for a user and you are authenticated as a different user 
 :)
declare 
  %rest:POST("{$body}")
  %rest:path("/api/user")
  %rest:consumes("application/xml", "text/xml")
  function user:post-xml(
    $body as document-node()
  ) as item()+ {
  user:post-form($body//user, $body//password)
};

(:~ Create a new user or edit a user's password, using a web form
 : @param $user The user's name
 : @param $password The user's new password
 : @return  if available. Otherwise, return errors
 :  201 (created): A new user was created, a location link points to the profile 
 :  400 (bad request): User or password missing
 :  401 (not authorized): Attempt to change a password for a user and you are not authenticated, 
 :  403 (forbidden): Attempt to change a password for a user and you are authenticated as a different user 
 :)
declare 
  %rest:POST
  %rest:path("/api/user")
  %rest:form-param("user", "{$user}")
  %rest:form-param("password", "{$password}")
  %rest:consumes("application/x-www-form-urlencoded")
  function user:post-form(
    $user as xs:string*,
    $password as xs:string*
  ) as item()+ {
  let $name := xmldb:decode($user[1] || "")
  let $normalized-name := data:normalize-resource-title($name, true())
  let $password := $password[1] 
  return
    if (not($name = $normalized-name))
    then api:rest-error(400, "User names must contain only alphanumeric characters, nonrepeated dashes and underscores. They must begin with a letter. They may not end with an underscore or dash.")
    else if (not($name) or not($password))
    then api:rest-error(400, "Missing user or password")
    else
      let $user := app:auth-user()
      return
        if ($user = $name)
        then
          (: logged in as the user of the request.
           : this is a change password request
           :) 
          <rest:response>
            <output:serialization-parameters>
              <output:method>text</output:method>
            </output:serialization-parameters>
            {
            system:as-user("admin", $magic:password, 
              sm:passwd($name, $password)
            )
            }
            <http:response status="204"/>
          </rest:response>
        else if (not($user))
        then
          (: not authenticated, this is a new user request :)
          if (system:as-user("admin", $magic:password, sm:user-exists($name)))
          then 
            (: user already exists, need to be authenticated to change the password :)
            api:rest-error(401, "Not authorized")
          else if (collection($user:path)//tei:idno=$name)
          then 
            (: profile already exists, but is not a user. No authorization will help :)
            api:rest-error(403, "Forbidden")
          else ( 
            (: the user can be created :)
            system:as-user("admin", $magic:password, (
              let $null := sm:create-account($name, $password, "everyone")
              let $stored := 
                xmldb:store($user:path, 
                  concat($normalized-name, ".xml"),
                  <j:contributor>
                    <tei:idno>{$name}</tei:idno>
                  </j:contributor>
                )
              let $uri := xs:anyURI($stored)
              return
                if ($stored)
                then 
                  <rest:response>
                    <output:serialization-parameters>
                      <output:method>text</output:method>
                    </output:serialization-parameters>
                    {
                      sm:chmod($uri, "rw-r--r--"),
                      sm:chown($uri, $name),
                      sm:chgrp($uri, $name),
                      didx:reindex(doc($stored))
                    }
                    <http:response status="201">
                      <http:header name="Location" value="{api:uri-of('/api/user')}/{$name}"/>
                    </http:response>
                  </rest:response>
                else 
                  api:rest-error(500, "Internal error in storing a document",
                    (" storage = " || $stored) 
                  )
            ))
          )
        else 
          (: authenticated as a user who is not the one we're changing :)
          api:rest-error(403, "Attempt to change the password of a different user")
}; 

declare function user:validate(
  $doc as document-node(),
  $name as xs:string
  ) as xs:boolean {
  jvalidate:validation-boolean(
    user:validate-report($doc, $name)
  )
};

declare function user:validate-report(
  $doc as document-node(),
  $name as xs:string
  ) as element(report) {
  jvalidate:concatenate-reports((
    jvalidate:validate-relaxng($doc, xs:anyURI($user:schema)),
    let $name-ok := $name = $doc//tei:idno
    return
      <report>
        <status>{
          if (not($name-ok))
          then "invalid"
          else "valid"
        }</status>
        <message>{
          if (not($name-ok))
          then "tei:idno must be the same as the profile name."
          else ()
        }</message>
      </report>
  ))
};

declare function user:put(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  user:put($name, $body, ())
};

(:~ Edit or create a user or contributor profile
 : @param $name The name to place the profile under
 : @param $body The user profile, which must validate against /schema/contributor.rnc
 : @param $validate Validate without writing to the database
 : @return
 :  200 (OK): validated successfully
 :  201 (created): A new contributor profile, which is not associated with a user, has been created
 :  204 (no data): The profile was successfully edited 
 :  400 (bad request): The profile is invalid
 :  401 (not authorized): You are not authenticated, 
 :  403 (forbidden): You are authenticated as a different user
 :)
declare
  %rest:PUT("{$body}")
  %rest:path("/api/user/{$name}")
  %rest:query-param("validate", "{$validate}")
  %rest:consumes("application/tei+xml", "application/xml", "text/xml")
  function user:put(
    $name as xs:string,
    $body as document-node(),
    $validate as xs:string*
  ) as item()+ {
  let $is-validate := boolean($validate[1])
  let $name := xmldb:decode($name)
  let $user := app:auth-user()
  let $resource-name := $name || ".xml"
  let $resource := concat($user:path, "/", $resource-name)
  let $resource-exists := doc-available($resource)
  let $is-non-user-profile := 
    not($user = $name) and 
    ($resource-exists and sm:has-access(xs:anyURI($resource), "w")) or
    not($resource-exists)
  return 
    if (not($user))
    then api:rest-error(401, "Unauthorized")
    else if ($user = $name or $is-non-user-profile)
    then
      (: user editing his own profile, or a non-user profile :)
      if (user:validate($body, $name))
      then
        (: the profile is valid :)
        if ($is-validate)
        then
            crest:validation-success()
        else
            if (xmldb:store($user:path, $resource-name, $body))
            then (
              system:as-user("admin", $magic:password, (
                sm:chown(xs:anyURI($resource), $user),
                sm:chgrp(xs:anyURI($resource), if ($is-non-user-profile) then "everyone" else $user),
                sm:chmod(xs:anyURI($resource), if ($is-non-user-profile) then "rw-rw-r--" else "rw-r--r--")
              )),
              didx:reindex($user:path, $resource-name),
              <rest:response>
                <output:serialization-parameters>
                  <output:method>text</output:method>
                </output:serialization-parameters>
                {
                  if ($resource-exists)
                  then <http:response status="204"/>
                  else
                    <http:response status="201">
                      <http:header name="Location" value="{api:uri-of('/api/user')}/{$name}"/>
                    </http:response>
                }
              </rest:response>
            )
            else api:rest-error(500, "Internal error: cannot store the profile")
      else (: invalid :)
        let $report := user:validate-report($body, $name)
        return
            if ($is-validate)
            then $report
            else api:rest-error(400, "Invalid", $report)
    else api:rest-error(403, "Forbidden") 
};

(:~ Delete a contributor or contributor profile
 : @param $name Profile to remove
 : @return 
 :  200 (OK): The profile is referenced elsewhere. All the information in it was deleted. A list of referencing documents is returned.
 :  204 (no data): The profile was successfully deleted 
 :  401 (not authorized): You are not authenticated 
 :  403 (forbidden): You are authenticated as a different user
 :)
declare
  %rest:DELETE
  %rest:path("/api/user/{$name}")
  function user:delete(
    $name as xs:string
  ) as item()+ {
  let $user := app:auth-user()
  let $resource-name := concat($name, ".xml")
  let $resource := concat($user:path, "/", $resource-name)
  let $resource-exists := doc-available($resource)
  let $is-non-user-profile := 
    not($user = $name) and 
    ($resource-exists and sm:has-access(xs:anyURI($resource), "w"))
  let $return-success :=
    <rest:response>
      <output:serialization-parameters>
        <output:method>text</output:method>
      </output:serialization-parameters>
      <http:response status="204"/>
    </rest:response>
  return 
    if (not($resource-exists))
    then api:rest-error(404, "Not found")
    else if (not($user))
    then api:rest-error(401, "Unauthorized")
    else if ($user = $name)
    then 
      let $user-doc := doc($resource)
      let $user-references := ridx:query-document($user-doc)[not(root(.) is doc)]
      let $removal-return := 
        if (empty($user-references))
        then 
            let $null := xmldb:remove($user:path, $resource-name)
            return $return-success
        else 
            (: the user is referenced externally.
               the profile should be replaced with a basic deleted user profile 
             :)
            let $store := xmldb:store($user:path, $resource-name, 
                <j:contributor>{
                    $user-doc/j:contributor/tei:idno,
                    <tei:name>Deleted user</tei:name>
                }</j:contributor>
            )
            let $chown := system:as-user("admin", $magic:password, (
                sm:chown(xs:anyURI($resource), "admin"),
                sm:chgrp(xs:anyURI($resource), "everyone"),
                sm:chmod(xs:anyURI($resource), "rw-rw-r--")
            ))
            return 
                api:rest-error(200, "The user account was removed, but external references prevented the user profile from being removed. It has been replaced by the profile of a deleted user, and will continue to exist as an empty third-party profile.", 
                    <documents>{
                        for $udoc in $user-references
                        group by $uuri := document-uri(root($udoc))
                        return <document>{data:db-path-to-api($uuri)}</document>
                    }</documents>)
      return
        system:as-user("admin", $magic:password, (
          try {
            for $member in sm:get-group-members($name)
            return sm:remove-group-member($name, $member),
            for $manager in sm:get-group-managers($name)
            return sm:remove-group-manager($name, $manager),
            sm:remove-account($name),
            sm:remove-group($name), (: TODO: successor group is guest! until remove-group#2 exists@ :)
            didx:remove($user:path, $resource-name),
            $removal-return
          }
          catch * {
            api:rest-error(500, "Internal error: Cannot delete the user or group!", 
              debug:print-exception("user", 
                $err:line-number, $err:column-number,
                $err:code, $err:value, $err:description))
          }
      ))
    else if ($is-non-user-profile)
    then (
      (: non-user profile -- check for references! :)
      xmldb:remove($user:path, $resource-name),
      $return-success
    )
    else 
      (: must be another user's profile :)
      api:rest-error(403, "Forbidden")
};

(:~ Get access/sharing data for a contributor profile
 : @param $name Name of contributor
 : @param $user User to get access as
 : @return HTTP 200 and an access structure (a:access) or user access (a:user-access)
 : @error HTTP 400 User does not exist
 : @error HTTP 404 Document not found or inaccessible
 :)
declare 
  %rest:GET
  %rest:path("/api/user/{$name}/access")
  %rest:query-param("user", "{$user}")
  %rest:produces("application/xml")
  function user:get-access(
    $name as xs:string,
    $user as xs:string*
  ) as item()+ {
  crest:get-access($user:data-type, $name, $user)
};

(:~ Set access/sharing data for a contributor profile
 : @param $name Name of document
 : @param $body New sharing rights, as an a:access structure 
 : @return HTTP 204 No data, access rights changed
 : @error HTTP 400 Access structure is invalid
 : @error HTTP 401 Not authorized
 : @error HTTP 403 Forbidden
 : @error HTTP 404 Document not found or inaccessible
 :)
declare 
  %rest:PUT("{$body}")
  %rest:path("/api/user/{$name}/access")
  %rest:consumes("application/xml", "text/xml")
  function user:put-access(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  crest:put-access($user:data-type, $name, $body)
};

