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
  catch { 
    util:log-system-out('Group testuser existed. Skipping creation.')
  },
  xmldb:create-user('testuser','testuser', ('testuser','everyone'), '/group/testuser'),
  try {
    xmldb:create-group('testuser2')
  }
  catch { 
    util:log-system-out('Group testuser2 existed. Skipping creation.')
  },
  xmldb:create-user('testuser2','testuser2', ('testuser2','everyone'), '/group/testuser2'),
  (: replace $magicpassword in XQuery files in /code with the admin password :)
  (:
  for $xquery in collection('/code')//document-uri(.)
  where matches($xquery, "xq[ml]$") and not(contains($xquery, "magic.xqm"))
  return
    let $collection := util:collection-name(string($xquery))
    let $resource := util:document-name(string($xquery))
    let $code := util:binary-to-string(util:binary-doc($xquery))
    where matches($code, "\$magic[:]?password")
    return 
      xmldb:store($collection, $resource, 
        replace($code, "\$magic[:]?password", "'ADMINPASSWORD'"), 
        'application/xquery')
   :)
   (: replace the password in $magic:password :)
   let $code := util:binary-to-string(util:binary-doc("/code/magic/magic.xqm"))
   let $newcode :=
      replace($code, '(variable\s+\$magic:password\s+:=\s+)""','$1"ADMINPASSWORD"')
   return 
    xmldb:store("/code/magic", "magic.xqm", $newcode, "application/xquery")
)
