xquery version "1.0";
(:~ task to find uncached resources and schedule the background
 : task to execute them
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "/code/modules/paths.xqm";

if ($paths:debug)
then 
  util:log-system-out(
    concat('In uncached resource scheduler at ', string(current-dateTime()))
  )
else ()