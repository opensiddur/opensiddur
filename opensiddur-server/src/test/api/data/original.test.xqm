xquery version "3.0";

(:~ Tests for original data API
 : Copyright 2020 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)

module namespace t = "http://test.jewishliturgy.org/api/data/original";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

import module namespace orig="http://jewishliturgy.org/api/data/original" at "../../../api/data/original.xqm";

import module namespace tcommon="http://jewishliturgy.org/test/tcommon" at "../../tcommon.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace o="http://a9.com/-/spec/opensearch/1.1/";

declare variable $t:test-original-document-1 :=
  <tei:TEI xml:lang="en">
    { tcommon:minimal-valid-header("testdoc1") }
    <tei:text>
      <j:streamText xml:id="stream">
        <tei:anchor xml:id="a1"/>
        A text
        <tei:anchor xml:id="a2"/>
      </j:streamText>
    </tei:text>
  </tei:TEI>;

declare variable $t:test-original-document-2 :=
  <tei:TEI xml:lang="en">
    { tcommon:minimal-valid-header("testdoc2") }
    <tei:text>
      <j:streamText xml:id="stream">
        <tei:anchor xml:id="b1"/>
        text B
        <tei:anchor xml:id="b2"/>
      </j:streamText>
    </tei:text>
  </tei:TEI>;


declare variable $t:test-linkage-1 :=
  <tei:TEI xml:lang="en">
    { tcommon:minimal-valid-header("linkdoc1") }
    <tei:text>
      <j:parallelText xml:id="parallel">
        <tei:idno>TEST</tei:idno>
        <tei:linkGrp domains="/data/original/testdoc1#stream /data/original/testdoc2#stream">
          <tei:link target="/data/original/testdoc1#range(a1,a2) /data/original/testdoc2#range(b1,b2)"/>
        </tei:linkGrp>
      </j:parallelText>
    </tei:text>
  </tei:TEI>;

declare variable $t:test-linkage-2 :=
  <tei:TEI xml:lang="en">
    { tcommon:minimal-valid-header("linkdoc2") }
    <tei:text>
      <j:parallelText xml:id="parallel">
        <tei:idno>ANOTHER</tei:idno>
        <tei:linkGrp domains="/data/original/testdoc1#stream /data/original/testdoc2#stream">
          <tei:link target="/data/original/testdoc1#range(a1,a2) /data/original/testdoc2#range(b1,b2)"/>
        </tei:linkGrp>
      </j:parallelText>
    </tei:text>
  </tei:TEI>;

declare
  %test:setUp
  function t:setup() {
  (: for this, we need an original document :)
  let $testuser := tcommon:setup-test-users(1)
  let $res1 := tcommon:setup-resource("testdoc1", "original", 1, $t:test-original-document-1)
  let $res2 := tcommon:setup-resource("testdoc2", "original", 1, $t:test-original-document-2)
  let $lnk1 := tcommon:setup-resource("linkdoc1", "linkage", 1, $t:test-linkage-1)
  let $lnk1 := tcommon:setup-resource("linkdoc2", "linkage", 1, $t:test-linkage-2)
  return ()
};

declare
  %test:tearDown
  function t:tear-down() {
  let $lnk1 := tcommon:teardown-resource("linkdoc1", "linkage", 1)
  let $lnk1 := tcommon:teardown-resource("linkdoc2", "linkage", 1)
  let $res1 := tcommon:teardown-resource("testdoc1", "original", 1)
  let $res2 := tcommon:teardown-resource("testdoc2", "original", 1)
  let $testuser := tcommon:teardown-test-users(1)
  return ()
};

declare
  %test:user("xqtest1", "xqtest1")
  %test:assertEmpty
  function t:linkage-query-function-finds-linkage-documents-associated-with-an-original-document() {
  let $original-document := doc("/db/data/original/testdoc1.xml")
  let $linkages := orig:linkage-query-function($original-document, ())
  return
    if (count($linkages) = 2 and $linkages/tei:idno="TEST" and $linkages/tei:idno="ANOTHER")
    then ()
    else <error>{$linkages}</error>
};

declare
  %test:assertEmpty
  function t:linkage-query-function-finds-linkage-documents-associated-with-an-original-document-limited-by-query-string() {
  let $original-document := doc("/db/data/original/testdoc1.xml")
  let $linkages := orig:linkage-query-function($original-document, "TES")
  return
    if (count($linkages) = 1 and $linkages/tei:idno="TEST")
    then ()
    else <error>{$linkages}</error>
};


declare
  %test:assertEquals("TEST")
  function t:linkage-title-function-returns-the-id-of-a-linkage-parallel-group() {
  let $parallelText := $t:test-linkage-1//j:parallelText
  return orig:linkage-title-function($parallelText)
};

declare
  %test:assertTrue
  function t:get-linkage-returns-a-list-of-linkages-and-ids-to-an-original-document() {
  let $linkages := orig:get-linkage("testdoc1", (), 1, 100)
  return count($linkages//html:li[@class="result"])=2
    and (
      every $id in ("TEST", "ANOTHER") satisfies $linkages//html:li[@class="result"]/html:a=$id
    ) and (
      every $link in $linkages//html:li[@class="result"]/html:a satisfies (
        let $expected-link :=
            if ($link = "TEST") then "linkdoc1"
            else if ($link = "ANOTHER") then "linkdoc2"
            else ()
        return
            matches($link/@href, "/api/data/linkage/" || $expected-link || "$")
        )
    )
};
