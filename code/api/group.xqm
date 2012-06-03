xquery version "3.0";
(:~ Group management API
 :
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later 
 :)
module namespace grp = 'http://jewishliturgy.org/api/group';

import module namespace api="http://jewishliturgy.org/modules/api"
  at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "/code/modules/app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "/code/modules/debug.xqm";
import module namespace jvalidate="http://jewishliturgy.org/modules/jvalidate"
  at "/code/modules/jvalidate.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "/code/magic/magic.xqm";
  
declare namespace g="http://jewishliturgy.org/ns/group/1.0";
declare namespace rest="http://exquery.org/ns/rest/annotation/";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace error="http://jewishliturgy.org/errors";

declare variable $grp:path := "/group";

(:~ List all groups or query existing groups 
 :)
declare 
  %rest:GET
  %rest:path("/group")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/html", "text/xml")
  %output:method("html5")
  function grp:list(
    $start as xs:integer,
    $max-results as xs:integer
  ) as item()+ {
  let $all := 
    (: for some reason, eXist considers group existence to be a secret.
     : I think it should be public.
     :)
    system:as-user("admin", $magic:password, sm:get-groups())
  let $total := count($all)
  return 
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head profile="http://a9.com/-/spec/opensearch/1.1/">
        <title>Group API index</title>
        <meta name="startIndex" content="{if ($total eq 0) then 0 else $start}"/>
        <meta name="endIndex" content="{min(($start + $max-results - 1, $total))}"/>
        <meta name="itemsPerPage" content="{$max-results}"/>
        <meta name="totalResults" content="{$total}"/>
      </head>
      <body>
        <ul class="results">{
          for $group in subsequence($all, $start, $max-results) 
          let $api-name := encode-for-uri($group)
          return
            <li class="result">
              <a class="document" href="/api{$grp:path}/{$api-name}">{
                $group
              }</a>
            </li>
        }</ul>
      </body>
    </html>
};

(:~ list members of a group, in XML 
 : @return XML conforming to schema/group.rnc
 : If the group does not exist or is inaccessible, return 404
 : If not logged in, return 401
 :)
declare 
  %rest:GET
  %rest:path("/group/{$name}")
  %rest:produces("application/xml", "text/xml")
  function grp:get-xml(
    $name as xs:string
  ) as item()+ {
  if (app:auth-user())
  then
    if (sm:get-groups() = $name)
    then
      let $members := sm:get-group-members($name)
      let $managers := sm:get-group-managers($name)
      return
        <g:group>{
          for $member in $members
          order by $member ascending
          return
            <g:member>{
              if ($member=$managers)
              then attribute manager { true() }
              else (), 
              $member
            }</g:member>
        }</g:group>
    else api:rest-error(404, "Not found")
  else api:rest-error(401, "Not authenticated")
};

(:~ list members of a group, in HTML
 : @return an HTML list of group members
 : If not logged in, return 401
 : If the group does not exist or is inaccessible, return 404
 :)
declare 
  %rest:GET
  %rest:path("/group/{$name}")
  %rest:produces("application/xhtml+xml", "text/html")
  function grp:get-html(
    $name as xs:string
  ) as item()+ {
  let $group := grp:get-xml($name)
  return
    if ($group[2] instance of element(error))
    then $group
    else 
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <title>{$name}</title>
        </head>
        <body>
          <ul class="results">{
            for $member in $group/g:member
            return
              <li class="result">
                <a class="document" href="/api/user/{encode-for-uri($member)}">{
                  if (xs:boolean($member/@manager))
                  then attribute property { "manager" }
                  else (),
                  $member
                }</a>
              </li>
          }</ul>
        </body>
      </html>
};

(:~ return the group memberships of a given user.
 : 401 if not logged in
 : 404 if the user does not exist
 :)
declare 
  %rest:GET
  %rest:path("/user/{$user}/groups")
  %rest:produces("application/xhtml+xml", "application/xml", "text/html", "text/xml")
  function grp:get-user-groups(
    $user as xs:string
  ) as item()+ {
  if (app:auth-user())
  then 
    if (xmldb:exists-user($user))
    then 
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <title>{$user}</title>
        </head>
        <body>
          <ul class="results">{
            (: TODO: this code is here because eXist r16512 returns deleted groups
             : until db restart
             :)
            let $all-groups := sm:get-groups()
            for $group in distinct-values(xmldb:get-user-groups($user))[.=$all-groups]
            order by $group
            return
              <li class="result">
                <a class="document" href="/api/group/{encode-for-uri($group)}">{
                  if (sm:get-group-managers($group) = $user)
                  then attribute property { "manager" }
                  else (),
                  $group
                }</a>
              </li>
          }</ul>
        </body>
      </html>
    else api:rest-error(404, "Not found")
  else api:rest-error(401, "Not authorized")
};

declare function grp:validate(
  $doc as document-node(),
  $group-name as xs:string?
  ) as xs:boolean {
  jvalidate:validation-boolean(
    grp:validate-report($doc, $group-name)
  )
};

declare function local:validate-existing-group(
  $doc as document-node(),
  $group-name as xs:string
  ) as element(message)* {
  ((: if there were any special validation for an 
    : existing group, it would go here:))
};

(:~ validate a group XML structure as the group with the
 : given $group-name. If the $group-name is empty, assume it
 : is for a new group. 
 :)
