xquery version "3.0";
(:~ remove a resource in the background 
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "xmldb:exist:///code/modules/paths.xqm";
import module namespace jcache="http://jewishliturgy.org/modules/cache"
  at "xmldb:exist:///code/modules/cache-controller.xqm";

(:
declare variable $local:resource external;
:)

try {
  if ($paths:debug)
  then 
    util:log-system-out(
      concat('Background cleanup ', $local:resource)
    )
  else (),
  xmldb:remove($local:collection, $local:resource)
}
catch * ($c, $d, $v) {
  util:log-system-out(("Error during background cleanup: ", $c, " ", $d, " ", $v))
}
