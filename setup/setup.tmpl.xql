xquery version "1.0";
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
	(: create a test user/group with a home collection where test files can be created and destroyed
  :)
  util:catch('*', xmldb:create-group('testuser'), ('Group testuser existed. Skipping creation.')),
  xmldb:create-user('testuser','testuser', ('testuser','everyone'), '/group/testuser'),
  (: replace $magicpassword in XQuery files in /code with the admin password :)
  for $xquery in collection('/code')//document-uri(.)
  where matches($xquery,'xq[ml]$')
  return
    let $collection := util:collection-name(string($xquery))
    let $resource := util:document-name(string($xquery))
    let $code := util:binary-to-string(util:binary-doc($xquery))
    where matches($code, "$magic(:)?password")
    return 
      xmldb:store($collection, $resource, 
        replace($code, "\$magic(:)?password", "'ADMINPASSWORD'"), 
        'application/xquery')
)
