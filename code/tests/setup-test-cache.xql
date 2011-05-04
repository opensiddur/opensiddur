xquery version "1.0";
(: Set up cache for testing directories 
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: setup-test-cache.xql 745 2011-04-17 17:43:50Z efraim.feinstein $
 :)
import module namespace jcache="http://jewishliturgy.org/modules/cache"
  at "xmldb:exist:///code/modules/cache-controller.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

for $resource in collection('/code/transforms')//tei:TEI
let $uri := trace(document-uri(root($resource)), 'trying ')
where matches($uri, '/test') and not(matches($uri, '/cache/'))
return (
util:log-system-out($uri),
jcache:cache-all($uri)),
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Caching test suite complete</title>
  </head>
  <body>
    <p>I'm done.</p>
  </body>
</html>
