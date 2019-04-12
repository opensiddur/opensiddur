xquery version "3.1";

module namespace t = "http://test.jewishliturgy.org/transforms/flatten";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

import module namespace magic="http://jewishliturgy.org/magic"
at "../../magic/magic.xqm";

import module namespace flatten="http://jewishliturgy.org/transform/flatten"
  at "../../transforms/flatten.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "../../modules/format.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "../modules/refindex.xqm";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace deepequality="http://jewishliturgy.org/modules/deepequality" at "../../modules/deepequality.xqm";

declare
  %test:setUp
  function t:setup() {
  let $tests-collection :=
    system:as-user("admin", $magic:password, (
      xmldb:create-collection("/db/data", "tests"),
      sm:chmod(xs:anyURI("/db/data/tests"), "rwxrwxrwx")
    ))
  return ()
};

declare
  %test:tearDown
  function t:tear-down() {
  xmldb:remove("/db/data/tests")
};

declare %private function t:setup-resource(
  $resource-name as xs:string,
  $content as item()
) as xs:string {
  let $name := xmldb:store("/db/data/tests", $resource-name, $content)
  let $ridx := ridx:reindex(doc($name))
  let $segmented := format:segment(doc($name), map {}, doc($name))
  return $name
};

declare %private function t:teardown-resource(
  $resource-name as xs:string
) {
  let $test-collection := "/db/data/tests"
  return (
    format:clear-caches($test-collection || "/" || $resource-name),
    xmldb:remove($test-collection, $resource-name)
  )
};

declare
  %test:name("flatten-document() without concurrency acts as an identity transform except streamText has a jf:id")
  %test:assertEmpty
  function t:test-no-concurrency() {
  let $test-doc-name := "identity.xml"
  let $setup := t:setup-resource($test-doc-name,
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <tei:seg xml:id="seg1">No layers!</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  )
  let $expected := document {
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
        jf:id="...">
          <tei:seg xml:id="seg1">No layers!</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  }
  let $test := flatten:flatten-document(doc($setup), map {})
  let $result := deepequality:equal-or-result($test, $expected)
  let $teardown := t:teardown-resource($test-doc-name)
  return $result
};

declare
  %test:name("flatten-document() with simple concurrency changes a pointer to a placeholder")
  %test:assertEmpty
  function t:test-simple-concurrency() {
  let $test-doc-name := "simple-concurrency.xml"
  let $setup := t:setup-resource($test-doc-name,
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <j:layer type="div" xml:id="div-layer">
            <tei:div xml:id="div1">
              <tei:ptr target="#seg1"/>
            </tei:div>
          </j:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="stream">
          <tei:seg xml:id="seg1">No layers!</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  )
  let $expected := document {
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <jf:layer xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" type="div"
          jf:id="div-layer"
          jf:layer-id="/data/tests/simple-concurrency#div-layer">
            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/simple-concurrency#div-layer"
            jf:id="div1"/>
            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
            jf:nprecedents="0"
            jf:stream="/data/tests/simple-concurrency#stream"
            jf:id="seg1"/>
            <tei:div jf:end="div1" jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/simple-concurrency#div-layer"/>
          </jf:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
        jf:id="stream">
          <tei:seg xml:id="seg1">No layers!</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  }
  let $test := flatten:flatten-document(doc($setup), map {})
  let $result := deepequality:equal-or-result($test, $expected)
  let $teardown := t:teardown-resource($test-doc-name)
  return $result
};

declare
  %test:name("flatten-document() with concurrent hierarchies with inline elements, no child elements")
  %test:assertXPath("not($result/self::error)")
  %test:assertXPath("$result//*:ab[@*:start]/@*:start=$result//*:ab[@*:end]/@*:end")
  function t:test-inline-no-children() {
  let $test-doc-name := "inline.xml"
  let $setup := t:setup-resource($test-doc-name,
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <j:layer type="div" xml:id="div-layer">
            <tei:div xml:id="div1">
              <tei:head>title</tei:head>
              <tei:ab>
                <tei:label>Label</tei:label>
                <tei:ptr target="#seg1"/>
              </tei:ab>
            </tei:div>
          </j:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  )
  let $expected := document {
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <jf:layer xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" type="div"
          jf:id="div-layer"
          jf:layer-id="/data/tests/inline#div-layer">
            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/inline#div-layer"
            jf:id="div1"/>
            <tei:head jf:position="1" jf:relative="-1" jf:nchildren="-1" jf:nlevels="2"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/inline#div-layer">title</tei:head>
            <tei:ab jf:start="..." jf:position="1" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="2"
            jf:nprecedents="2"
            jf:layer-id="/data/tests/inline#div-layer"/>
            <tei:label jf:position="1" jf:relative="-1" jf:nchildren="-1" jf:nlevels="3"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/inline#div-layer">Label</tei:label>
            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
            jf:nprecedents="0"
            jf:stream="/data/tests/inline#stream"
            jf:id="seg1"/>
            <tei:ab jf:end="..." jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
            jf:nprecedents="2"
            jf:layer-id="/data/tests/inline#div-layer"/>
            <tei:div jf:end="div1" jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/inline#div-layer"/>
          </jf:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
        jf:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  }
  let $test := flatten:flatten-document(doc($setup), map {})
  let $result := deepequality:equal-or-error($test, $expected)
  let $teardown := t:teardown-resource($test-doc-name)
  return $result
};

