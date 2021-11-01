xquery version "3.1";
(:~ Group management API
 :
 : Copyright 2012-2013 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 : @author Efraim Feinstein 
 :)
module namespace grp = 'http://jewishliturgy.org/api/group';

import module namespace api="http://jewishliturgy.org/modules/api"
  at "../modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "../modules/app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "../modules/debug.xqm";
import module namespace jvalidate="http://jewishliturgy.org/modules/jvalidate"
  at "../modules/jvalidate.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "../magic/magic.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "../modules/paths.xqm";
  
declare namespace g="http://jewishliturgy.org/ns/group/1.0";
declare namespace error="http://jewishliturgy.org/errors";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace http="http://expath.org/ns/http-client";

declare variable $grp:schema := concat($paths:schema-base, "/group.rnc");

(:~ @return the group managers of a given group.
 : eXist considers this a secret, but it's public in Open Siddur
 :)
declare function grp:get-group-managers(
    $group as xs:string
  ) as xs:string* {
  system:as-user("admin", $magic:password, 
    sm:get-group-managers($group)
  )
};

(:~ @return the group memberships of a given user.
 : eXist considers this a secret, but it is public knowledge in Open Siddur
 :)
declare function grp:get-user-group-memberships(
  $user as xs:string
  ) as xs:string+ {
  system:as-user("admin", $magic:password,
    sm:get-user-groups($user)
  )
};

declare function grp:get-user-group-managerships(
  $user as xs:string
) as xs:string* {
  system:as-user("admin", $magic:password,
    sm:list-groups()[
      sm:get-group-managers(.)=$user
    ]
  )
};

(:~ @return the members of a given group
 : eXist considers group membership a secret. We do not
 :)
declare function grp:get-group-members(
    $group as xs:string
  ) as xs:string* {
  system:as-user("admin", $magic:password,
    sm:get-group-members($group)
  )
};

(:~ @return a list of groups
 : eXist considers group existence a secret. We do not
 :)
declare function grp:get-groups(
  ) as xs:string* {
  system:as-user("admin", $magic:password,
    sm:list-groups()
  )
};

(:~ List all groups
 : @param $start Begin listing at this item number
 : @param $max-results End listing after this many results
 : @return an HTML list of groups  
 :)
declare 
  %rest:GET
  %rest:path("/api/group")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)
  %rest:produces("application/xhtml+xml", "application/xml", "text/html", "text/xml")
  %output:method("xhtml")
  function grp:list(
    $start as xs:integer*,
    $max-results as xs:integer*
  ) as item()+ {
  let $start := $start[1]
  let $max-results := $max-results[1]
  let $all := 
    (: for some reason, eXist considers group existence to be a secret.
     : I think it should be public.
     :)
    grp:get-groups()
  let $total := count($all)
  return 
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head>
        <title>Group API index</title>
        <meta name="startIndex" content="{if ($total eq 0) then 0 else $start}"/>
        <meta name="itemsPerPage" content="{$max-results}"/>
        <meta name="totalResults" content="{$total}"/>
      </head>
      <body>
        <ul class="results">{
          for $group in subsequence($all, $start, $max-results) 
          let $api-name := encode-for-uri($group)
          return
            <li class="result">
              <a class="document" href="{api:uri-of('/api/group')}/{$api-name}">{
                $group
              }</a>
            </li>
        }</ul>
      </body>
    </html>
};

(:~ list members of a group, in group XML
 : @param $name Group name 
 : @return XML conforming to schema/group.rnc
 : @error HTTP 404 Not found If the group does not exist or is inaccessible
 : @error HTTP 401 Unauthorized If not logged in
 :)
declare 
  %rest:GET
  %rest:path("/api/group/{$name}")
  %rest:produces("application/xml", "text/xml")
  function grp:get-xml(
    $name as xs:string
  ) as item()+ {
  if (app:auth-user())
  then
    if (grp:get-groups() = $name)
    then
      let $members := grp:get-group-members($name)
      let $managers := grp:get-group-managers($name)
      return
        <g:group>{
          for $member in $members
          let $manager := 
            if ($member=$managers)
            then
              attribute manager {true()}
            else ()
          order by $member ascending
          return
            <g:member>{
              $manager,
              $member
            }</g:member>
        }</g:group>
    else api:rest-error(404, "Not found")
  else api:rest-error(401, "Not authenticated")
};

