xquery version "3.0";
(: install setup script 
 :
 : Open Siddur Project
 : Copyright 2010-2011 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
(
	(: set the admin password :)
	xmldb:change-user('admin', 'ADMINPASSWORD', (), ()),
  (: create userman user as equivalent of admin. userman is only required because
   : of a bug in eXist that prevents admin from deleting groups :)
  xmldb:create-user('userman', 'ADMINPASSWORD', 'dba', ()),
	(: add a demo user :)
  xmldb:create-group('demouser'),
	xmldb:create-user('demouser', 'resuomed', ('demouser','everyone'), '/group/demouser'),
	(: create two test user/groups and home collections where test files can be created and destroyed
  :)
  try {
    xmldb:create-group('testuser')
  }
  catch * { 
    util:log-system-out('Group testuser existed. Skipping creation.')
  },
  xmldb:create-user('testuser','testuser', ('testuser','everyone'), '/group/testuser'),
  try {
    xmldb:create-group('testuser2')
  }
  catch * { 
    util:log-system-out('Group testuser2 existed. Skipping creation.')
  },
  xmldb:create-user('testuser2','testuser2', ('testuser2','everyone'), '/group/testuser2'),
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
