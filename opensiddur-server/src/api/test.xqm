xquery version "3.0";

(:~ Test API to run XQSuite-style tests
:)

module namespace tst = "http://jewishliturgy.org/api/test";

import module namespace api="http://jewishliturgy.org/modules/api"
    at "../modules/api.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
    at "../modules/paths.xqm";
import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(:~ recursively find all xqueries starting from the given path :)
declare function tst:list-xqueries(
        $path as xs:string
) as xs:string* {
    if (xmldb:collection-available($path))
    then (
        (: $path is a collection :)
        for $child-collection in xmldb:get-child-collections($path)
        let $child-path := concat($path, '/', $child-collection)
        return
            tst:list-xqueries($child-path),
        for $child-resource in xmldb:get-child-resources($path)
        let $child-path := concat($path, '/', $child-resource)
        return
            if (xmldb:get-mime-type(xs:anyURI($path)) = "application/xquery")
            then $path
            else ()
    )
    else ()
};

(:~ given a list of XQuery modules, find which ones are testable :)
declare
    function tst:get-testable-modules(
        $modules as xs:string*
) as xs:string* {
    for $module in $modules
    return
        inspect:inspect-module(xs:anyURI($module))/function/annotation[@namespace="http://exist-db.org/xquery/xqsuite"]
};

(:~ List all available modules that can be tested :)
declare
    %rest:GET
    %rest:path("/api/test")
    %rest:produces("application/xhtml+xml", "text/html")
    %output:method("xhtml")
    function tst:list(
    ) as item()+ {
    let $api-base := api:uri-of("/api/test")
    return
        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
                <title>Tests</title>
            </head>
            <body>
                <ul class="apis">
                    <li class="api">
                        <a class="discovery" href="{$api-base}/run">All tests</a>
                    </li>,
                    {
                        for $module in tst:get-testable-modules(tst:list-xqueries($paths:repo-base))
                        return (
                            <li class="api">
                                <a class="discovery" href="{$api-base}/run?suite={encode-for-uri($module)}">{$module}</a>
                            </li>
                        )
                    }
                </ul>
            </body>
        </html>
};

(:~ Run one or more test suites and return the result as xUnit XML
 :
 : @param $suite The suite(s) to run. If unspecified, will run them all
 : @return xUnit XML corresponding to the tests that were run
 :)
declare
    %rest:GET
    %rest:path("/api/test/run")
    %rest:produces("application/xml", "text/xml")
    %rest:query-param("suite", "{$suites}", "")
    %output:method("xml")
    function tst:run(
        $suites as xs:string*
) as item()+ {
    let $suites-to-run :=
        if (empty($suites))
        then tst:get-testable-modules(tst:list-xqueries($paths:repo-base))
        else $suites
    return
        test:suite(
            for $suite in $suites-to-run
            return inspect:module-functions(xs:anyURI($suite))
        )
};
