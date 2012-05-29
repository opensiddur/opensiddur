xquery version "3.0";
(: install setup script 
 :
 : Open Siddur Project
 : Copyright 2010-2012 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)

declare function local:create-groups(
  $group-names as xs:string*,
  $manager as xs:string
  ) as empty() {
  for $group-name in $group-names
  let $null :=
    try {
      xmldb:create-group($group-name, $manager)
    }
    catch * {
      util:log-system-out(concat('Group ', $group-name, ' existed. Skipping creation.'))
    }
  return ()
};

(
  (: create userman user as equivalent of admin. userman is only required because
   : of a bug in eXist that prevents admin from deleting groups :)
  xmldb:create-user('userman', 'ADMINPASSWORD', 'dba', ()),
	(: add a demo user :)
  local:create-groups("everyone", "admin"),
	xmldb:create-user('demouser', 'resuomed', ('demouser','everyone'), ()),
	(: create two test user/groups and home collections where test files can be created and destroyed
  :)
  xmldb:create-user('testuser','testuser', ('testuser','everyone'), ()),
  xmldb:create-user('testuser2','testuser2', ('testuser2','everyone'), ()),
  (: replace the password in $magic:password :)
  xmldb:create-collection("/db", "code"),
  xmldb:create-collection("/db/code", "magic"),
  let $newcode :=
    "xquery version '1.0';
    module namespace magic = 'http://jewishliturgy.org/magic';

    declare variable $magic:password := 'ADMINPASSWORD';

    declare function magic:null() {()};
    "
  return 
    xmldb:store("/code/magic", "magic.xqm", $newcode, "application/xquery")
)
