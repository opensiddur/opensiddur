xquery version "3.0";
(:~ common module for reading/writing access (sharing) control
 : Not all types of access restrictions are supported!
 : See the access.rnc schema for details
 :
 : Open Siddur Project
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace acc="http://jewishliturgy.org/modules/access";

import module namespace app="http://jewishliturgy.org/modules/app"
  at "xmldb:exist:///db/code/modules/app.xqm";
import module namespace jvalidate="http://jewishliturgy.org/modules/jvalidate"
  at "xmldb:exist:///db/code/modules/jvalidate.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:///db/code/magic/magic.xqm";

declare namespace a="http://jewishliturgy.org/ns/access/1.0";
declare namespace error="http://jewishliturgy.org/errors";

declare variable $acc:schema := "/schema/access.rnc";

declare function acc:validate(
  $access as element(a:access)
  ) as xs:boolean {
  jvalidate:validation-boolean(
    acc:validate-report($access)
  )
};

declare function local:validate-report(
  $access as element(a:access)
  ) as element(report) {
  let $bad-usernames :=
    $access/
      (a:owner, a:share-user, a:deny-user)
      [not(xmldb:exists-user(.))]   
  let $all-groups := sm:get-groups()
  let $bad-groups :=
    $access/(a:group, a:share-group, a:deny-group)
      [not(.=$all-groups)]
  return
    element report {
      element status { 
        ("valid"[empty(($bad-usernames, $bad-groups))], "invalid")[1] 
      },
      for $bad in ($bad-usernames | $bad-groups)
      return
        element message { 
          attribute level { "Error" },
          concat("In element ", name($bad), 
            " the user or group ", $bad/string(), 
            " does not exist")
        }
    }
};

declare function acc:validate-report(
  $access as element(a:access)
  ) as element(report) {
  jvalidate:concatenate-reports((
    jvalidate:validate-relaxng($access, xs:anyURI($acc:schema)),
    local:validate-report($access)
  ))
};

(:~ get access rights as an a:access structure 
 : @param $doc A document
 :)
declare function acc:get-access(
  $doc as document-node()
  ) as element(a:access) {
  let $permissions as element(sm:permissions) := 
    sm:get-permissions(xs:anyURI(document-uri($doc)))/*
  return
    <a:access>
      <a:owner>{$permissions/@owner/string()}</a:owner>
      <a:group>{
        $permissions/(
          attribute write { contains(substring(@mode, 4, 3), "w") }, 
          @group/string()
        )
      }</a:group>
      <a:world>{
        let $mode-world := substring($permissions/@mode, 7, 3)
        return ( 
          attribute read { contains($mode-world, "r") },
          attribute write { contains($mode-world, "w") }
        )
      }</a:world>
      {
        for $group-share-ace in $permissions/sm:acl/sm:ace
          [@target="GROUP"][@access_type="ALLOWED"]
        return
          element a:share-group { 
            attribute write { contains($group-share-ace/@mode, "w") },
            $group-share-ace/@who/string()
          },
        for $user-share-ace in $permissions/sm:acl/sm:ace
          [@target="USER"][@access_type="ALLOWED"]
        return
          element a:share-user { 
            attribute write { contains($user-share-ace/@mode, "w") },
            $user-share-ace/@who/string()
          },
        for $group-deny-ace in $permissions/sm:acl/sm:ace
          [@target="GROUP"][@access_type="DENIED"]
        return
          element a:deny-group { 
            attribute read { not(contains($group-deny-ace/@mode, "r")) },
            $group-deny-ace/@who/string()
          },
        for $user-deny-ace in $permissions/sm:acl/sm:ace
          [@target="USER"][@access_type="DENIED"]
        return
          element a:deny-user { 
            attribute read { not(contains($user-deny-ace/@mode, "r")) },
            $user-deny-ace/@who/string()
          }
      }
    </a:access>
};

(: @return true if the logged in user can set access permissions
 : on the given $doc 
 :)
declare function local:can-set-access(
  $doc as document-node()
  ) as xs:boolean {
  let $user := app:auth-user()
  let $doc-uri := xs:anyURI(document-uri($doc))
  let $permissions as element(sm:permissions) :=
    sm:get-permissions($doc-uri)/*
  return 
    exists($user) and
    xmldb:is-admin-user($user) or (
      sm:has-access($doc-uri, "w") and
      $permissions/(
        @owner=$user or
        sm:get-group-members(@group)=$user
      )
    )
};

(:~ api helper for setting access.
 : @param $doc The document to change access to
 : @param $access The new access list 
 : Only a document owner or owner-group member can change 
 : access settings
 : Throws exceptions on error
 :)
declare function acc:set-access(
  $doc as document-node(),
  $access as element(a:access)
  ) as empty-sequence() {
  if (local:can-set-access($doc))
  then
    if (acc:validate($access))
    then
      let $user := app:auth-user()
      let $doc-uri := xs:anyURI(document-uri($doc))
      return 
        system:as-user("admin", $magic:password,(
          sm:chown($doc-uri, $access/a:owner),
          sm:chgrp($doc-uri, $access/a:group),
          sm:chmod($doc-uri, 
            concat("rw-r",   (: owner always has rw access, group always has r :)
              ("w"[xs:boolean($access/a:group/@write)], "-")[1],
              "-",
              ("r"[xs:boolean($access/a:world/@read)], "-")[1],
              ("w"[xs:boolean($access/a:world/@write)], "-")[1],
              "-"
            )
          ),
          sm:clear-acl($doc-uri),
          for $exception in $access/a:share-group
          return sm:add-group-ace($doc-uri, $exception, true(), 
            "r" || ("w"[xs:boolean($exception/@write)], "-")[1] || "-"),
          for $exception in $access/a:share-user
          return sm:add-user-ace($doc-uri, $exception, true(),
            "r" || ("w"[xs:boolean($exception/@write)], "-")[1] || "-"),
          for $exception in $access/a:deny-group
          return sm:add-group-ace($doc-uri, $exception, false(),
            ("r"[not(xs:boolean($exception/@read))], "-")[1]||"w-"),
          for $exception in $access/a:deny-user
          return sm:add-user-ace($doc-uri, $exception, false(),
            ("r"[not(xs:boolean($exception/@read))], "-")[1]||"w-")
          )
        )
    else 
      error(xs:QName("error:VALIDATION"), 
        "The access description is invalid")
  else error(xs:QName(
    if (app:auth-user())
    then "error:FORBIDDEN"
    else "error:UNAUTHORIZED"), "Access denied.")
};