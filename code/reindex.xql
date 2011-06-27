xquery version "1.0";
(: reindex.xql
 :
 : call as reindex.xql?collection=X
 :
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: reindex.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
import module namespace admin="http://jewishliturgy.org/modules/admin"
  at "xmldb:exist:///code/modules/admin.xqm";

let $collection := request:get-parameter('collection','')
return
  <result xmlns="">{
    if ($collection)
    then admin:reindex($collection)
    else 'false'
  }</result>
