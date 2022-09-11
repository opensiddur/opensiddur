xquery version "3.1";
(:~ common module for reading/writing access (sharing) control
 : Not all types of access restrictions are supported!
 : See the access.rnc schema for details
 :
 : Open Siddur Project
 : Copyright 2012-2014 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace acc="http://jewishliturgy.org/modules/access";

import module namespace app="http://jewishliturgy.org/modules/app"
  at "app.xqm";
import module namespace jvalidate="http://jewishliturgy.org/modules/jvalidate"
  at "jvalidate.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "../magic/magic.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "paths.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace a="http://jewishliturgy.org/ns/access/1.0";
declare namespace error="http://jewishliturgy.org/errors";

declare variable $acc:schema := concat($paths:schema-base, "/access.rnc");

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
      (a:owner, a:grant/a:grant-user, a:deny/a:deny-user)
      [not(sm:user-exists(.))]   
  let $all-groups := sm:list-groups()
  let $bad-groups :=
    $access/(a:group, a:grant/a:grant-group, a:deny/a:deny-group)
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

(:~
 : @param $doc The document
 : @param $user The user 
 : @return whether the given user can relicense the document
 :)
declare function acc:can-relicense(
  $doc as document-node(),
  $user as xs:string?
  ) as xs:boolean {
  let $has-adjustable-license := 
    exists($doc//tei:licence)
  let $authors := 
    distinct-values(
    $doc//tei:change/@who/substring-after(., "/user/")
  )
  let $can-change-license :=
    exists($user) and 
    $has-adjustable-license and
    (count($authors) = 1) and 
    $authors = $user
  return $can-change-license
};

declare function acc:get-access-as-user(
  $doc as document-node(),
  $user as xs:string?
  ) as element(a:user-access) {
  acc:get-access-as-user($doc, $user, true())
};

(:~ determine the access rights to a document that a given
 :  user has. The available rights are: read, write, chmod, and relicense. 
 : read/write = can read/write the document, 
 : chmod = can change access rights to the document,
 : relicense = can change the license of the document
 : (note that relicensing rights also require write access!)
 : @param $doc A document
 : @param $user A user
 : @param $can-set Whether to return the @chmod and @relicense bits; default true()
 :)
declare function acc:get-access-as-user(
  $doc as document-node(),
  $user as xs:string?,
  $can-set as xs:boolean
  ) as element(a:user-access) {
  let $user := ($user, "guest")[1]  (: no user = guest user :)
  let $path := document-uri($doc)
  return
    <a:user-access user="{$user}">{
      if ($user = app:auth-user())
      then (
        (: the requested user is the current user :)
        attribute read { sm:has-access($path, "r") },
        attribute write { sm:has-access($path, "w") },
        if ($can-set)
        then (
            attribute chmod { acc:can-set-access($doc, $user) },
            attribute relicense { acc:can-relicense($doc, $user) }
        )
        else ()
      )
      else 
        (: the requested user is not the current user
         : and may not even exist
         :)
        if (
          $user="guest" or  (: sm:user-exists fails for guests :) 
          sm:user-exists($user))
        then
          (: OK, user exists :)
          let $access := acc:get-access-data($doc)
          let $user-groups := 
            system:as-user("admin", $magic:password, 
              sm:get-user-groups($user)
            )
          return (
            if ($can-set)
            then (
              attribute chmod { acc:can-set-access($doc, $user) },
              attribute relicense { acc:can-relicense($doc, $user) }
            )
            else (),
            if ($user = $access/a:owner)
            then (
              (: the user is the owner :)
              attribute read { true() }, 
              attribute write { true() }
            )
            else if ($user-groups = $access/a:group/@group)
            then (
              (: the user is in the owner's group :)
              attribute read { true() },
              $access/a:group/@write
            )
            else 
              let $default-read := xs:boolean($access/a:world/@read)
              let $default-write := xs:boolean($access/a:world/@write)
              let $share-acl-by-user := 
                $access/a:grant/a:grant-user[.=$user][last()]
              let $deny-acl-by-user := 
                $access/a:deny/a:deny-user[.=$user][last()]
              let $share-acl-by-group :=
                $access/a:grant/a:grant-group[.=$user-groups][last()]
              let $deny-acl-by-group := 
                $access/a:deny/a:deny-group[.=$user-groups][last()]
              return (
                attribute read { 
                  (
                    let $controlled-by :=
                      ( $share-acl-by-user |
                        $deny-acl-by-user[@read="false"] |
                        $share-acl-by-group |
                        $deny-acl-by-group[@read="false"]
                      )[last()]
                    return 
                      typeswitch($controlled-by)
                      case element(a:grant-group)
                      return true()
                      case element(a:grant-user)
                      return true()
                      case element(a:deny-group)
                      return false()
                      case element(a:deny-user)
                      return false()
                      default return (),
                    $default-read
                  )[1] 
                },
                attribute write { 
                  (
                    let $controlled-by :=
                      ( $share-acl-by-user[@write="true"] |
                        $deny-acl-by-user |
                        $share-acl-by-group[@write="true"] |
                        $deny-acl-by-group
                      )[last()]
                    return 
                      typeswitch($controlled-by)
                      case element(a:grant-group)
                      return true()
                      case element(a:grant-user)
                      return true()
                      case element(a:deny-group)
                      return false()
                      case element(a:deny-user)
                      return false()
                      default return (),
                    $default-write
                  )[1] 
                } 
              )
          )
        else 
          error(
            xs:QName("error:BAD_REQUEST"), 
            "Requested user does not exist"
          )
    }</a:user-access>
};

(:~ get access rights as an a:access structure, including details and you 
 : @param $doc a document
 :)
declare function acc:get-access(
  $doc as document-node()
  ) as element(a:access) {
  let $as-user := acc:get-access-as-user($doc, app:auth-user())
  let $details := acc:get-access-data($doc)
  return 
    <a:access>
        <a:you>{$as-user/(@* except @user)}</a:you>
        {$details/*}
    </a:access>
};

(:~ get access rights as an a:access structure, excluding a:you 
 : @param $doc A document
 :)
declare function acc:get-access-data(
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
        let $grants := (
          for $group-share-ace in $permissions/sm:acl/sm:ace
            [@target="GROUP"][@access_type="ALLOWED"]
          return
            element a:grant-group { 
              attribute write { contains($group-share-ace/@mode, "w") },
              $group-share-ace/@who/string()
            },
          for $user-share-ace in $permissions/sm:acl/sm:ace
            [@target="USER"][@access_type="ALLOWED"]
          return
            element a:grant-user { 
              attribute write { contains($user-share-ace/@mode, "w") },
              $user-share-ace/@who/string()
            }
        )
        where $grants
        return
            <a:grant>{
                $grants
            }</a:grant>,
        let $denials := (
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
        )
        where $denials
        return
            <a:deny>{
                $denials
            }</a:deny>
      }
    </a:access>
};

declare function acc:can-set-access(
  $doc as document-node()
  ) as xs:boolean {
  acc:can-set-access($doc, app:auth-user())
};

(: @return true if the given user can set access permissions
 : on the given $doc 
 :)
declare function acc:can-set-access(
  $doc as document-node(),
  $user as xs:string?  
  ) as xs:boolean {
  let $doc-uri := xs:anyURI(document-uri($doc))
  let $permissions as element(sm:permissions) :=
    sm:get-permissions($doc-uri)/*
  return 
    exists($user) and
    sm:is-dba($user) or (
      (:sm:has-access($doc-uri, "w"):)
      acc:get-access-as-user($doc, $user, false())/@write="true" and
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
  if (acc:can-set-access($doc))
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
          for $exception in $access/(a:grant|a:deny)/*
          return 
            typeswitch($exception)
            case element(a:grant-group)
            return
                sm:add-group-ace($doc-uri, $exception, true(), 
                    "r" || ("w"[xs:boolean($exception/@write)], "-")[1] || "-")
            case element(a:grant-user)
            return
                sm:add-user-ace($doc-uri, $exception, true(),
                    "r" || ("w"[xs:boolean($exception/@write)], "-")[1] || "-")
            case element(a:deny-group)
            return 
                sm:add-group-ace($doc-uri, $exception, false(),
                    ("r"[not(xs:boolean($exception/@read))], "-")[1]||"w-")
            case element(a:deny-user)
            return 
                sm:add-user-ace($doc-uri, $exception, false(),
                    ("r"[not(xs:boolean($exception/@read))], "-")[1]||"w-")
            default return ()
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