declare
  %test:name("flatten-document() with concurrent hierarchies with two inline elements in a row")
  %test:assertXPath("not($result/self::error)")
  function t:test-inline-two-labels() {
  let $test-doc-name := "inline.xml"
  let $setup := t:setup-resource($test-doc-name,
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <j:layer type="div" xml:id="div-layer">
            <tei:div xml:id="div1">
              <tei:head>title</tei:head>
              <tei:ab>
                <tei:label>Label 1</tei:label>
                <tei:label>Label 2</tei:label>
                <tei:ptr target="#seg1"/>
              </tei:ab>
            </tei:div>
          </j:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  )
  let $expected-label-1 :=
    <tei:label xmlns:tei="http://www.tei-c.org/ns/1.0"
      xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
      jf:position="1"
      jf:relative="-1"
      jf:nchildren="-1"
      jf:nlevels="3"
      jf:nprecedents="1"
      jf:layer-id="/data/tests/inline#div-layer">Label 1</tei:label>
  let $expected-label-2 :=
    <tei:label xmlns:tei="http://www.tei-c.org/ns/1.0"
      xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
      jf:position="1"
      jf:relative="-1"
      jf:nchildren="-1"
      jf:nlevels="3"
      jf:nprecedents="2"
      jf:layer-id="/data/tests/inline#div-layer">Label 2</tei:label>
  let $test := flatten:flatten-document(doc($setup), map {})
  let $result-1 := deepequality:equal-or-error($test//tei:label[1], $expected-label-1)
  let $result-2 := deepequality:equal-or-error($test//tei:label[2], $expected-label-2)
  let $teardown := t:teardown-resource($test-doc-name)
  return $result-1 | $result-2
};

declare
  %test:name("flatten-document() with concurrent hierarchies with two inline elements, second follows a ptr")
  %test:assertXPath("not($result/self::error)")
  function t:test-inline-two-labels-separated-by-pointer() {
  let $test-doc-name := "inline.xml"
  let $setup := t:setup-resource($test-doc-name,
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <j:layer type="div" xml:id="div-layer">
            <tei:div xml:id="div1">
              <tei:head>title</tei:head>
              <tei:ab>
                <tei:label>Label 1</tei:label>
                <tei:ptr target="#seg1"/>
                <tei:label>Label 2</tei:label>
              </tei:ab>
            </tei:div>
          </j:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  )
  let $expected-label-1 :=
    <tei:label xmlns:tei="http://www.tei-c.org/ns/1.0"
      xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
      jf:position="1"
      jf:relative="-1"
      jf:nchildren="-1"
      jf:nlevels="3"
      jf:nprecedents="1"
      jf:layer-id="/data/tests/inline#div-layer">Label 1</tei:label>
  let $expected-label-2 :=
    <tei:label xmlns:tei="http://www.tei-c.org/ns/1.0"
      xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
      jf:position="1"
      jf:relative="1"
      jf:nchildren="1"
      jf:nlevels="-3"
      jf:nprecedents="3"
      jf:layer-id="/data/tests/inline#div-layer">Label 2</tei:label>
  let $test := flatten:flatten-document(doc($setup), map {})
  let $result-1 := deepequality:equal-or-error($test//tei:label[1], $expected-label-1)
  let $result-2 := deepequality:equal-or-error($test//tei:label[2], $expected-label-2)
  let $teardown := t:teardown-resource($test-doc-name)
  return $result-1 | $result-2
};

declare
  %test:name("flatten-document() with pointers and labels")
  %test:assertEmpty
  function t:test-two-pointers-and-labels() {
  let $test-doc-name := "inline.xml"
  let $setup := t:setup-resource($test-doc-name,
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <j:layer type="div" xml:id="div-layer">
            <tei:div xml:id="div1">
              <tei:head>title</tei:head>
              <tei:ab>
                <tei:label>Label 1</tei:label>
                <tei:ptr target="#seg1"/>
                <tei:label>Label 2</tei:label>
                <tei:ptr target="#seg2"/>
                <tei:label>Label 3</tei:label>
              </tei:ab>
              <tei:label>Label 4</tei:label>
            </tei:div>
          </j:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
          <tei:seg xml:id="seg2">Two segments</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  )
  let $expected := document {
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <jf:layer xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" type="div"
          jf:id="div-layer"
          jf:layer-id="/data/tests/inline#div-layer">
            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-2"
            jf:nlevels="1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/inline#div-layer"
            jf:id="div1"/>
            <tei:head jf:position="1" jf:relative="-1" jf:nchildren="-2" jf:nlevels="2"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/inline#div-layer">title</tei:head>
            <tei:ab jf:start="..." jf:position="1" jf:relative="-1" jf:nchildren="-2"
            jf:nlevels="2"
            jf:nprecedents="2"
            jf:layer-id="/data/tests/inline#div-layer"/>
            <tei:label jf:position="1" jf:relative="-1" jf:nchildren="-2" jf:nlevels="3"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/inline#div-layer">Label 1</tei:label>
            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
            jf:nprecedents="0"
            jf:stream="/data/tests/inline#stream"
            jf:id="seg1"/>
            <tei:label jf:position="1" jf:relative="1" jf:nchildren="2" jf:nlevels="-3"
            jf:nprecedents="3"
            jf:layer-id="/data/tests/inline#div-layer">Label 2</tei:label>
            <jf:placeholder jf:position="2" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
            jf:nprecedents="0"
            jf:stream="/data/tests/inline#stream"
            jf:id="seg2"/>
            <tei:label jf:position="2" jf:relative="1" jf:nchildren="2" jf:nlevels="-3"
            jf:nprecedents="5"
            jf:layer-id="/data/tests/inline#div-layer">Label 3</tei:label>
            <tei:ab jf:end="..." jf:position="2" jf:relative="1" jf:nchildren="2" jf:nlevels="-2"
            jf:nprecedents="2"
            jf:layer-id="/data/tests/inline#div-layer"/>
            <tei:label jf:position="2" jf:relative="1" jf:nchildren="2" jf:nlevels="-2"
            jf:nprecedents="3"
            jf:layer-id="/data/tests/inline#div-layer">Label 4</tei:label>
            <tei:div jf:end="div1" jf:position="2" jf:relative="1" jf:nchildren="2" jf:nlevels="-1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/inline#div-layer"/>
          </jf:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
        jf:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
          <tei:seg xml:id="seg2">Two segments</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  }
  let $test := flatten:flatten-document(doc($setup), map {})
  let $result := deepequality:equal-or-result($test, $expected)
  let $teardown := t:teardown-resource($test-doc-name)
  return $result
};

declare
  %test:name("flatten-document() with two level suspend and continue")
  %test:assertEmpty
  function t:test-two-level-suspend-and-continue() {
  let $test-doc-name := "suspend.xml"
  let $setup := t:setup-resource($test-doc-name,
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <j:layer type="div" xml:id="div-layer">
            <tei:div xml:id="div1">
              <tei:ab xml:id="ab1">
                <tei:ptr target="#seg1"/>
                <tei:ptr target="#seg3"/>
              </tei:ab>
            </tei:div>
          </j:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
          <tei:seg xml:id="seg2">Two segments</tei:seg>
          <tei:seg xml:id="seg3">Three segments</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  )
  let $expected := document {
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <jf:layer xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" type="div"
          jf:id="div-layer"
          jf:layer-id="/data/tests/suspend#div-layer">
            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"
            jf:id="div1"/>
            <tei:ab jf:start="ab1" jf:id="ab1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="2"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
            jf:nprecedents="0"
            jf:stream="/data/tests/suspend#stream"
            jf:id="seg1"/>
            <tei:ab jf:suspend="ab1" jf:position="1" jf:relative="1" jf:nchildren="1"
            jf:nlevels="-2"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <tei:div jf:suspend="div1" jf:position="1" jf:relative="1" jf:nchildren="1"
            jf:nlevels="-1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <tei:div jf:continue="div1" jf:position="3" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <tei:ab jf:continue="ab1" jf:position="3" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="2"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <jf:placeholder jf:position="3" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
            jf:nprecedents="0"
            jf:stream="/data/tests/suspend#stream"
            jf:id="seg3"/>
            <tei:ab jf:end="ab1" jf:position="3" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <tei:div jf:end="div1" jf:position="3" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
          </jf:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
        jf:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
          <tei:seg xml:id="seg2">Two segments</tei:seg>
          <tei:seg xml:id="seg3">Three segments</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  }
  let $test := flatten:flatten-document(doc($setup), map {})
  let $result := deepequality:equal-or-result($test, $expected)
  let $teardown := t:teardown-resource($test-doc-name)
  return $result
};

declare
  %test:name("flatten-document() with suspend and continue with labels")
  %test:assertEmpty
  function t:test-suspend-and-continue-with-inline() {
  let $test-doc-name := "suspend.xml"
  let $setup := t:setup-resource($test-doc-name,
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <j:layer type="div" xml:id="div-layer">
            <tei:div xml:id="div1">
              <tei:label xml:id="lbl1">before</tei:label>
              <tei:ptr target="#seg1"/>
              <tei:label xml:id="lbl2">after 1</tei:label>
              <tei:ptr target="#seg3"/>
              <tei:label xml:id="lbl3">after 3</tei:label>
            </tei:div>
          </j:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
          <tei:seg xml:id="seg2">Two segments</tei:seg>
          <tei:seg xml:id="seg3">Three segments</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  )
  let $expected := document {
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <jf:layer xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" type="div"
          jf:id="div-layer"
          jf:layer-id="/data/tests/suspend#div-layer">
            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"
            jf:id="div1"/>
            <tei:label jf:id="lbl1" jf:position="1" jf:relative="-1" jf:nchildren="-1" jf:nlevels="2"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer">before</tei:label>
            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
            jf:nprecedents="0"
            jf:stream="/data/tests/suspend#stream"
            jf:id="seg1"/>
            <tei:label jf:id="lbl2" jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
            jf:nprecedents="3"
            jf:layer-id="/data/tests/suspend#div-layer">after 1</tei:label>
            <tei:div jf:suspend="div1" jf:position="1" jf:relative="1" jf:nchildren="1"
            jf:nlevels="-1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <tei:div jf:continue="div1" jf:position="3" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <jf:placeholder jf:position="3" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
            jf:nprecedents="0"
            jf:stream="/data/tests/suspend#stream"
            jf:id="seg3"/>
            <tei:label jf:id="lbl3" jf:position="3" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
            jf:nprecedents="5"
            jf:layer-id="/data/tests/suspend#div-layer">after 3</tei:label>
            <tei:div jf:end="div1" jf:position="3" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
          </jf:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
        jf:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
          <tei:seg xml:id="seg2">Two segments</tei:seg>
          <tei:seg xml:id="seg3">Three segments</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  }
  let $test := flatten:flatten-document(doc($setup), map {})
  let $result := deepequality:equal-or-result($test, $expected)
  let $teardown := t:teardown-resource($test-doc-name)
  return $result
};

declare
  %test:name("flatten-document() with multi-level suspend and continue with unequal numbers of levels")
  %test:assertEmpty
  function t:test-multi-level-suspend-and-continue-with-unequal-levels() {
  let $test-doc-name := "suspend.xml"
  let $setup := t:setup-resource($test-doc-name,
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <j:layer type="div" xml:id="div-layer">
            <tei:div xml:id="div1">
              <tei:ab xml:id="ab1">
                <tei:ptr target="#seg1"/>
              </tei:ab>
              <tei:ptr target="#seg3"/>
            </tei:div>
          </j:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
          <tei:seg xml:id="seg2">Two segments</tei:seg>
          <tei:seg xml:id="seg3">Three segments</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  )
  let $expected := document {
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <jf:layer xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" type="div"
          jf:id="div-layer"
          jf:layer-id="/data/tests/suspend#div-layer">
            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"
            jf:id="div1"/>
            <tei:ab jf:start="ab1" jf:id="ab1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="2"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
            jf:nprecedents="0"
            jf:stream="/data/tests/suspend#stream"
            jf:id="seg1"/>
            <tei:ab jf:end="ab1" jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <tei:div jf:suspend="div1" jf:position="1" jf:relative="1" jf:nchildren="1"
            jf:nlevels="-1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <tei:div jf:continue="div1" jf:position="3" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <jf:placeholder jf:position="3" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
            jf:nprecedents="0"
            jf:stream="/data/tests/suspend#stream"
            jf:id="seg3"/>
            <tei:div jf:end="div1" jf:position="3" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
          </jf:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
        jf:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
          <tei:seg xml:id="seg2">Two segments</tei:seg>
          <tei:seg xml:id="seg3">Three segments</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  }
  let $test := flatten:flatten-document(doc($setup), map {})
  let $result := deepequality:equal-or-result($test, $expected)
  let $teardown := t:teardown-resource($test-doc-name)
  return $result
};

declare
  %test:name("flatten-document() with multi-level suspend and continue with end and start at the suspend position")
  %test:assertEmpty
  function t:test-multi-level-suspend-and-continue-with-end-and-start-at-suspend() {
  let $test-doc-name := "suspend.xml"
  let $setup := t:setup-resource($test-doc-name,
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <j:layer type="div" xml:id="div-layer">
            <tei:div xml:id="div1">
              <tei:ab xml:id="ab1">
                <tei:ptr target="#seg1"/>
              </tei:ab>
              <tei:ab xml:id="ab2">
                <tei:ptr target="#seg3"/>
              </tei:ab>
            </tei:div>
          </j:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
          <tei:seg xml:id="seg2">Two segments</tei:seg>
          <tei:seg xml:id="seg3">Three segments</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  )
  let $expected := document {
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <jf:layer xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" type="div"
          jf:id="div-layer"
          jf:layer-id="/data/tests/suspend#div-layer">
            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"
            jf:id="div1"/>
            <tei:ab jf:start="ab1" jf:id="ab1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="2"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
            jf:nprecedents="0"
            jf:stream="/data/tests/suspend#stream"
            jf:id="seg1"/>
            <tei:ab jf:end="ab1" jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <tei:div jf:suspend="div1" jf:position="1" jf:relative="1" jf:nchildren="1"
            jf:nlevels="-1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <tei:div jf:continue="div1" jf:position="3" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <tei:ab jf:start="ab2" jf:id="ab2" jf:position="3" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="2"
            jf:nprecedents="2"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <jf:placeholder jf:position="3" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
            jf:nprecedents="0"
            jf:stream="/data/tests/suspend#stream"
            jf:id="seg3"/>
            <tei:ab jf:end="ab2" jf:position="3" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
            jf:nprecedents="2"
            jf:layer-id="/data/tests/suspend#div-layer"/>
            <tei:div jf:end="div1" jf:position="3" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
            jf:nprecedents="1"
            jf:layer-id="/data/tests/suspend#div-layer"/>
          </jf:layer>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
        jf:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
          <tei:seg xml:id="seg2">Two segments</tei:seg>
          <tei:seg xml:id="seg3">Three segments</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  }
  let $test := flatten:flatten-document(doc($setup), map {})
  let $result := deepequality:equal-or-result($test, $expected)
  let $teardown := t:teardown-resource($test-doc-name)
  return $result
};

declare
  %test:name("resolve-stream() placeholders are replaced by stream elements")
  %test:assertEmpty
  function t:test-resolve-stream() {
  let $test-doc-name := "resolve.xml"
  let $setup := t:setup-resource($test-doc-name,
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <jf:merged xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0">
            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="1"
            jf:nprecedents="1"
            jf:layer-id="div-layer"
            jf:id="div1"/>
            <tei:head jf:position="1" jf:relative="-1" jf:nchildren="-1" jf:nlevels="2"
            jf:nprecedents="1"
            jf:layer-id="div-layer">title</tei:head>
            <tei:ab jf:start="..." jf:position="1" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="2"
            jf:nprecedents="2"
            jf:layer-id="div-layer"/>
            <tei:label jf:position="1" jf:relative="-1" jf:nchildren="-1" jf:nlevels="3"
            jf:nprecedents="1"
            jf:layer-id="div-layer">Label</tei:label>
            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
            jf:nprecedents="0"
            jf:stream="stream"
            jf:id="seg1"/>
            <tei:ab jf:end="..." jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
            jf:nprecedents="2"
            jf:layer-id="div-layer"/>
            <tei:div jf:end="div1" jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
            jf:nprecedents="1"
            jf:layer-id="div-layer"/>
          </jf:merged>
        </j:concurrent>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="stream">
          <tei:seg xml:id="seg1">One segment</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  )
  let $expected := document {
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <!-- leaving it blank... -->
      </tei:teiHeader>
      <tei:text>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <jf:merged xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0">
            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="1"
            jf:nprecedents="1"
            jf:layer-id="div-layer"
            jf:id="div1"/>
            <tei:head jf:position="1" jf:relative="-1" jf:nchildren="-1" jf:nlevels="2"
            jf:nprecedents="1"
            jf:layer-id="div-layer">title</tei:head>
            <tei:ab jf:start="..." jf:position="1" jf:relative="-1" jf:nchildren="-1"
            jf:nlevels="2"
            jf:nprecedents="2"
            jf:layer-id="div-layer"/>
            <tei:label jf:position="1" jf:relative="-1" jf:nchildren="-1" jf:nlevels="3"
            jf:nprecedents="1"
            jf:layer-id="div-layer">Label</tei:label>
            <tei:seg jf:id="seg1" jf:stream="stream">One segment</tei:seg>
            <tei:ab jf:end="..." jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
            jf:nprecedents="2"
            jf:layer-id="div-layer"/>
            <tei:div jf:end="div1" jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
            jf:nprecedents="1"
            jf:layer-id="div-layer"/>
          </jf:merged>
        </j:concurrent>
      </tei:text>
    </tei:TEI>
  }
  let $test := flatten:resolve-stream(doc($setup), map {})
  let $result := deepequality:equal-or-result($test, $expected)
  let $teardown := t:teardown-resource($test-doc-name)
  return $result
};

declare %private function t:setup-parallel() {
  let $linkage-document := "flatten-par.xml"
  let $parallel-document-1 := "flatten-parA.xml"
  let $parallel-document-2 := "flatten-parB.xml"
  let $setup-parallel-document-1 := t:setup-resource($parallel-document-1,
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <tei:fileDesc>
          <tei:titleStmt>
            <tei:title type="main">Parallel text A</tei:title>
          </tei:titleStmt>
          <tei:publicationStmt>
            <tei:distributor>
              <tei:ref target="http://opensiddur.org">Open Siddur Project</tei:ref>
            </tei:distributor>
            <tei:availability>
              <tei:licence target="http://www.creativecommons.org/publicdomain/zero/1.0"/>
            </tei:availability>
            <tei:date>2014-03-19</tei:date>
          </tei:publicationStmt>
          <tei:sourceDesc>
            <tei:bibl>
              <tei:ptr type="bibl" target="/data/sources/Born%20Digital"/>
              <tei:ptr type="bibl-content" target="#stream"/>
            </tei:bibl>
          </tei:sourceDesc>
        </tei:fileDesc>
        <tei:revisionDesc>
        </tei:revisionDesc>
      </tei:teiHeader>
      <tei:text>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="stream">
          <tei:seg xml:id="A1">A-1</tei:seg>
          <tei:seg xml:id="A2">A-2</tei:seg>
          <tei:seg xml:id="A3">A-3</tei:seg>
          <tei:seg xml:id="A4">A-4</tei:seg>
          <tei:seg xml:id="A5">A-5</tei:seg>
          <tei:seg xml:id="A6">A-6</tei:seg>
          <tei:seg xml:id="A7">A-7</tei:seg>
          <tei:seg xml:id="A8">A-8</tei:seg>
          <tei:seg xml:id="A9">A-9</tei:seg>
        </j:streamText>
      </tei:text>
    </tei:TEI>
  )
  let $setup-parallel-document-2 := t:setup-resource($parallel-document-2,
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <tei:fileDesc>
          <tei:titleStmt>
            <tei:title type="main">Parallel text B</tei:title>
          </tei:titleStmt>
          <tei:publicationStmt>
            <tei:distributor>
              <tei:ref target="http://opensiddur.org">Open Siddur Project</tei:ref>
            </tei:distributor>
            <tei:availability>
              <tei:licence target="http://www.creativecommons.org/publicdomain/zero/1.0"/>
            </tei:availability>
            <tei:date>2014-03-19</tei:date>
          </tei:publicationStmt>
          <tei:sourceDesc>
            <tei:bibl>
              <tei:ptr type="bibl" target="/data/sources/Born%20Digital"/>
              <tei:ptr type="bibl-content" target="#stream"/>
            </tei:bibl>
          </tei:sourceDesc>
        </tei:fileDesc>
        <tei:revisionDesc>
        </tei:revisionDesc>
      </tei:teiHeader>
      <tei:text>
        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="stream">
          <tei:seg xml:id="A1">B-1</tei:seg>
          <tei:seg xml:id="A2">B-2</tei:seg>
          <tei:seg xml:id="A3">B-3</tei:seg>
          <tei:seg xml:id="A4">B-4</tei:seg>
          <tei:seg xml:id="A5">B-5</tei:seg>
          <tei:seg xml:id="A6">B-6</tei:seg>
          <tei:seg xml:id="A7">B-7</tei:seg>
          <tei:seg xml:id="A8">B-8</tei:seg>
          <tei:seg xml:id="A9">B-9</tei:seg>
        </j:streamText>
        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
          <j:layer type="p">
            <tei:p>
              <tei:ptr target="#range(A1,A9)"/>
            </tei:p>
          </j:layer>
        </j:concurrent>
      </tei:text>
    </tei:TEI>
  )
  let $setup-linkage-document := t:setup-resource($linkage-document,
    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
      <tei:teiHeader>
        <tei:fileDesc>
          <tei:titleStmt>
            <tei:title type="main">Parallel texts A and B</tei:title>
          </tei:titleStmt>
          <tei:publicationStmt>
            <tei:distributor>
              <tei:ref target="http://opensiddur.org">Open Siddur Project</tei:ref>
            </tei:distributor>
            <tei:availability>
              <tei:licence target="http://www.creativecommons.org/publicdomain/zero/1.0"/>
            </tei:availability>
            <tei:date>2014-03-19</tei:date>
          </tei:publicationStmt>
          <tei:sourceDesc>
            <tei:bibl>
              <tei:ptr type="bibl" target="/data/sources/Born%20Digital"/>
              <tei:ptr type="bibl-content" target="#parallel"/>
            </tei:bibl>
          </tei:sourceDesc>
        </tei:fileDesc>
        <tei:revisionDesc>
        </tei:revisionDesc>
      </tei:teiHeader>
      <tei:text>
        <j:parallelText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="parallel">
          <tei:idno>Test</tei:idno>
          <tei:linkGrp domains="/data/tests/flatten-parA#stream /data/tests/flatten-parB#stream">
            <!-- A-1 is not part of the parallelism -->
            <!-- link without range -->
            <tei:link target="/data/tests/flatten-parA#A2 /data/tests/flatten-parB#A1"/>
            <!-- link with range, same size -->
            <tei:link target="/data/tests/flatten-parA#range(A3,A5) /data/tests/flatten-parB#range(A2,A4)"/>
            <!-- skip both A#A6 and B#A5 -->
            <!-- link with range, different sizes -->
            <tei:link target="/data/tests/flatten-parA#range(A7,A8) /data/tests/flatten-parB#range(A6,A8)"/>
            <!-- A9 and B9 are not part of the parallelism -->
          </tei:linkGrp>
        </j:parallelText>
      </tei:text>
    </tei:TEI>
  )
  return (
    $setup-linkage-document,
    $setup-parallel-document-1,
    $setup-parallel-document-2
  )
};

declare %private function t:teardown-parallel() {
  let $linkage-document := "flatten-par.xml"
  let $parallel-document-1 := "flatten-parA.xml"
  let $parallel-document-2 := "flatten-parB.xml"
  return (
    t:teardown-resource($linkage-document),
    t:teardown-resource($parallel-document-1),
    t:teardown-resource($parallel-document-2)
  )
};

(: NOTE: there is a bug in eXist which causes an NPE in format:flatten() when it references a partial function
 : but the bug only manifests while we are running XQSuite. When it is fixed, these tests should be set to active :)
declare
  %test:pending
  %test:name("flatten a parallel document")
  %test:assertEmpty
  function t:test-flatten-a-parallel-document() {
  let $setup := t:setup-parallel()
  let $linkage-document := $setup[1]
  let $null := util:log("info", ("***setup complete running flatten test for ", $linkage-document))
  let $test :=
    let $d := doc($linkage-document)
    return format:flatten($d, map {}, $d)
  let $results := $test/(
    <results>
      <xpath desc="parA reproduces its own streamText">{.//tei:TEI[contains(@jf:document, '/flatten-parA')]//j:streamText/tei:seg[@jf:id="A1"]="A-1"}</xpath>
      <xpath desc="parA has 1 flattened parallel layer">{exists(.//tei:TEI[contains(@jf:document, '/flatten-parA')]//j:concurrent[count(jf:layer)=1]/jf:layer[@type="parallel"])}</xpath>
      <xpath desc="parA layer has flattened parallelGrps">{exists(.//tei:TEI[contains(@jf:document, '/flatten-parA')]//j:concurrent/jf:layer[@type="parallel"][count(jf:parallelGrp[@jf:start])=3][count(jf:parallel[@jf:start])=3][count(jf:placeholder[@jf:stream="/data/tests/flatten-parA#stream"])=6])}</xpath>
      <xpath desc="parA layer placeholders point to their segs">{every $ph in .//tei:TEI[contains(@jf:document, '/flatten-parA')]//j:concurrent/jf:layer[@type="parallel"]/jf:placeholder satisfies starts-with($ph/@jf:id, "A")}</xpath>
      <xpath desc="parB reproduces its own streamText">{.//tei:TEI[contains(@jf:document, '/flatten-parB')]//j:streamText/tei:seg[@jf:id="A1"]="B-1"}</xpath>
      <xpath desc="parB has 1 flattened parallel layer and 2 flattened layers">{exists(.//tei:TEI[contains(@jf:document, '/flatten-parB')]//j:concurrent[count(jf:layer)=2]/jf:layer[@type="parallel"])}</xpath>
      <xpath desc="one parB layer has flattened parallelGrps">{exists(.//tei:TEI[contains(@jf:document, '/flatten-parB')]//j:concurrent/jf:layer[@type="parallel"][count(jf:parallelGrp[@jf:start])=3][count(jf:parallel[@jf:start])=3][count(jf:placeholder[@jf:stream="/data/tests/flatten-parB#stream"])=7])}</xpath>
      <xpath desc="one parB layer has flattened paragraphs">{exists(.//tei:TEI[contains(@jf:document, '/flatten-parB')]//j:concurrent/jf:layer[@type="p"][count(tei:p[@jf:start])=1][count(jf:placeholder[@jf:stream="/data/tests/flatten-parB#stream"])=9])}</xpath>
      <xpath desc="parB layer placeholders point to their segs">{every $ph in .//tei:TEI[contains(@jf:document, '/flatten-parB')]//j:concurrent/jf:layer[@type="parallel"]/jf:placeholder satisfies starts-with($ph/@jf:id, "A")}</xpath>
      <xpath desc="parallel elements are prioritized">{every $pe in .//jf:parallelGrp|.//jf:parallel satisfies $pe/@jf:nchildren=(-19,19)}</xpath>
    </results>
  )
  let $teardown := t:teardown-parallel()
  let $fails := $results/xpath[not(.="true")]
  where exists($fails)
  return ($fails, $test)
};

declare
  %test:pending
  %test:name("merge a parallel document")
  %test:assertEmpty
  function t:test-merge-a-parallel-document() {
  let $setup := t:setup-parallel()
  let $linkage-document := $setup[1]
  let $test :=
    let $d := doc($linkage-document)
    return format:merge($d, map {}, $d)
  let $results := $test/(
    <results>
      <xpath desc="parA has a merged element">{exists(.//tei:TEI[contains(@jf:document, '/flatten-parA')]//jf:merged)}</xpath>
      <xpath desc="parA merged element contains all the elements from the parA streamText">{count(.//tei:TEI[contains(@jf:document, '/flatten-parA')]//jf:merged/jf:placeholder[contains(@jf:stream, 'parA')][starts-with(@jf:id,'A')])=9}</xpath>
      <xpath desc="parA has a concurrent element that makes reference to its layers">{exists(.//tei:TEI[contains(@jf:document, '/flatten-parA')]//jf:concurrent[count(jf:layer)=1]/jf:layer[count(node())=0])}</xpath>
      <xpath desc="parB has a merged element">{exists(.//tei:TEI[contains(@jf:document, '/flatten-parB')]//jf:merged)}</xpath>
      <xpath desc="parB merged element contains all the elements from the parB streamText">{count(.//tei:TEI[contains(@jf:document, '/flatten-parB')]//jf:merged/jf:placeholder[contains(@jf:stream,'parB')][starts-with(@jf:id,'A')])=9}</xpath>
      <xpath desc="parB has a concurrent element that makes reference to its layers">{every $layer in .//tei:TEI[contains(@jf:document, '/flatten-parB')]//jf:concurrent[count(jf:layer)=2]/jf:layer satisfies count($layer/node())=0}</xpath>
    </results>
  )
  let $teardown := t:teardown-parallel()
  let $fails := $results/xpath[not(.="true")]
  where exists($fails)
  return ($fails, $test)
};

declare
  %test:pending
  %test:name("resolve a parallel document")
  %test:assertEmpty
  function t:test-resolve-a-parallel-document() {
  let $setup := t:setup-parallel()
  let $linkage-document := $setup[1]
  let $test :=
    let $d := doc($linkage-document)
    return format:resolve($d, map {}, $d)
  let $results := $test/(
    <results>
      <xpath desc="streamText has been removed">{empty(.//j:streamText)}</xpath>
      <xpath desc="parA merged element contains all the seg elements from the parA streamText">{count(.//tei:TEI[contains(@jf:document, '/flatten-parA')]//jf:merged/tei:seg[contains(@jf:stream, 'parA')][starts-with(.,'A-')])=9}</xpath>
      <xpath desc="parB merged element contains all the seg elements from the parB streamText">{count(.//tei:TEI[contains(@jf:document, '/flatten-parB')]//jf:merged/tei:seg[contains(@jf:stream,'parB')][starts-with(.,'B-')])=9}</xpath>
    </results>
  )
  let $teardown := t:teardown-parallel()
  let $fails := $results/xpath[not(.="true")]
  where exists($fails)
  return ($fails, $test)
};