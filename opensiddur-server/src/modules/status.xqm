xquery version "3.0";
(:~ job status/logging module 
 :
 : Open Siddur Project
 : Copyright 2014 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace status="http://jewishliturgy.org/modules/status";

import module namespace app="http://jewishliturgy.org/modules/app"
    at "app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
    at "data.xqm";
import module namespace mirror="http://jewishliturgy.org/modules/mirror"
    at "mirror.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
    at "../magic/magic.xqm";

declare variable $status:status-collection := "/db/cache/status";
declare variable $status:bg-scheduler := "scheduler.xml";

(:~ initial setup :)
declare function status:setup(
    ) {
    if (xmldb:collection-available($status:status-collection))
    then ()
    else 
        let $cp := app:make-collection-path($status:status-collection, "/", sm:get-permissions(xs:anyURI("/db/data")))
        let $ch := sm:chmod(xs:anyURI($status:status-collection), "rwxrwxrwx")
        return status:setup-scheduler()
};

(:~ clear all jobs :)
declare function status:clear-jobs(
    ) {
    for $job in collection($status:status-collection)[status:job]
    return xmldb:remove(util:collection-name($job), util:document-name($job))
};

(:~ return a query-unique job id for the processing of the given document :)
declare function status:get-job-id(
    $doc as document-node()
    ) as xs:string {
    let $query-document-id := string(util:absolute-resource-id($doc))
    let $query-time := string((current-dateTime() - xs:dateTime("1970-01-01T00:00:00-00:00")) div xs:dayTimeDuration('PT0.001S'))
    return $query-document-id || "-" || $query-time
};

(:~ @return the name of the job document :)
declare function status:job-doc-name(
    $job-id as xs:string
    ) as xs:string {
    $job-id || ".status.xml"
};

(:~ get the status document for a given origin document 
 : @param $job-id the job identifier
 :)
declare function status:doc(
    $job-id as xs:string
    ) as document-node()? {
    let $job-doc := status:job-doc-name($job-id)
    return doc($status:status-collection || "/" || $job-doc)
};

(:~ start a job in this query with $origin-doc, 
 : @return the job-id of the job
 :)
declare function status:start-job(
    $origin-doc as document-node()
    ) as xs:string {
    let $collection := util:collection-name($origin-doc)
    let $resource := util:document-name($origin-doc)
    let $job-id := status:get-job-id($origin-doc)
    let $status-resource := status:job-doc-name($job-id)
    let $path := 
        xmldb:store(
            $status:status-collection,
            $status-resource,
            element status:job {
                attribute user { (app:auth-user(), "guest")[1] },
                attribute started { util:system-dateTime()},
                attribute state { "working" },
                attribute resource {data:db-path-to-api(string-join(($collection, $resource), '/'))}
            }
        )
    let $permissions := app:copy-permissions(
        $path,
        sm:get-permissions(document-uri($origin-doc)))
    let $universal := sm:chmod(xs:anyURI($path), "rw-rw-rw-")
    return $job-id
};

declare function status:complete-job(
    $job-id as xs:string,
    $result-path as xs:string
    ) as empty-sequence() {
    let $sj := status:doc($job-id)/status:job
    return (
        update value $sj/@state with "complete",
        update insert attribute completed { util:system-dateTime() } into $sj,
        update insert element status:complete {
            attribute timestamp { util:system-dateTime() },
            attribute resource { data:db-path-to-api($result-path) }
        } into $sj
    )
};

declare function status:fail-job(
    $job-id as xs:string,
    $resource as item(),
    $stage as xs:string?,
    $error as item()
    ) as empty-sequence() {
    let $sj := status:doc($job-id)/status:job
    let $res :=
        data:db-path-to-api(
            typeswitch($resource)
            case document-node() return document-uri($resource)
            default return $resource
        )
    return (
        update value $sj/@state with "failed",
        update insert attribute failed { util:system-dateTime() } into $sj,
        update insert element status:fail {
            attribute timestamp { util:system-dateTime() },
            attribute resource { $res },
            if ($stage) then attribute stage { $stage } else (),
            $error
        } into $sj
    )
};

declare function  status:start(
    $job-id as xs:string,
    $resource as item(),
    $stage as xs:string
    ) as empty-sequence() {
    let $sj := status:doc($job-id)/status:job
    let $res :=
        data:db-path-to-api(
            typeswitch($resource)
            case document-node() return document-uri($resource)
            default return $resource
        )
    return (
        update insert element status:start {
            attribute timestamp { util:system-dateTime() },
            attribute resource { $res },
            attribute stage { $stage }
        } into $sj
    ) 
};

declare function  status:finish(
    $job-id as xs:string,
    $resource as item(),
    $stage as xs:string
    ) as empty-sequence() {
    let $sj := status:doc($job-id)/status:job
    let $res :=
        data:db-path-to-api(
            typeswitch($resource)
            case document-node() return document-uri($resource)
            default return $resource
        )
    return (
        update insert element status:finish {
            attribute timestamp { util:system-dateTime() },
            attribute resource { $res },
            attribute stage { $stage }
        } into $sj
    ) 
};

declare function  status:log(
    $job-id as xs:string,
    $resource as item()?,
    $stage as xs:string?,
    $message as item()*
    ) as empty-sequence() {
    let $sj := status:doc($job-id)/status:job
    let $res :=
        if (exists($resource))
        then
            data:db-path-to-api(
                typeswitch($resource)
                case document-node() return document-uri($resource)
                default return $resource
            )
        else ""
    return (
        update insert element status:log {
            attribute timestamp { util:system-dateTime() },
            attribute resource { $res },
            attribute stage { $stage },
            $message
        } into $sj
    ) 
};


(: these functions are for the background task processor, which can be eliminated when util:eval-async works :)

declare function status:setup-scheduler() {
    let $scheduler := 
        xmldb:store($status:status-collection, $status:bg-scheduler,
            <status:scheduler>
            </status:scheduler>
        )
    let $chmod := sm:chmod(xs:anyURI($scheduler), "rw-rw-rw-")
    return ()
};

declare function status:submit(
    $xquery as xs:string
    ) {
    let $sch := doc($status:status-collection || "/" || $status:bg-scheduler)/status:scheduler
    return update insert <status:task>{$xquery}</status:task> into $sch 
};

declare function status:run(
    ) {
    let $sch := doc($status:status-collection || "/" || $status:bg-scheduler)/status:scheduler
    let $next-task := string($sch/status:task[1])
    let $del := update delete $sch/status:task[1]
    where $next-task
    return system:as-user("admin", $magic:password, util:eval($next-task))
};
