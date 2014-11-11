xquery version "3.0";
(:~ job status/logging module 
 :
 : Open Siddur Project
 : Copyright 2014 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace status="http://jewishliturgy.org/modules/status";

import module namespace data="http://jewishliturgy.org/modules/data"
    at "data.xqm";
import module namespace mirror="http://jewishliturgy.org/modules/mirror"
    at "mirror.xqm";

declare variable $status:status-collection := "/db/cache/status";

(:~ initial setup :)
declare function status:setup(
    ) {
    if (xmldb:collection-available($status:status-collection))
    then ()
    else mirror:create($status:status-collection, "/db/data", true())
};

(:~ clear all jobs :)
declare function status:clear-jobs(
    ) {
    for $job in collection($status:status-collection)[status:job]
    return mirror:remove($status:status-collection, util:collection-name($job), util:document-name($job))
};

(:~ get the status document for a given origin document 
 : @param $origin-doc origin document node or path string
 :)
declare function status:doc(
    $origin-doc as item()
    ) as document-node()? {
    let $origin :=
        typeswitch($origin-doc)
        case document-node() return $origin-doc
        default return data:doc($origin-doc)
    return mirror:doc($status:status-collection, document-uri($origin))
};

(:~ start a job :)
declare function status:start-job(
    $origin-doc as document-node()
    ) as empty-sequence() {
    let $collection := util:collection-name($origin-doc)
    let $resource := util:document-name($origin-doc)
    let $mirrored-path := 
        mirror:store(
            $status:status-collection,
            $collection,
            $resource,
            element status:job {
                attribute started { util:system-dateTime()},
                attribute state { "working" },
                attribute resource {data:db-path-to-api(string-join(($collection, $resource), '/'))}
            }
        )
    return ()
};

declare function status:complete-job(
    $origin-doc as item(),
    $result-path as xs:string
    ) as empty-sequence() {
    let $sj := status:doc($origin-doc)/status:job
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
    $origin-doc as item(),
    $resource as item(),
    $stage as xs:string?,
    $error as item()
    ) as empty-sequence() {
    let $sj := status:doc($origin-doc)/status:job
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
    $origin-doc as item(),
    $resource as item(),
    $stage as xs:string
    ) as empty-sequence() {
    let $sj := status:doc($origin-doc)/status:job
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
    $origin-doc as item(),
    $resource as item(),
    $stage as xs:string
    ) as empty-sequence() {
    let $sj := status:doc($origin-doc)/status:job
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
    $origin-doc as item(),
    $resource as item()?,
    $stage as xs:string?,
    $message as item()*
    ) as empty-sequence() {
    let $sj := status:doc($origin-doc)/status:job
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

