xquery version "3.1";

module namespace t = "http://test.jewishliturgy.org/modules/data";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace tcommon="http://jewishliturgy.org/test/tcommon" at "../tcommon.xqm";
import module namespace deepequality="http://jewishliturgy.org/modules/deepequality" at "../../modules/deepequality.xqm";

import module namespace data="http://jewishliturgy.org/modules/data" at "../../modules/data.xqm";

import module namespace magic="http://jewishliturgy.org/magic" at "../../magic/magic.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

declare variable $t:year := format-number(year-from-date(current-date()), "0000");
declare variable $t:month := format-number(month-from-date(current-date()), "00");

declare variable $t:resource := "datatest";

declare variable $t:resource-content := document {
<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
   <tei:teiHeader>
      <tei:fileSpec>
         <tei:titleStmt>
            <tei:title>datatest</tei:title>
         </tei:titleStmt>
      </tei:fileSpec>
   </tei:teiHeader>
   <tei:text>
    Empty.
  </tei:text>
</tei:TEI>
};

declare
    %test:setUp
    function t:set-up() {
    let $users := tcommon:setup-test-users(1)
    return ()
};

declare function t:before-each() {
    let $test-resource := tcommon:setup-resource($t:resource, "original", 1,
    $t:resource-content)
    return ()
};

declare function t:after-each() {
    let $test-resource := tcommon:teardown-resource($t:resource, "original", 1)
    return ()
};

declare
    %test:tearDown
    function t:tear-down() {
    let $users := tcommon:teardown-test-users(1)
    return ()
};

declare
    %test:assertEmpty
    function t:db-path-to-api-returns-empty-sequence-in-a-nonexistent-hierarchy() {
    data:db-path-to-api("/db/code/tests/api/data.t.xml")
    };

declare
    %test:assertEquals("/exist/restxq/api/user/xqtest1")
    function t:db-path-to-api-returns-the-path-to-a-user-if-the-user-exists() {
    data:db-path-to-api("/db/data/user/xqtest1")
    };

declare
    %test:assertEmpty
    function t:db-path-to-api-returns-empty-if-a-user-does-not-exist() {
    data:db-path-to-api("/db/data/user/__nope__")
    };

declare
    %test:assertEquals("/exist/restxq/api/data/original/datatest")
    function t:db-path-to-api-returns-the-path-to-a-document-if-the-document-exists() {
    t:before-each(),
    data:db-path-to-api("/db/data/original/" || $t:resource || ".xml"),
    t:after-each()
    };

declare
    %test:assertEmpty
    function t:db-path-to-api-returns-empty-if-a-document-does-not-exist() {
    data:db-path-to-api("/db/data/original/__nope__.xml")
    };

declare
    %test:assertEquals("/db/data/user/xqtest1.xml")
    function t:api-path-to-db-returns-the-db-path-of-a-user-that-exists() {
    data:api-path-to-db("/api/user/xqtest1")
    };

declare
    %test:assertEmpty
    function t:api-path-to-db-returns-empty-when-the-user-does-not-exist() {
    data:api-path-to-db("/api/user/__nope__")
};

declare
    %test:assertEquals("/db/data/original/datatest.xml")
    function t:api-path-to-db-returns-the-db-path-of-a-document-that-exists() {
    t:before-each(),
    data:api-path-to-db("/api/data/original/datatest"),
    t:after-each()
    };

declare
    %test:assertEmpty
    function t:api-path-to-db-returns-empty-when-the-document-does-not-exist() {
    data:api-path-to-db("/api/data/original/__nope__")
};

declare
    %test:assertEmpty
    function t:api-path-to-db-returns-empty-in-an-unsupported-hierarchy() {
    data:api-path-to-db("/api/group/everyone")
};

declare
    %test:assertEmpty
    function t:data-new-path-returns-a-full-path-when-there-is-no-resource-with-the-same-title() {
    let $return := data:new-path("original", "very long test title")
    let $expected := concat(
                             "/db/data/original/", $t:year, "/", $t:month, "/very%20long%20test%20title.xml"
                         )
    where not($return = $expected)
    return <error>Return value is '{$return}' instead of '{$expected}'</error>
};

declare
    %test:assertEmpty
    function t:data-new-path-returns-a-numbered-resource-when-there-is-a-resource-with-the-same-title() {
    t:before-each(),
    let $return := data:new-path("original", "datatest")
    where not($return=concat(
        "/db/data/original/", $t:year, "/", $t:month, "/datatest-1.xml"
    ))
    return <error>Return value is {$return}</error>,
    t:after-each()
};

declare
    %test:assertTrue
    function t:data-doc-returns-a-document-that-exists-by-api-path() {
    t:before-each(),
    exists(data:doc("/api/data/original/datatest")),
    t:after-each()
};

declare
    %test:assertEmpty
    function t:data-doc-returns-empty-for-a-nonexistent-document-by-path() {
        data:doc("/api/data/original/__nope__")
    };