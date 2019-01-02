xquery version "3.0";

module namespace t = "http://test.jewishliturgy.org/api/test";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

import module namespace paths="http://jewishliturgy.org/modules/paths"
at "../../modules/paths.xqm";
import module namespace tst="http://jewishliturgy.org/api/test" at "../../api/test.xqm";

declare
    %test:setup
    function t:setup() {
    (: save a copy of an XQuery module with tests to a new directory :)
    xmldb:create-collection("/db", "tests"),
    xmldb:copy($paths:repo-base || "/api/test.xqm", "/db/tests")
};

declare
    %test:teardown
    function t:tear-down() {
    xmldb:remove("/api/tests", "test.xqm")
};

declare
    %test:name("tst:list-xqueries() returns an XQuery with tests")
    %test:assertEquals("/db/tests/test.xqm")
    %test:assertXPath("./count() = 1")
    function t:test-list-xqueries-returns-an-xquery-with-tests() {
    tst:list-xqueries("/db/tests")
};
