xquery version "3.0";
(:~ Job queue control functions
 : 
 : The job control structure looks like:
 : <jobs xmlns="http://jewishliturgy.org/apps/jobs">
 :  <job>
 :    <run>
 :      <query/>
 :      <param>
 :        <name/>
 :        <value/>
 :      </param>+
 :    </run>
 :    <priority/> <!--default 0 -->
 :    <runas/> <!-- default guest -->
 :    <id/> <!-- job id - set by the code -->
 :    <depends/>+ <!-- depends on completion of other jobs -->
 :    <running/> <!-- contains task id that is currently running the task -->
 :    <error>   <!-- where to store an exception output if an error occurs. The user who runs the job must have write access  -->
 :      <collection/>
 :      <resource/>
 :    </error>
 :    <signature/> <!-- md5 of the query and all parameters; used for testing for uniqueness -->
 :  </job>
 : </jobs>
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace jobs="http://jewishliturgy.org/apps/jobs";

import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "xmldb:exist:///code/modules/paths.xqm";

declare namespace err="http://jewishliturgy.org/errors";

declare option exist:optimize "enable=no";

declare variable $jobs:queue-collection := '/code/apps/jobs/data';
declare variable $jobs:queue-resource := "queue.xml";
declare variable $jobs:users-resource := "users.xml";
declare variable $jobs:next-id-resource := "next-id.xml";
declare variable $jobs:queue-path := 
  concat($jobs:queue-collection, '/', $jobs:queue-resource);
declare variable $jobs:users-path :=
  concat($jobs:queue-collection, '/', $jobs:users-resource);

declare function local:make-signature(
  $job as element(jobs:job)
  ) as xs:string {
  let $us :=
    string-join((
      $job/jobs:run/jobs:query,
      for $param in $job/jobs:run/jobs:param
      return ('P:', $param/jobs:name, 'V:', $param/jobs:value)
    ), ' ')
  return string(util:hash($us, 'md5', true()))
};

(: return the next viable job id 
 : expects to be run as admin
 :)
declare function local:next-job-id(
  $queue as document-node()
  ) as xs:integer {
  let $max-job-id as xs:integer := 2147483647
  let $job-id-path :=
    concat($jobs:queue-collection, "/", $jobs:next-id-resource)
  let $create-jobs-id-path :=
    if (doc-available($job-id-path))
    then ()
    else 
      if (xmldb:store($jobs:queue-collection, $jobs:next-id-resource,
        element jobs:next-id {1}
      ))
      then 
        xmldb:set-resource-permissions(
          $jobs:queue-collection, $jobs:next-id-resource,
          "admin", "dba", util:base-to-integer(0770, 8)
        )
      else 
        error(xs:QName("err:STORE"), "Cannot store the next job id. This is bad.")
  let $next-id-element :=
    doc($job-id-path)//jobs:next-id
  let $this-id := 
    $next-id-element/number()
  return (
    update value $next-id-element with (
      if ($this-id = $max-job-id)
      then 1
      else ($this-id + 1)
    ),
    if ($queue//jobs:job-id=$this-id)
    then ( 
      (: try again to avoid conflict, which is only possible
       if we have wrapped around :)
      local:next-job-id($queue)
    )
    else
      $this-id
  )
};

(: set up a task to be enqueued.
 : expects to be run as admin
 :)
declare function local:set-job-defaults(
  $jobs as element(jobs:job)+,
  $user as xs:string?
  ) as element(jobs:job)+ {
  let $queue := doc($jobs:queue-path) 
  for $job in $jobs
  return
    element jobs:job {
      $job/(* except (jobs:id, jobs:running, jobs:runas, jobs:signature)),
      element jobs:runas { ($user[.], 'guest')[1] },
      if ($job/jobs:priority)
      then ()
      else element jobs:priority { 0 },
      element jobs:id { local:next-job-id($queue) },
      element jobs:signature { local:make-signature($job) }
    }
};

(: remove a user from the user list if no more jobs (except
 : $exclude-job-id will run as that user 
 :)
declare function local:delete-jobs-user(
  $user as xs:string,
  $exclude-job-id as xs:integer?
  ) as empty() {
  system:as-user('admin', $magicpassword, 
    let $jobs := doc($jobs:queue-path)
    let $users := doc($jobs:users-path)
    where empty($jobs//(jobs:job[jobs:runas=$user][not(jobs:id=$exclude-job-id)]))
    return update delete $users//jobs:user[jobs:name=$user]
  )
};

(:~ add a user to the jobs user list :)
declare function local:add-jobs-user(
  $user as xs:string,
  $password as xs:string?
  ) as empty() {
  let $newuser := element jobs:user {
    element jobs:name { $user },
    element jobs:password { $password }
  }
  where not($user='guest')
  return
    system:as-user('admin', $magicpassword, 
      if (doc-available($jobs:users-path))
      then
        let $users := doc($jobs:users-path)/jobs:users
        where empty($users//jobs:name=$user)
        return update insert $newuser into $users
      else
        if (xmldb:store($jobs:queue-collection, $jobs:users-resource,
          element jobs:users {
            $newuser
          }))
        then
          xmldb:set-resource-permissions(
            $jobs:queue-collection, $jobs:users-resource, 
            'admin', 'dba',
            util:base-to-integer(0770, 8)
            )
        else
          error(xs:QName('err:INTERNAL'), "Cannot store users file.")
    )
};

(:~ schedule a job in the queue, return its job ids 
 : @param $jobs jobs structures of jobs to add
 : @param $user runas user
 : @param $password password of runas user
 :)
declare function jobs:enqueue(
  $jobs as element(jobs:job)+,
  $user as xs:string,
  $password as xs:string?
  ) as element(jobs:id)+ {
  for $job in $jobs[not(matches(normalize-space(.//jobs:query), '^(xmldb:exist://)?(/db)?/code'))]
  return 
    error(xs:QName('err:SECURITY'), concat("For security reasons, all scheduled tasks must be in the /db/code collection in the database, offender: ", $job//jobs:query))
  ,
  system:as-user('admin', $magicpassword,
    let $defaulted := local:set-job-defaults($jobs, $user)
    let $queue := doc($jobs:queue-path)/jobs:jobs
    return (
      local:add-jobs-user($user, $password),
      if ($queue)
      then
        update insert $defaulted into $queue
      else
        if (xmldb:store($jobs:queue-collection, $jobs:queue-resource,
          element jobs:jobs {
            $defaulted
          }))
        then (
          xmldb:set-resource-permissions(
            $jobs:queue-collection, $jobs:queue-resource, 
            'admin', 'dba',
            util:base-to-integer(0770, 8)
            )
        )
        else
          error(xs:QName('err:INTERNAL'), 
            "Internal error. Cannot store the job queue"),
      $defaulted//jobs:id   
    )
  )
};

(:~ enqueue the listed jobs if there are not already-enqueued
 : jobs with the same query and parameter values
 : return the job ids of all the enqueued jobs 
 :)
declare function jobs:enqueue-unique(
  $jobs as element(jobs:job)+,
  $user as xs:string,
  $password as xs:string
  ) as element(jobs:id)* {
  let $queue := 
    system:as-user('admin', $magicpassword, doc($jobs:queue-path))
  for $job in $jobs
  let $signature := local:make-signature($job)
  let $identical-job := $queue//jobs:signature[. = $signature]
  return
    if (exists($identical-job))
    then
      $identical-job/../jobs:id
    else
      jobs:enqueue($job, $user, $password)
};

(:~ mark a job completed :)
declare function jobs:complete(
  $job-id as xs:integer
  ) as empty() {
  system:as-user('admin', $magicpassword,
    let $queue := doc($jobs:queue-path)/jobs:jobs
    let $this-job := $queue/jobs:job[jobs:id=$job-id]  
    return (
      local:delete-jobs-user($this-job/jobs:runas, $this-job/jobs:id),
      update delete $this-job
    )
  )
};

(:~ mark a job incomplete-- run, but an error encountered, so it must be run again
 :)
declare function jobs:incomplete(
  $job-id as xs:integer
  ) as empty() {
  system:as-user('admin', $magicpassword,
    let $queue := doc($jobs:queue-path)/jobs:jobs
    let $this-job := $queue/jobs:job[jobs:id=$job-id]  
    return (
      update delete $this-job//jobs:running
    )
  )
};

(:~ cancel a job and all its dependent jobs
 : note: a running job cannot be canceled, but dependent jobs will be
 :)
declare function jobs:cancel( 
  $job-id as xs:integer
  ) as empty() {
  let $queue := 
    system:as-user('admin', $magicpassword,
      doc($jobs:queue-path))/jobs:jobs
  let $job := $queue//jobs:job[jobs:id=$job-id]
  where $job
  return  
    let $current-user := xmldb:get-current-user()
    let $can-cancel := 
      if ($job/jobs:runas=$current-user or 
        xmldb:is-admin-user($current-user))
      then true()
      else 
        error(xs:QName("err:AUTHORIZATION"), concat("The user ", $current-user, 
          " is not authorized to cancel job#", string($job-id), " which is owned by ",
          $job/jobs:runas))
    let $dependencies := $queue//jobs:job[jobs:depends=$job-id]
    let $has-external-dependencies := 
      some $d in $dependencies satisfies not($d/jobs:runas=$job/jobs:runas)
    return ( 
      (: find dependent jobs from the same user and cancel them :)
      for $dependency in $dependencies
      where $dependency/jobs:runas=$job/jobs:runas
      return (
        if ($paths:debug)
        then 
          util:log-system-out(concat("Cancel job dependency ", $dependency/jobs:id/number()))
        else (),
        util:log-system-out(
          concat("WARNING: While cancelling job ", 
          $job-id, " cannot cancel dependency ", 
          $dependency/jobs:id/number()))
        (:
         : TODO: we can't cancel here because eXist fails on compile
         :)
        (:jobs:cancel($dependency/jobs:id/number()):)
      ),
      (: try to cancel the current job :)
      if (not($job/jobs:running) and not($has-external-dependencies))
      then 
        (: cancel this job :)
        system:as-user('admin', $magicpassword,
          update delete $job
        )
      else (
        (: cannot cancel a running job -- TODO? :)
        (: cannot cancel a job that has dependencies from other users :)
      )
    )
};
  

(:~ mark a job as running by the given $task-id :)
declare function jobs:running(
  $job-id as xs:integer,
  $task-id as xs:integer?
  ) as empty() {
  system:as-user('admin', $magicpassword,
    let $queue := doc($jobs:queue-path)/jobs:jobs
    return
      update insert element jobs:running { $task-id } into 
        $queue/jobs:job[jobs:id=$job-id]
  )
};

(:~ find the next job that should be run and return its job structure :)
declare function jobs:pop(
  ) as element(jobs:job)? {
  let $queue := 
    system:as-user('admin', $magicpassword,
      doc($jobs:queue-path))/jobs:jobs
  let $max-priority := max($queue//jobs:priority[not(../jobs:running)])
  let $job-ids := $queue//jobs:id
  return
    $queue/jobs:job[not(jobs:running)]
      [jobs:priority=$max-priority]
      [not(jobs:depends=$job-ids)][1]
  
};

(:~ run the next job as the given task id 
 : return the job id of the job that runs or empty if no job runs
 :)
declare function jobs:run(
  $task-id as xs:integer
  ) as xs:integer? {
  let $next-job := jobs:pop()
  where exists($next-job) 
  return
    let $runas := $next-job/jobs:runas/string()
    let $job-id := $next-job/jobs:id/number()
    let $run := $next-job/jobs:run
    let $null := 
      if ($paths:debug)
      then util:log-system-out(("Jobs module: Next job: ", $next-job, " runas=", $runas, " $id=", $job-id, " run=", $run, " exist=", exists($next-job)))
      else ()
    let $password :=
      if ($runas='admin')
      then $magicpassword
      else 
        string(
          system:as-user('admin', $magicpassword, 
          doc($jobs:users-path)//jobs:user[jobs:name=$runas]/jobs:password
        ))
    return (
      jobs:running($job-id, $task-id),
      try {
        system:as-user($runas, $password,
          (
            if ($paths:debug)
            then util:log-system-out(("Jobs module attempting to run: ", $run))
            else (),
            let $query := util:binary-to-string(util:binary-doc($run/jobs:query))
            return 
            (
              util:eval($query , false(),
                (
                xs:QName('local:user'), $runas,
                xs:QName('local:password'), $password,
                for $param in $run/jobs:param
                let $qname := xs:QName(concat('local:', $param/jobs:name))
                let $value := string($param/jobs:value)
                return ($qname, $value)
                )
              )
            )
          
          )
        ),
        jobs:complete($job-id),
        xs:integer($job-id)
      }
      catch * ($code, $description, $value) {
        local:record-exception($job-id, $code, $description, $value),
        jobs:incomplete($job-id), 
        jobs:cancel($job-id),
        util:log-system-out(('Jobs module: An exception occurred while running job ',$job-id,': ', $code, ' ', $description, ' ', $value))
      }
    )
};

(:~ determine if any task is running that has the given task id :)
declare function jobs:is-task-running(
  $task-id as xs:integer
  ) as xs:boolean {
  system:as-user('admin', $magicpassword,
    some $j in doc($jobs:queue-path)//jobs:running satisfies $j=$task-id
  )
};

(:~ record an exception according to the jobs:error description in the given job :)
declare function local:record-exception(
  $job-id as xs:integer, 
  $code as xs:string,
  $description as xs:string,
  $value as xs:string
  ) as empty() {
  let $job := 
    system:as-user('admin', $magicpassword,
      doc($jobs:queue-path)//jobs:job[jobs:id=$job-id]
    )
  let $error-element := $jobs/jobs:error
  where $error-element
  return
    let $runas as xs:string := $job/jobs:runas/string()
    let $collection := string($error-element/jobs:collection)
    let $resource := string($error-element/jobs:resource)
    return
      if (xmldb:store($collection, $resource, 
        <jobs:error>
          {$job}
          <jobs:code>{$code}</jobs:code>
          <jobs:description>{$description}</jobs:description>
          <jobs:value>{$value}</jobs:value>
        </jobs:error>
        ))
      then 
        xmldb:set-resource-permissions($collection, $resource, $runas, $runas,
          util:base-to-integer(0770,8))
      else 
        error(xs:QName("err:STORE"), "Cannot store the error output. This is very bad!")
};
