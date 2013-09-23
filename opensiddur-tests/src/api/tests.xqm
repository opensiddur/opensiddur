xquery version "3.0";
(:~ tests API
 : Copyright 2013 Efraim Feinstein efraim@opensiddur.org
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : @author Efraim Feinstein
 :)
module namespace tests="http://jewishliturgy.org/api/tests";

import module namespace t="http://exist-db.org/xquery/testing/modified" 
    at "../modules/test2.xqm";
import module namespace api="http://jewishliturgy.org/modules/api"
    at "/db/apps/opensiddur-server/modules/api.xqm";
import module namespace crest="http://jewishliturgy.org/modules/common-rest"
    at "/db/apps/opensiddur-server/modules/common-rest.xqm";

declare namespace expath="http://expath.org/ns/pkg";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare variable $tests:repo-base :=
  let $descriptor := 
    collection(repo:get-root())//expath:package[@name = "http://jewishliturgy.org/apps/opensiddur-tests"]
  return
    util:collection-name($descriptor);
declare variable $tests:path-base := concat($tests:repo-base, "/tests"); 
declare variable $tests:api-path-base := "/api/tests";

declare 
    %rest:GET
    %rest:path("/api/tests")
    %rest:query-param("suite", "{$suite}")
    %rest:query-param("test", "{$test}")
    %rest:produces("application/xhtml+xml", "text/html", "application/xml", "text/xml")
    %output:method("html5")  
    function tests:get(
        $suite as xs:string*,
        $test as xs:string*
    ) as item()+ {
    if (empty($suite))
    then 
        if (empty($test)) 
        then tests:do-list()
        else api:rest-error(400, "The test parameter must specify a suite", $test)
    else 
        if (count($suite) = 1)
        then 
            if (count($test) <= 1) 
            then tests:do-test($suite[1], $test[1])
            else api:rest-error(400, "There can be at most 1 test parameter", $test)
        else api:rest-error(400, "There can be at most 1 suite parameter", $suite)
};

declare function tests:list-function(
    ) as element(TestSuite)* {
    collection($tests:path-base)[ends-with(document-uri(.), ".t.xml")]/TestSuite
};

declare function tests:title-function(
    $doc as document-node()
    ) as xs:string {
    ($doc/TestSuite/suiteName[1]/string(), replace(document-uri($doc), $tests:path-base || "/", "") )[1]
};

declare function tests:do-list(
    ) as item()+ {
    (: this is like crest:list() but different enough that it
     : needs custom code
     :)
    <rest:response>
        <output:serialization-parameters>
            <output:method value="html5"/>
        </output:serialization-parameters>
    </rest:response>,
    <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
            <title>Test API</title>
        </head>
        <body>
            <ul class="results">{
                for $result in tests:list-function()
                let $root := root($result)
                let $api-suite-name := 
                    replace(util:collection-name($root), $tests:path-base, "") || "/" ||
                    replace(util:document-name($root), "\.t\.xml$", "")
                order by document-uri($root) ascending
                return
                    <li class="result">
                        <a class="document" href="{api:uri-of($tests:api-path-base)}?suite={$api-suite-name}">{
                            tests:title-function($root)   
                        }</a>
                    </li>
            }</ul>
        </body>
    </html>
};

(:~ @param $suite is the part of the path after {$tests:path-base} :)
declare function tests:do-test(
    $suite as xs:string,
    $test as xs:string?
    ) as item()+ {
    let $suite-doc := concat($tests:path-base, $suite, ".t.xml") 
    return
        if (exists(doc($suite-doc)))
        then (
            <rest:response>
                <output:serialization-parameters>
                    <output:method value="xml"/>
                </output:serialization-parameters>
            </rest:response>,
            t:format-testResult(
                if ($test)
                then t:run-testSet(doc($suite-doc)//TestSet[TestName=$test], (), ())
                else t:run-testSuite(doc($suite-doc)/TestSuite, (), ())
            )
        )
        else api:rest-error(404, "Not found", $suite)
};