(:~ list members of a group, in HTML
 : @param $name The name of the group to list
 : @return an HTML list of group members
 : @error HTTP 401 Unauthorized If not logged in
 : @error HTTP 404 Not found If the group does not exist or is inaccessible
 :)
declare 
  %rest:GET
  %rest:path("/api/group/{$name}")
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
                <a class="document" href="{api:uri-of('/api/user')}/{encode-for-uri($member)}">{
                  if (xs:boolean($member/@manager))
                  then attribute property { "manager" }
                  else (),
                  $member/string()
                }</a>
              </li>
          }</ul>
        </body>
      </html>
};

(:~ List the group memberships of a given user.
 : @return An HTML list of group memberships
 : @error HTTP 401 Unauthorized if not logged in
 : @error HTTP 404 Not found If the user does not exist
 :)
declare 
  %rest:GET
  %rest:path("/api/user/{$user}/groups")
  %rest:produces("application/xhtml+xml", "application/xml", "text/html", "text/xml")
  function grp:get-user-groups(
    $user as xs:string
  ) as item()+ {
  if (app:auth-user())
  then 
    if (sm:user-exists($user))
    then 
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <title>{$user}</title>
        </head>
        <body>
          <ul class="results">{
            let $managerships := grp:get-user-group-managerships($user) 
            for $membership in grp:get-user-group-memberships($user)
            let $managership :=
              if ($managerships=$membership)
              then
                attribute property {"manager"}
              else ()
            order by $membership
            return 
              <li class="result">
                <a class="document" href="{api:uri-of('/api/group')}/{encode-for-uri($membership)}">
                  { $managership, $membership }
                </a>
              </li>
          }</ul>
        </body>
      </html>
    else api:rest-error(404, "Not found")
  else api:rest-error(401, "Not authorized")
};

(:~ validate group XML
 : @param $doc Document holding group XML 
 : @param $group-name Group name of existing group this XML is intended to describe, empty for a new group
 : @return A boolean
 :)
(: TODO: use document-node(element(g:group)) :)
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

(:~ validate a group XML structure 
 : @param $doc Group XML 
 : @param $group-name Name of existing group the XML is intending to change. If empty, assume it is for a new group.
 : @return A validation report. report/status indicates validity, report/message indicates reasons for invalidity. 
 :)
