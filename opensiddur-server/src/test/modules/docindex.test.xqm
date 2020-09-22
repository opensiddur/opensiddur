xquery version "3.1";

module namespace t = "http://test.jewishliturgy.org/modules/data";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace tcommon="http://jewishliturgy.org/test/tcommon" at "../tcommon.xqm";
import module namespace deepequality="http://jewishliturgy.org/modules/deepequality" at "../../modules/deepequality.xqm";

import module namespace didx="http://jewishliturgy.org/modules/docindex" at "../../modules/didx.xqm";

import module namespace magic="http://jewishliturgy.org/magic" at "../../magic/magic.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

declare
    %test:setUp
    function t:set-up() {
    let $users := tcommon:setup-test-users(1)
    return ()
    };

declare
    %test:tearDown
    function t:tear-down() {
    let $users := tcommon:teardown-test-users(1)
    return ()
    };

declare function t:before-each() {
    let $document := tcommon:setup-resource("test_docindex", "original", 1, <test/>)
    return ()
};

declare function t:after-each() {
    let $document := tcommon:teardown-resource("test-docindex", "original", 1)
    return ()
};

declare function t:the-test-document-was-indexed(
) {
    t:the-test-document-was-indexed(
    doc($didx:didx-path || "/" || $didx:didx-resource)//didx:entry[@db-path="/db/data/original/test_docindex.xml"])
};

declare function t:the-test-document-was-indexed(
    $expected as element()?
    ) as element()? {
    if (empty($expected))
    then <error>The test document was not indexed</error>
    else if (count($expected) > 1)
    then <error>The test document was indexed more than once</error>
    else if (not($expected/@resource="test_docindex"))
    then <error>Resource was recorded incorrectly</error>
    else if (not($expected/@data-type="original"))
    then <error>Data type was recorded incorrectly</error>
    else if (not($expected/@document-name="test_docindex.xqm"))
    then <error>Document name was recorded incorrectly</error>
    else ()
};

declare
    %test:assertEmpty
    function t:setup-ran-at-startup() {
    (
        t:before-each(),
        if (xmldb:collection-available($didx:didx-path))
        then ()
        else <error>Document index collection {$didx:didx-path} does not exist</error>,
        if (exists(doc($didx:didx-path || "/" || $didx:didx-resource)))
        then ()
        else <error>Document index file does not exist</error>,
        t:the-test-document-was-indexed(),
        t:after-each()
    )
    };

declare
    %test:assertEmpty
    function t:reindexing-an-existing-document-does-not-add-an-additional-entry() {
        t:before-each(),
        let $test := didx:reindex("/db/data/original", "test_docindex.xqm")
        return t:the-test-document-was-indexed(),
        t:after-each()
    };

declare
    %test:assertEmpty
    function t:remove-deletes-the-entry-from-the-index() {
    t:before-each(),
    let $removed := didx:remove("/db/data/original", "test_docindex.xqm")
    where exists(doc($didx:didx-path || "/" || $didx:didx-resource)//didx:entry[@db-path="/db/data/original/test_docindex.xml"])
    return <error>The index entry was not removed</error>,
    t:after-each()
    };

declare
    %test:assertEmpty
    function t:query-path-returns-a-result-for-an-existing-path() {
    t:before-each(),
    let $query := didx:query-path("original", "test_docindex")
    return
        if (count($query) != 1)
        then  <error>query-path returned {count($query)} results</error>
        else if (not($query = "/db/data/original/test_docindex.xqm" ))
        then <error>The query returned '{$query}' instead of the expected result</error>
        else (),
    t:after-each()
    };

declare
    %test:assertEmpty
    function t:query-path-returns-empty-for-nonexisting-path() {
    let $query := didx:query-path("original", "nonexistent_docindex_entry")
    where exists($query)
    return <error>query-path returned a spurious entry</error>
    };

declare
    %test:assertEmpty
    function t:query-by-path-returns-a-result-for-an-existing-path() {
    t:before-each(),
    let $query := didx:query-by-path("/db/data/original/test_docindex.xml")
    return
        if (count($query) != 1)
        then  <error>query-by-path returned {count($query)} results</error>
        else t:the-test-document-was-indexed($query),
    t:after-each()
    };

declare
    %test:assertEmpty
    function t:query-by-path-returns-no-result-for-a-nonexisting-path() {
    let $query := didx:query-by-path("/db/data/original/test_docindex_does_not_exist.xml")
    where exists($query)
    return <error>query-by-path returned a spurious entry</error>
    };
