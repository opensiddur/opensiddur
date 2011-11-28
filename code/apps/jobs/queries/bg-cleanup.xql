xquery version "3.0";
(:~ remove a resource in the background 
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "xmldb:exist:///code/modules/debug.xqm";
(:
declare variable $local:resource external;
:)


debug:debug($debug:info, "jobs",
 concat('Background cleanup ', $local:resource)
  ),
if (doc-available(concat($local:collection, "/", $local:resource)))
then 
  xmldb:remove($local:collection, $local:resource)
else ()
