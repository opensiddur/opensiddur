xquery version "3.0";
(:~ User management API
 :
 : Copyright 2012-2013 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later 
 :)
module namespace user="http://jewishliturgy.org/api/user";

import module namespace api="http://jewishliturgy.org/modules/api"
  at "/db/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "/db/code/modules/app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "/db/code/modules/debug.xqm";
import module namespace jvalidate="http://jewishliturgy.org/modules/jvalidate"
  at "/db/code/modules/jvalidate.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "/db/code/magic/magic.xqm";
import module namespace name="http://jewishliturgy.org/modules/name"
  at "/db/code/modules/name.xqm";
import module namespace kwic="http://exist-db.org/xquery/kwic";
  
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace error="http://jewishliturgy.org/errors";

(: path to user profile data :)
declare variable $user:path := "/db/user";
declare variable $user:api-path := "/api/user";
(: path to schema :)
declare variable $user:schema := "/db/schema/contributor.rnc";

declare 
  %private 
  function user:result-title(
  $result as element(j:contributor)
  ) as xs:string {
  if (exists($result/tei:name))
  then name:name-to-string($result/tei:name)
  else $result/(tei:orgName, tei:idno)[1]/string()
};

(: @return (list, start, count, n-results) :) 
declare 
  %private 
  function user:do-query(
    $query as xs:string,
    $start as xs:integer,
    $count as xs:integer
  ) as item()+ {
  let $all-results := 
      collection($user:path)/j:contributor[ft:query(.,$query)]
  let $list-of-results :=
    for $result in  
      subsequence($all-results, $start, $count)
    group by $document := document-uri(root($result))
    order by max(for $r in $result return ft:score($r))
    return
      let $api-name := replace(util:document-name(doc($document)), "\.xml$", "")
      return
      <li xmlns="http://www.w3.org/1999/xhtml" class="result">
        <a class="document" href="{$user:api-path}/{$api-name}">{
        user:result-title(doc($document)/j:contributor)
        }</a>:
        <ol class="contexts">{
          for $h in $result
          order by ft:score($h) descending
          return
            <li class="context">{
              kwic:summarize($h, <config xmlns="" width="40" />)
            }</li>
        }</ol>
      </li>
  let $listed-results := 
    <ol xmlns="http://www.w3.org/1999/xhtml" class="results">{
      $list-of-results
    }</ol>
  return (
    $listed-results,
    $start,
    $count, 
    count($all-results)
  )
};