declare function grp:validate-report(
  $doc as document-node(),
  $group-name as xs:string?
  ) as element(report) {
  jvalidate:concatenate-reports((
    jvalidate:validate-relaxng($doc, xs:anyURI("/schema/group.rnc")),
    let $invalid-users := $doc//g:member/string()[not(xmldb:exists-user(.))]
    let $existing-group-validation :=
      if ($group-name)
      then
        local:validate-existing-group($doc, $group-name)
      else ()
    return
    <report>
      <status>{
        if (empty(($invalid-users, $existing-group-validation)))
        then "valid"
        else "invalid"
      }</status>
      {
        for $user in $invalid-users
        return
          <message>User {$user} does not exist.</message>,
        $existing-group-validation
      }
    </report>
  ))
};

(:~ create a group or change membership of a group
 : @return
 :  201 successful, new group created 
 :  204 successful, group edited
 :  400 if the input is invalid
 :  401 if not logged in
 :  403 if not a group manager
 :
 : Notes: 
 :  When a group is created, the creating user is a manager, independent of the 
 :  admin cannot be removed as a 
 :)
declare
  %rest:PUT("{$body}")
  %rest:path("/group/{$name}")
  %rest:consumes("application/xml", "text/xml")
  function grp:put(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  let $user := app:auth-user()
  return
    if ($user)
    then
      let $group-exists := sm:get-groups()=$name
      return
        if (grp:validate($body, $name[$group-exists]))
        then
          if ($group-exists)
          then
            (: group exists, this is an edit :)
            let $old-managers := sm:get-group-managers($name)
            return
              if ($old-managers=$user)
              then
                let $all-new-members := $body//g:member
                let $all-new-managers := $body//g:member[xs:boolean(@manager)]
                let $old-members := sm:get-group-members($name)
                let $members-to-add := $all-new-members[not(.=$old-members)]
                let $members-to-remove := $old-members[not(.=$all-new-members)][not(.="admin")]
                let $managers-to-add := $all-new-managers[not(.=$old-managers)]
                let $managers-to-remove := $old-managers[not(.=$all-new-managers)][not(.="admin")]
                let $errors := (
                  for $member in distinct-values(($members-to-add, $managers-to-add))
                  let $added := xmldb:add-user-to-group($member, $name)
                  where not($added)
                  return $member,
                  for $member in $members-to-remove
                  let $removed := xmldb:remove-user-from-group($member, $name)
                  where not($removed)
                  return $member
                )
                let $warnings :=
                  let $managers-to-change := ($managers-to-add, $managers-to-remove)
                  where exists($managers-to-change)
                  return
                    debug:debug(
                      $debug:warn,
                      "group",
                      ("Managerial status cannot be changed for: ",
                      string-join($managers-to-change, " ")
                      )
                    )
                return
                  if (exists($errors))
                  then
                    api:rest-error(500, "Could not change group status of:",
                      string-join($errors, " ")
                    )
                  else
                    <rest:response>
                      <output:serialization-parameters>
                        <output:method value="text"/>
                      </output:serialization-parameters>
                      <http:response status="204"/>
                    </rest:response>
              else
                (: not a group manager of an existing group :)
                api:rest-error(403, "Forbidden")
          else
            (: group does not exist, this is group creation :)
            let $members := distinct-values($body//g:member[not(xs:boolean(@manager))])
            let $managers := distinct-values(($body//g:member[xs:boolean(@manager)], "admin", $user))
            let $created :=
              system:as-user("admin", $magic:password, 
                xmldb:create-group($name, $managers)
              )
            return
              if ($created)
              then 
                let $errors :=
                  for $member in $members
                  let $added := xmldb:add-user-to-group($member, $name)
                  where not($added)
                  return $member
                return 
                  if (exists($errors))
                  then
                    api:rest-error(500, 
                      "Could not add users to group", 
                      string-join($errors, " ")
                    )
                  else 
                    <rest:response>
                      <output:serialization-parameters>
                        <output:method value="text"/>
                      </output:serialization-parameters>
                      <http:response status="201">
                        <http:header name="Location" value="/api/group/{$name}"/>
                      </http:response>
                    </rest:response>
              else api:rest-error(500, "Could not create group " || $name)
        else api:rest-error(400, "Validation error", grp:validate-report($body, $name[$group-exists]))
    else api:rest-error(401, "Not authorized")
};

(:~ delete a group
 : @return
 :  204 if successful
 :  401 if not logged in
 :  403 if not a group manager
 :  404 if the group does not exist 
 :)
declare
  %rest:DELETE
  %rest:path("/group/{$name}")
  function grp:delete(
    $name as xs:string
  ) as item()+ {
  let $user := app:auth-user()
  return
    if ($user)
    then
      if (sm:get-groups()=$name)
      then
        if (sm:get-group-managers($name)=$user)
        then
          <rest:response>
            <output:serialization-parameters>
              <output:method value="text"/>
            </output:serialization-parameters>
            {
              (: members are not removed automatically from a deleted group :)
              let $all-group-members := sm:get-group-members($name)
              return system:as-user("admin", $magic:password, ( 
                for $member in $all-group-members
                let $removed := xmldb:remove-user-from-group($member, $name)
                where not($removed)
                return debug:debug($debug:warn, "group", 
                  ("Could not remove ", $member, " from ", $name)),
                sm:delete-group($name)
              ))
            }
            <http:response status="204"/>
          </rest:response>
        else api:rest-error(403, "Forbidden")
      else api:rest-error(404, "Not found")
    else api:rest-error(401, "Not authorized")
};
