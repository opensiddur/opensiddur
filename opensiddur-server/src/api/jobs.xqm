xquery version "3.0";
(:~ API module for background job tracking
 : 
 : Copyright 2014 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed Under the GNU Lesser General Public License, version 3 or later
 :)
module namespace job='http://jewishliturgy.org/api/jobs';

import module namespace api="http://jewishliturgy.org/modules/api"
  at "../modules/api.xqm";
import module namespace crest="http://jewishliturgy.org/modules/common-rest"
  at "../modules/common-rest.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "../modules/data.xqm";
import module namespace status="http://jewishliturgy.org/modules/status"
  at "../modules/status.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace o="http://a9.com/-/spec/opensearch/1.1/";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare function job:get-jobs(
    $user as xs:string?,
    $state as xs:string?,
    $from as xs:string?,
    $to as xs:string?
    ) as node()* {
    let $username := $user
    let $c := collection($status:status-collection)
    let $state :=
        if (empty($state))
        then ("complete", "working", "failed")
        else $state
    let $from := 
        if (empty($from))
        then min($c//@started/string())
        else $from
    let $to :=
        if (empty($to))
        then max($c//@started/string())
        else $to
    return
        if (empty($user))
        then
            $c//status:job
                [@started ge $from]
                [@started le $to]
                [$state=@state]
        else
            $c//status:job
                [@user=$user]
                [@started ge $from]
                [@started le $to]
                [$state=@state]
};

(:~ List all jobs
 : @param $user List only jobs initiated by the given user
 : @param $state List only jobs with the given state, which may be one of: working, complete, failed. No restriction if omitted.
 : @param $from List only jobs started on or after the given date/time. No restriction if omitted. The expected format is yyyy-mm-ddThh:mm:ss, where any of the smaller sized components are optional.
 : @param $to List only jobs started on or before the given date/time. No restriction if omitted.
 : @param $start Start the list from the given index
 : @param $max-results List only this many results
 : @return An HTML list
 :)
declare 
    %rest:GET
    %rest:path("/api/jobs")
    %rest:query-param("user", "{$user}")
    %rest:query-param("state", "{$state}")
    %rest:query-param("from", "{$from}")
    %rest:query-param("to", "{$to}")
    %rest:query-param("start", "{$start}", 1)
    %rest:query-param("max-results", "{$max-results}", 100)
    %rest:produces("application/xhtml+xml", "text/html", "application/xml", "text/xml")
    function job:list(
        $user as xs:string*,
        $state as xs:string*,
        $from as xs:string*,
        $to as xs:string*,
        $start as xs:integer*,
        $max-results as xs:integer*
    ) as item()+ {
    if ($state and not($state=("working", "failed", "complete")))
    then
        api:rest-error(400, "Invalid state. Must be one of 'working', 'failed', or 'complete'", $state) 
    else (
      <rest:response>
        <output:serialization-parameters>
          <output:method value="html5"/>
        </output:serialization-parameters>
      </rest:response>,
      <html xmlns="http://www.w3.org/1999/xhtml"> 
        <head>
          <title>Jobs</title>
          <meta charset="utf-8"/>
        </head>
        <body>
            <ul class="results">{
                for $job in 
                    subsequence(
                        for $jb in job:get-jobs($user[.][1], $state[.][1], $from[.][1], $to[.][1])
                        order by $jb/@started/string() descending
                        return $jb, ($start, 1)[1], ($max-results, 100)[1])
                let $job-id := substring-before(util:document-name($job), ".status.xml")
                return
                    <li class="result"><a href="{api:uri-of('/api/jobs')}/{$job-id}">{
                        $job/@resource/string()
                        }</a>:
                        <span class="title">{
                            let $doc := data:doc($job/@resource/string())
                            return
                                if (exists($doc))
                                then crest:tei-title-function($doc)
                                else "(deleted)"
                        }</span>:
                        <span class="user">{$job/@user/string()}</span>:
                        <span class="state">{$job/@state/string()}</span>:
                        <span class="started">{$job/@started/string()}</span>-
                        {
                            if ($job/@state=("complete", "failed"))
                            then
                                <span class="{$job/@state/string()}">{$job/(@completed,@failed)/string()}</span>
                            else ()
                        }
                    </li>
            }</ul>
        </body>
      </html>
    )
};

(:~ Get the status of a job, given a job id
 : @param $id The job id
 : @return HTTP 200 and a job description XML document 
 : @error HTTP 404 if the job id does not exist
 :)
declare 
    %rest:GET
    %rest:path("/api/jobs/{$id}")
    %rest:produces("application/xml", "text/xml")
    %output:method("xml")
    %output:indent("yes")
    function job:get-job(
        $id as xs:string
    ) as item()+ {
    let $status-doc := doc($status:status-collection || "/" || $id || ".status.xml")
    return 
        if ($status-doc)
        then $status-doc
        else api:rest-error(404, "Not found", $id)
};

