xquery version "1.0";
(:~ background task executive
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "/code/modules/paths.xqm";
import module namespace jobs="http://jewishliturgy.org/apps/jobs"
  at "/code/apps/jobs/modules/jobs.xqm";

declare variable $local:task-id external;

declare function local:run-next-task(
  ) as empty() {
  if (not(jobs:is-task-running($task-id)))
  then 
    if (jobs:run($task-id))
    then local:run-next-task()
    else ()
  else ()
};

if ($paths:debug)
then 
  util:log-system-out(
    concat('In background task executive id ', $task-id, ' at ', string(current-dateTime()))
    )
else (),
local:run-next-task()
