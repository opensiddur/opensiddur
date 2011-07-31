xquery version "3.0";
(:~ background task executive
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "xmldb:exist:///code/modules/paths.xqm";
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
  if ($paths:debug)
  then 
    util:log-system-out(
      concat('In background task executive id ', $local:task-id, ' at ', string(current-dateTime()))
      )
  else (),
  local:run-next-task()
}
catch * ($code, $d, $v) {
  util:log-system-out(('EXCEPTION IN BG-RUN-TASK: ', $code, ' ', $d, ' ', $v))
}