declare
  %private 
  function user:do-list(
  $start as xs:integer,
  $count as xs:integer
  ) {
  let $all := collection($user:path)/j:contributor
  return (
    <ul xmlns="http://www.w3.org/1999/xhtml" class="results">{
      for $user in subsequence($all, $start, $count) 
      let $api-name := replace(util:document-name($user), "\.xml$", "")
      return
        <li class="result">
          <a class="document" href="{$user:api-path}/{$api-name}">{
            user:result-title($user)
          }</a>
          <a class="alt" property="groups" href="{$user:api-path}/{$api-name}/groups">groups</a>
        </li>
    }</ul>,
    $start,
    $count,
    count($all)
  )
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
  %output:method("html5")
  function user:list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
    ) as item()+ {
  <rest:response>
    <output:serialization-parameters>
      <output:method value="html5"/>
    </output:serialization-parameters>
  </rest:response>,
  let $query := string-join($q[.], " ")
  let $start := $start[1]
  let $max-results := $max-results[1]
  let $results as item()+ := 
    if ($query) 
    then user:do-query($query, $start, $max-results)
    else user:do-list($start, $max-results)
  let $result-element := $results[1]
  let $start := $results[2] 
  let $count := $results[3]
  let $total := $results[4]
  return
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head>
        <title>User and contributor API</title>
        <link rel="search"
               type="application/opensearchdescription+xml" 
               href="/api/data/OpenSearchDescription?source={encode-for-uri($user:api-path)}"
               title="Full text search" />
        <meta name="startIndex" content="{if ($total eq 0) then 0 else $start}"/>
        {((:<meta name="endIndex" content="{min(($start + $max-results - 1, $total))}"/>:))}
        <meta name="itemsPerPage" content="{$max-results}"/>
        <meta name="totalResults" content="{$total}"/>
      </head>
      <body>{
        $result-element
      }</body>
    </html>

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
  let $resource := concat($user:path, "/", encode-for-uri($name), ".xml")
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
  function user:post-form(
    $user as xs:string*,
    $password as xs:string*
  ) as item()+ {
  let $name := $user[1]
  let $password := $password[1] 
  return
    if (not($name) or not($password))
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
              <output:method value="text"/>
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
                  concat(encode-for-uri($name), ".xml"),
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
                      <output:method value="text"/>
                    </output:serialization-parameters>
                    {
                      sm:chmod($uri, "rw-r--r--"),
                      sm:chown($uri, $name),
                      sm:chgrp($uri, $name)
                    }
                    <http:response status="201">
                      <http:header name="Location" value="/api/user/{encode-for-uri($name)}"/>
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

(:~ Edit or create a user or contributor profile
 : @param $name The name to place the profile under
 : @param $body The user profile, which must validate against /schema/contributor.rnc
 : @return 
 :  201 (created): A new contributor profile, which is not associated with a user, has been created
 :  204 (no data): The profile was successfully edited 
 :  400 (bad request): The profile is invalid
 :  401 (not authorized): You are not authenticated, 
 :  403 (forbidden): You are authenticated as a different user
 :)
declare
  %rest:PUT("{$body}")
  %rest:path("/api/user/{$name}")
  %rest:consumes("application/tei+xml", "application/xml", "text/xml")
  function user:put(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  let $user := app:auth-user()
  let $resource := concat($user:path, "/", encode-for-uri($name), ".xml")
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
        if (xmldb:store($user:path, $resource, $body))
        then (
          system:as-user("admin", $magic:password, (
            sm:chown(xs:anyURI($resource), $user),
            sm:chgrp(xs:anyURI($resource), if ($is-non-user-profile) then "everyone" else $user),
            sm:chmod(xs:anyURI($resource), if ($is-non-user-profile) then "rw-rw-r--" else "rw-r--r--")
          )),
          <rest:response>
            <output:serialization-parameters>
              <output:method value="text"/>
            </output:serialization-parameters>
            {
              if ($resource-exists)
              then <http:response status="204"/>
              else 
                <http:response status="201">
                  <http:header name="Location" value="/api/user/{encode-for-uri($name)}"/>
                </http:response>
            }
          </rest:response>
        )
        else api:rest-error(500, "Internal error: cannot store the profile")
      else api:rest-error(400, "Invalid", user:validate-report($body, $name))
    else api:rest-error(403, "Forbidden") 
};

(:~ Delete a contributor or contributor profile
 : @param $name Profile to remove
 : @return 
 :  204 (no data): The profile was successfully deleted 
 :  400 (bad request): The profile is referenced elsewhere and cannot be deleted. A list of references is returned
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
  let $resource-name := concat(encode-for-uri($name), ".xml")
  let $resource := concat($user:path, "/", $resource-name)
  let $resource-exists := doc-available($resource)
  let $is-non-user-profile := 
    not($user = $name) and 
    ($resource-exists and sm:has-access(xs:anyURI($resource), "w"))
  let $return-success :=
    <rest:response>
      <output:serialization-parameters>
        <output:method value="text"/>
      </output:serialization-parameters>
      <http:response status="204"/>
    </rest:response>
  return 
    if (not($resource-exists))
    then api:rest-error(404, "Not found")
    else if (not($user))
    then api:rest-error(401, "Unauthorized")
    else if ($user = $name)
    then (
      (: TODO: check for references!!! :)
      xmldb:remove($user:path, $resource-name),
      system:as-user("admin", $magic:password, (
        try {
          for $member in sm:get-group-members($name)
          return sm:remove-group-member($name, $member),
          for $manager in sm:get-group-managers($name)
          return sm:remove-group-manager($name, $manager),
          sm:remove-account($name),
          sm:remove-group($name), (: TODO: successor group is guest! until remove-group#2 exists@ :)
          $return-success
        }
        catch * {
          api:rest-error(500, "Internal error: Cannot delete the user or group!", 
            debug:print-exception("user", 
              $err:line-number, $err:column-number,
              $err:code, $err:value, $err:description))
        }
      ))
    )
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
