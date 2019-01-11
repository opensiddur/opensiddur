xquery version "3.0";

module namespace t = "http://test.jewishliturgy.org/api/test";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

import module namespace tst="http://jewishliturgy.org/api/test" at "../../api/test.xqm";

import module namespace magic="http://jewishliturgy.org/magic" at "../../magic/magic.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";

declare
    %test:setUp
    function t:setup() {
    (: save a copy of an XQuery module with tests to a new directory :)
    system:as-user("admin", $magic:password, (
        xmldb:create-collection("/db", "tests"),
        xmldb:create-collection("/db/tests", "recursive"),
        sm:chmod(xs:anyURI("/db/tests"), "rwxrwxrwx"),
        sm:chmod(xs:anyURI("/db/tests/recursive"), "rwxrwxrwx"),
        xmldb:store("/db/tests", "foo.xqm",
                'xquery version "3.1";
                module namespace f="foo";
                declare namespace test="http://exist-db.org/xquery/xqsuite";
                declare %test:assertEquals("foo") function f:foo() {"foo"};',
                "application/xquery"),
        xmldb:store("/db/tests/recursive", "bar.xqm",
                'xquery version "3.1";
                module namespace b="bar";
                declare function b:bar() {"bar"};',
                "application/xquery"),
        xmldb:store("/db/tests", "foobar.xml", <test/>),
        sm:chmod(xs:anyURI("/db/tests/foo.xqm"),"rw-rw-rw-"),
        sm:chmod(xs:anyURI("/db/tests/recursive/bar.xqm"),"rw-rw-rw-"),
        sm:chmod(xs:anyURI("/db/tests/foobar.xml"),"rw-rw-rw-")
    ))
};

declare
    %test:tearDown
    function t:tear-down() {
    system:as-user("admin", $magic:password, (
        xmldb:remove("/db/tests")
    ))
};

declare
    %test:name("Test nonexistent directories, collection recursion, selection for XQueries")
    %test:args("/db/tests")
    %test:assertXPath("count($result) = 2")
    %test:assertXPath("$result = '/db/tests/foo.xqm'")
    %test:assertXPath("$result = '/db/tests/recursive/bar.xqm'")

    %test:args("/db/doesntexist")
    %test:assertEmpty
    function t:test-list-xqueries(
        $collection as xs:string
    ) {
    tst:list-xqueries($collection)
};

declare
    %test:name("Only testable modules are returned")
    %test:arg("modules", "/db/tests/foo.xqm", "/db/tests/recursive/bar.xqm")
    %test:assertXPath("count($result) = 1")
    %test:assertEquals("/db/tests/foo.xqm")

    %test:args("")
    %test:assertEmpty
    function t:test-get-testable-modules(
        $modules as xs:string*
) {
    tst:get-testable-modules($modules[.])
};


declare
    %test:assertTrue
    function t:test-render-html-list-returns-an-html-document() {
    let $modules := ("a.xqm")
    let $rendered := tst:render-html-list("/A/P/I", $modules)
    return $rendered/self::html:html
};

declare
    %test:assertEquals(3)
    function t:test-render-html-list-returns-discovery-links() {
    let $modules := ("a.xqm", "b.xqm")
    let $rendered := tst:render-html-list("/A/P/I", $modules)
    return count($rendered/self::html:html/html:body/html:ul[@class='apis']/html:li[@class='api']/html:a[@class='discovery'][@href])
};

declare
    %test:assertTrue
    function t:test-render-html-list-prepends-api-base() {
    let $modules := ("a.xqm", "b.xqm")
    let $rendered := tst:render-html-list("/A/P/I", $modules)
    return
        every $href in $rendered/self::html:html/html:body/html:ul/html:li/html:a[@class='discovery']/@href
        satisfies starts-with($href, '/A/P/I/run')
};

declare
    %test:assertEquals("All tests", "a.xqm", "b.xqm")
    function t:test-render-html-list-returns-references-to-test-modules() {
    let $modules := ("a.xqm", "b.xqm")
    let $rendered := tst:render-html-list("/A/P/I", $modules)
    return $rendered/self::html:html/html:body/html:ul/html:li/html:a/string()
};
