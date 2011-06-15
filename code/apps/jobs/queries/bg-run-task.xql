xquery version "1.0";
(:~ task to find uncached resources and schedule the background
 : task to execute them
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "/code/modules/paths.xqm";

let $task-id := request:get-parameter('task-id', ())
return
  if ($paths:debug)
  then 
    util:log-system-out(
      concat('In background task executive id ', $task-id, ' at ', string(current-dateTime()))
    )
  else ()
