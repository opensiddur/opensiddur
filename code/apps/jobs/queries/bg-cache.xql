xquery version "1.0";
(:~ cache a single resource and its dependencies from the background 
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "/code/modules/paths.xqm";
import module namespace jcache="http://jewishliturgy.org/modules/cache"
  at "/code/modules/cache-controller.xqm";

declare variable $local:resource external;
declare variable $local:user external;
declare variable $local:password external;

if ($paths:debug)
then 
  util:log-system-out(
    concat('Background caching ', $local:resource)
  )
else (),
jcache:cache-all($local:resource, $local:user, $local:password)
