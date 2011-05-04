(:
 : Clear cache query
 :
 : You must be logged in to use it, otherwise, expect a 401
 : Accepts parameters:
 :  clear=yes|all
 :  path=?
 : Other parameters ignored
 :
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : The Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: clear-cache.xql 769 2011-04-29 00:02:54Z efraim.feinstein $
 :)

import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace app="http://jewishliturgy.org/modules/app" at "/db/code/modules/app.xqm";
import module namespace jcache="http://jewishliturgy.org/modules/cache" at "/db/code/modules/cache-controller.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/code/modules/paths.xqm";

declare namespace exist="http://exist.sourceforge.net/NS/exist";
declare namespace err="http://jewishliturgy.org/errors";


let $clear := request:get-parameter('clear','')
let $recurse := ($clear = 'all')
let $path := request:get-parameter('path','')
where (app:require-authentication())
return (
	if ($paths:debug)
	then
  	util:log-system-out('IN CLEAR-CACHE')
  else (),
  if (not($clear = ('yes','all')))
  then
    error(xs:QName('err:INVALID'), ('An invalid clear parameter "', $clear, '" was received.  It must be "yes" or "all".'))
  else 
    if (doc-available($path))
    then 
      (: the path references a document :)
      let $collection := util:collection-name($path)
      let $resource := util:document-name($path)
      return
        jcache:clear-cache-resource($collection, $resource)
    else if (xmldb:collection-available($path))
    then (
      jcache:clear-cache-collection($path, $recurse)
    )
    else 
      error(xs:QName('err:INVALID'), concat('The given path "', $path, '" is not an accessible document or collection'))
)
