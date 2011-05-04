xquery version "1.0";
(: Administrative functions that require the admin password
 : This file should be stored securely and the source containing
 : the correct password should not be released.
 : NOTE: you must change every let $admin-password to be correct!
 :
 : Copyright 2010-2011 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 : $Id: admin.tmpl.xqm 726 2011-04-04 19:33:16Z efraim.feinstein $
 :)

module namespace admin="http://jewishliturgy.org/modules/admin";

import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

(: This is fscked up insecure! :)
declare variable $admin:admin-user as xs:string := 'userman';

(:~ Create a new user in the database :)
declare function admin:new-user(
  $new-user as xs:string, 
  $new-password as xs:string)
  as xs:boolean {
  let $admin-password as xs:string := '*PASSWORD*'
  return
    if (xmldb:exists-user($new-user) or 
      string-length($new-user) eq 0)
    then false()
    else
    	let $home-collection := concat('/db/group/', $new-user)
    	return
      (system:as-user($admin:admin-user, $admin-password, (
      	xmldb:create-group($new-user),
        xmldb:create-user($new-user, $new-password,
          ($new-user, 'everyone'), $home-collection),
        xmldb:set-collection-permissions($home-collection, $new-user, $new-user, 
        	util:base-to-integer(0770, 8))
      )) and true())
};

(:~ change a user's password :)
declare function admin:change-password(
  $user-name as xs:string, 
  $old-password as xs:string, 
  $new-password as xs:string)
  as xs:boolean {
  let $admin-password as xs:string := '*PASSWORD*'
  return
    if (xmldb:authenticate('/db', $user-name, $old-password))
    then (system:as-user($admin:admin-user, $admin-password,
      xmldb:change-user($user-name, $new-password, (), ())), true())
    else false()
};

(:~ change a user's group memberships.  For this function to work: 
 : the logged-in user must be a member of all the groups in $new-groups.
 : the user can't be removed from his/her own group
 : $add-groups and $remove-groups can't contradict each other
 : The function either succeeds or fails wholesale
 : 
 : @param user-name user whose groups will be changed
 : @param add-groups groups to add 
 : @param remove-groups groups to remove membership from
 :)
declare function admin:change-groups(
  $user-name as xs:string, 
  $add-groups as xs:string*,
  $remove-groups as xs:string*) 
  as xs:boolean {
  let $user-groups := xmldb:get-user-groups($user-name)
  let $logged-in-user := xmldb:get-current-user()
  let $logged-in-groups := xmldb:get-user-groups($logged-in-user)
  let $allow-add := 
    not(($add-groups, $remove-groups)!=$logged-in-groups)
    and not($add-groups=$remove-groups)
    and not($remove-groups=$user-name)
  let $admin-password as xs:string := '*PASSWORD*'
  return 
    if ($allow-add) 
    then system:as-user($admin:admin-user, $admin-password,
      xmldb:change-user($user-name, (), 
        for $group in ($user-groups,$add-groups[not(.=$user-groups)])
        return if ($group=$remove-groups) then () else $group, ())
    )
    else false()
};

(:~ reindex the given collection
 : NOTE: this API may not be exposed in future versions.
 : @param $collection collection to reindex 
 : @return whether the collection was reindexed successfully.
 :)
declare function admin:reindex(
  $collection as xs:string
  ) as xs:boolean {
  let $admin-password as xs:string := '*PASSWORD*'
  return
    system:as-user($admin:admin-user, $admin-password,
      xmldb:reindex($collection))
};
