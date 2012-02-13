xquery version "3.0";
(:~ background task executive
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "xmldb:exist:///code/modules/debug.xqm";
import module namespace jobs="http://jewishliturgy.org/apps/jobs"
  at "xmldb:exist:///code/apps/jobs/modules/jobs.xqm";

declare variable $local:task-id external;

declare function local:run-next-task(
  ) {
  if (not(jobs:is-task-running($local:task-id)))
  then 
    if (jobs:run($local:task-id))
    then local:run-next-task()
    else ()
  else ()
};

try {
  debug:debug(
    $debug:info,
    "jobs",
    concat('In background task executive id ', $local:task-id, ' at ', string(current-dateTime()))
  ),
  local:run-next-task()
}
catch * {
  debug:debug(
    $debug:warn,
    "jobs",
    (
      'EXCEPTION IN BG-RUN-TASK: ', 
      debug:print-exception($err:module, $err:line-number, $err:column-number, $err:code, $err:value, $err:description)
    )
  )
}
