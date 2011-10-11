xquery version "1.0";
(:~ 
 : Support functions for user management
 :
 : Copyright 2010-2011 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)

module namespace user="http://jewishliturgy.org/modules/user";

import module namespace admin="http://jewishliturgy.org/modules/admin"
	at "admin.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "app.xqm";

declare namespace err="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

declare variable $user:profile-resource := 'profile.xml';

declare variable $user:profile-prototype as element(tei:div) :=
	<tei:div type="contributor" xml:id="{app:auth-user()}">
    <tei:name/>
    <tei:email/>
    <tei:orgName/>
  </tei:div>;

declare function local:set-user-id(
  $profile as element(tei:div),
  $name as xs:string
  ) as element(tei:div) {
  element tei:div {
    attribute xml:id { $name },
    $profile/(@* except @xml:id,*)
  }
};

(:~ @return a URI pointing to a user's profile :)
declare function user:profile-uri(
    $user-name as xs:string) 
    as xs:string {
    app:concat-path(xmldb:get-user-home($user-name),$user:profile-resource)
};

(:~ store a new blank user profile 
 : @return a reference uri to the profile or empty on error
 :)
declare function user:new-profile(
  $user-name as xs:string
  ) as xs:string {
  let $home := xmldb:get-user-home($user-name)
  let $path := xmldb:store($home, $user:profile-resource,
    local:set-user-id($user:profile-prototype, $user-name))
  where $path
  return ( 
    (: profile is readable, but not writable by group, everything by user :)
    xmldb:set-resource-permissions($home, $user:profile-resource, $user-name, $user-name, 
      util:base-to-integer(0744,8)),
    $path
  )
};

(:~ create a new user with the given user name and password
 :
 : @param $user-name new user name
 : @param $password new user's password
 : @return true() if user created, error if not.
 :)
declare function user:create(
  $user-name as xs:string,
  $password as xs:string) 
  as xs:boolean {
  let $user-exists := xmldb:exists-user($user-name)
  let $status as xs:boolean :=
      (not($user-exists) or 
        error(xs:QName('err:USER_EXISTS'), 
          string-join(('User ', $user-name,' exists'),''))) 
      and 
      (if ($user-name) then true() else 
        error(xs:QName('err:REQUIRED_USER'), 'Parameter $user-name cannot be blank')) 
      and 
      (if ($password) then true() else
        error(xs:QName('err:REQUIRED_PASSWORD'), 'Parameter $password cannot be blank'))
  let $new-user-created := admin:new-user($user-name, $password)
  return 
    if ($new-user-created)
    then 
      if (system:as-user($user-name, $password, user:new-profile($user-name)))
      then true()
      else
        error(xs:QName('err:PROFILE_FAILED'),
          'User created but cannot store an empty profile (internal error).')
    else error(xs:QName('err:CREATE_FAILED'), concat('Cannot create user ', $user-name))
};
  
(:~ @return a user's profile :)
declare function user:profile(
  $user-name as xs:string) 
  as document-node()? {
  let $document-uri := user:profile-uri($user-name)
  return
    if (doc-available($document-uri))
    then doc($document-uri)
    else ()
};

(:~ Set your password. Any authentication type is OK. :)
declare function user:set-password(
  $old-password as xs:string,
  $new-password as xs:string)
  as element(report) {
  let $authenticated := app:authenticate()
  let $auth-user := app:auth-user()
  let $auth-password := $old-password
  return
    if (not($old-password))
    then error(xs:QName('err:EMPTY_PASSWORD'),'Old password cannot be empty.')
    else if (not($new-password))
    then error(xs:QName('err:EMPTY_PASSWORD'),'New password cannot be empty.')
    else if (not($authenticated) or not($auth-user))
    then error(xs:QName('err:NOT_AUTHORIZED'),'You must be logged in to change a password.')
    else if (not(admin:change-password($auth-user, $auth-password, $new-password)))
    then error(xs:QName('err:CHANGE_PASSWORD'),'Cannot change password.')
    else <report><status>ok</status></report>  
};

(:~ Set your password.  You must be authenticated with HTTP Basic. :)
declare function user:set-password(
    $new-password as xs:string)
    as element(report) {
    user:set-password(app:auth-password(), $new-password)
};

(:~ Disable a user by setting a random password.  Requires HTTP basic authentication. :)
declare function user:delete() 
  as element(report) {
  let $authenticated := xmldb:is-authenticated()
  return
    if ($authenticated) 
    then user:set-password(util:uuid())
    else error(xs:QName('err:LOGIN'), 'Authentication required.')
};

(:~ join another user to a group :)
declare function user:add-group(
  $user-name as xs:string, 
  $new-group as xs:string) {
  let $authenticated := app:authenticate()
  return
    if (not($authenticated))
    then
      error(xs:QName('err:NOT_AUTHORIZED'),'Authentication required.')
    else if (admin:change-groups($user-name, $new-group, ()))
    then 
      <report>
        <status>ok</status>
      </report>
    else
      error(xs:QName('err:ADD_GROUP'),string-join((
        'Cannot add ', $user-name, ' to ', $new-group, '.'),''))
};

(:~ remove self or another user from a group :)
declare function user:remove-group(
  $user-name as xs:string, 
  $group as xs:string) {
  let $authenticated := app:authenticate()
  return
    if (not($authenticated))
    then
      error(xs:QName('err:NOT_AUTHORIZED'),'You must be logged in')
    else if (admin:change-groups($user-name, (), $group))
    then 
      <report>
        <status>ok</status>
      </report>
    else
      error(xs:QName('err:REMOVE_GROUP'),string-join((
        'Cannot remove ', $user-name, ' from ',$new-group, '.'),''))
};