declare function grp:validate-report(
  $doc as document-node(),
  $group-name as xs:string?
  ) as element(report) {
  jvalidate:concatenate-reports((
    jvalidate:validate-relaxng($doc, xs:anyURI($grp:schema)),
    let $invalid-users := $doc//g:member/string()[not(sm:user-exists(.))]
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

(:~ Create a group or change membership of a group
 : @param $name Name of group to create or edit
 : @param $body Group XML, which describes the membership of the group
 : @return HTTP 201 successful, new group created
 : @return HTTP 204 successful, group edited
 : @error HTTP 400 if the input is invalid
 : @error HTTP 401 if not logged in
 : @error HTTP 403 if not a group manager
 :
 : Notes: 
 :  When a group is created, the creating user is a manager, independent of the XML. 
 :  admin cannot be removed as a group manager.
 :  Because of a missing feature in eXist, group management cannot be changed after creation.
 :)
declare
  %rest:PUT("{$body}")
  %rest:path("/api/group/{$name}")
  %rest:consumes("application/xml", "text/xml")
  function grp:put(
    $name as xs:string,
    $body as document-node()
  ) as item()+ {
  let $user := app:auth-user()
  return
    if ($user)
    then
      let $group-exists := grp:get-groups()=$name
      return
        if (grp:validate($body, $name[$group-exists]))
        then
          if ($group-exists)
          then
            (: group exists, this is an edit :)
            let $old-managers := grp:get-group-managers($name)
            return
              if ($old-managers=$user)
              then
                let $all-new-members := $body//g:member
                let $all-new-managers := $body//g:member[xs:boolean(@manager)]
                let $old-members := grp:get-group-members($name)
                let $members-to-add := $all-new-members[not(.=$old-members)]
                let $members-to-remove := $old-members[not(.=$all-new-members)]
                let $managers-to-add := $all-new-managers[not(.=$old-managers)]
                let $managers-to-remove := $old-managers[not(.=$all-new-managers)][not(.="admin")]
                let $errors := (
                  (: Changing group managerships/memberships is supposed to work 
                  w/o admin access (it does not). Admin access is required to
                  ensure it works as an atomic operation if a user removes
                  his own managership :)
                  for $member in $members-to-add
                  return 
                    try {
                      system:as-user("admin", $magic:password,
                        sm:add-group-member($name, $member)
                      )
                    }
                    catch * {
                      "Adding member:" || $member
                    },
                  for $manager in $managers-to-add
                  return
                    try {
                      system:as-user("admin", $magic:password,
                        sm:add-group-manager($name, $manager)
                      )
                    }
                    catch * {
                      "Adding manager: " || $manager
                    },
                  for $member in $members-to-remove
                  return 
                    try {
                      system:as-user("admin", $magic:password,
                        sm:remove-group-member($name, $member)
                      )
                    }
                    catch * {
                      "Removing member:" || $member
                    },
                  for $manager in $managers-to-remove
                  return
                    try {
                      system:as-user("admin", $magic:password,
                        sm:remove-group-manager($name, $manager)
                      )
                    }
                    catch * {
                      "Removing manager:" || $manager
                    }
                )
                return
                  if (exists($errors))
                  then
                    api:rest-error(500, "Could not change group status:",
                      string-join($errors, " ")
                    )
                  else
                    <rest:response>
                      <output:serialization-parameters>
                        <output:method>text</output:method>
                      </output:serialization-parameters>
                      <http:response status="204"/>
                    </rest:response>
              else
                (: not a group manager of an existing group :)
                api:rest-error(403, "Forbidden: " || $user || " cannot edit group because managers are " || string-join($old-managers, ","))
          else
            (: group does not exist, this is group creation :)
            let $members := distinct-values($body//g:member)
            let $managers := distinct-values(($body//g:member[xs:boolean(@manager)], "admin", $user))
            let $created :=
              try {
                system:as-user("admin", $magic:password, 
                  sm:create-group($name, $managers, string($body//g:description)) 
                ),
                true()
              }
              catch * {
                false()
              }
            return
              if ($created)
              then 
                let $errors :=
                  for $member in $members
                  return 
                    try {
                      sm:add-group-member($name, $member)
                    }
                    catch * {
                      $member
                    }
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
                        <output:method>text</output:method>
                      </output:serialization-parameters>
                      <http:response status="201">
                        {((: TODO: this is wrong! It needs to be an absolute URI :))}
                        <http:header name="Location" value="{api:uri-of('/api/group')}/{$name}"/>
                      </http:response>
                    </rest:response>
              else api:rest-error(500, "Could not create group " || $name)
        else api:rest-error(400, "Validation error", grp:validate-report($body, $name[$group-exists]))
    else api:rest-error(401, "Not authorized")
};

(:~ delete a group
 : @param $name Group to delete
 : @return HTTP 204 if successful
 : @error HTTP 401 if not logged in
 : @error HTTP 403 if not a group manager
 : @error HTTP 404 if the group does not exist
 : 
 : Notes: 
 :   Resources owned by a deleted group should become property of "everyone"
 :   For now, they become property of guest.
 :   TODO: This code has some hacks to work around eXist deficiencies 
 :)
declare
  %rest:DELETE
  %rest:path("/api/group/{$name}")
  function grp:delete(
    $name as xs:string
  ) as item()+ {
  let $user := app:auth-user()
  return
    if ($user)
    then
      if (grp:get-groups()=$name)
      then
        if (grp:get-group-managers($name)=$user)
        then
          <rest:response>
            <output:serialization-parameters>
              <output:method>text</output:method>
            </output:serialization-parameters>
            {
              (: members are not removed automatically from a deleted group :)
              let $all-group-members := grp:get-group-members($name)
              let $all-group-managers := grp:get-group-managers($name)
              return system:as-user("admin", $magic:password, ( 
                for $member in $all-group-members
                return sm:remove-group-member($name, $member),
                for $manager in $all-group-managers
                return sm:remove-group-manager($name, $manager),
                sm:remove-group($name)
              ))
            }
            <http:response status="204"/>
          </rest:response>
        else api:rest-error(403, "Forbidden")
      else api:rest-error(404, "Not found")
    else api:rest-error(401, "Not authorized")
};
