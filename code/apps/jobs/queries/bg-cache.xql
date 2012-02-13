xquery version "3.0";
(:~ cache a single resource and its dependencies from the background 
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "xmldb:exist:///code/modules/debug.xqm";
import module namespace jcache="http://jewishliturgy.org/modules/cache"
  at "xmldb:exist:///code/modules/cache-controller.xqm";

(:
declare variable $local:resource external;
declare variable $local:user external;
declare variable $local:password external;
:)

try {
  debug:debug(
    $debug:info,
    "jobs",
    concat('Background caching ', $local:resource)
  ),
  jcache:cache-all($local:resource, $local:user, $local:password)
}
catch * {
  debug:debug(
    $debug:warn,
    "jobs", 
    ("Error during background caching: ", 
      debug:print-exception($err:module, $err:line-number, $err:column-number, $err:code, $err:value, $err:description))
  )
}
