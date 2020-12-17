package org.opensiddur.transforms

import org.opensiddur.DbTest

class TestFlatten extends DbTest {
  override val prolog =
    """xquery version '3.1';

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:/db/apps/opensiddur-server/magic/magic.xqm";
import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

import module namespace flatten="http://jewishliturgy.org/transform/flatten"
  at "xmdb:exist:/db/apps/opensiddur-server/transforms/flatten.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "xmdb:exist:/db/apps/opensiddur-server/modules/format.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "xmdb:exist:/db/apps/opensiddur-server/modules/refindex.xqm";

    """

  def setupResourceForFormat(resourceName: String, dataType: String = "original",
                            ): Unit = {
    setupResource("src/test/resources/transforms/" + resourceName + ".xml",
      resourceName, dataType, 1, if (dataType == "original") Some("en") else None, 
      Some("everyone"), Some("rw-rw-r--"))
    xq(
      s"""
          let $$name := '/db/data/$dataType/${if (dataType == "original") "en/" else ""}$resourceName.xml'
          let $$segmented := format:segment(doc($$name), map {}, doc($$name))
          return ()""").go
  }

  override def beforeAll: Unit = {
    super.beforeAll
    xq("""let $users := tcommon:setup-test-users(1)
         return ()""")
      .go

    setupResourceForFormat("identity")
    setupResourceForFormat("simple-concurrency")
    setupResourceForFormat("inline")
    setupResourceForFormat("inline2")
    setupResourceForFormat("inline3")
    setupResourceForFormat("inline4")
    setupResourceForFormat("suspend")
    setupResourceForFormat("suspend2")
    setupResourceForFormat("suspend3")
    setupResourceForFormat("suspend4")
    setupResourceForFormat("resolve")
    setupResourceForFormat("flatten-parA")
    setupResourceForFormat("flatten-parB")
    setupResourceForFormat("flatten-par", "linkage")
  }

  override def afterAll(): Unit = {
    teardownResource("flatten-parB", "original", 1)
    teardownResource("flatten-parA", "original", 1)
    teardownResource("flatten-par", "linkage", 1)
    teardownResource("resolve", "original", 1)
    teardownResource("suspend4", "original", 1)
    teardownResource("suspend3", "original", 1)
    teardownResource("suspend2", "original", 1)
    teardownResource("suspend", "original", 1)
    teardownResource("inline4", "original", 1)
    teardownResource("inline3", "original", 1)
    teardownResource("inline2", "original", 1)
    teardownResource("inline", "original", 1)
    teardownResource("simple-concurrency", "original", 1)
    teardownResource("identity", "original", 1)
    xq("""let $users := tcommon:teardown-test-users(1)
         return ()""")
      .go
    super.afterAll()
  }

  describe("format:flatten-document") {
    it("acts as an identity transform except streamText has jf:id, when there is no concurrency") {
      xq("""flatten:flatten-document(doc("/db/data/original/en/identity.xml"), map {})/*""")
        .assertXmlEquals("""
                           |    <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
                           |      <tei:teiHeader>
                           |        <!-- leaving it blank... -->
                           |      </tei:teiHeader>
                           |      <tei:text>
                           |        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
                           |        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                           |        jf:id="...">
                           |          <tei:seg xml:id="seg1">No layers!</tei:seg>
                           |        </j:streamText>
                           |      </tei:text>
                           |    </tei:TEI>""".stripMargin)
        .go
    }

    it("changes a pointer to a placeholder with simple concurrency") {
      xq("""flatten:flatten-document(doc("/db/data/original/en/simple-concurrency.xml"), map {})/*""")
        .assertXmlEquals("""<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
                           |      <tei:teiHeader>
                           |        <!-- leaving it blank... -->
                           |      </tei:teiHeader>
                           |      <tei:text>
                           |        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
                           |          <jf:layer xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" type="div"
                           |          jf:id="div-layer"
                           |          jf:layer-id="/data/original/simple-concurrency#div-layer">
                           |            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/simple-concurrency#div-layer"
                           |            jf:id="div1"/>
                           |            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
                           |            jf:nprecedents="0"
                           |            jf:stream="/data/original/simple-concurrency#stream"
                           |            jf:id="seg1"/>
                           |            <tei:div jf:end="div1" jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/simple-concurrency#div-layer"/>
                           |          </jf:layer>
                           |        </j:concurrent>
                           |        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
                           |        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                           |        jf:id="stream">
                           |          <tei:seg xml:id="seg1">No layers!</tei:seg>
                           |        </j:streamText>
                           |      </tei:text>
                           |    </tei:TEI>""".stripMargin)
        .go
    }

    it("matches start and end attributes when there are concurrent hierarchies with inline elements and no children") {
      xq("""flatten:flatten-document(doc("/db/data/original/en/inline.xml"), map {})/*""")
        .assertXmlEquals("""<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
                           |      <tei:teiHeader>
                           |        <!-- leaving it blank... -->
                           |      </tei:teiHeader>
                           |      <tei:text>
                           |        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
                           |          <jf:layer xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" type="div"
                           |          jf:id="div-layer"
                           |          jf:layer-id="/data/original/inline#div-layer">
                           |            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/inline#div-layer"
                           |            jf:id="div1"/>
                           |            <tei:head jf:position="1" jf:relative="-1" jf:nchildren="-1" jf:nlevels="2"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/inline#div-layer">title</tei:head>
                           |            <tei:ab jf:start="..." jf:position="1" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="2"
                           |            jf:nprecedents="2"
                           |            jf:layer-id="/data/original/inline#div-layer"/>
                           |            <tei:label jf:position="1" jf:relative="-1" jf:nchildren="-1" jf:nlevels="3"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/inline#div-layer">Label</tei:label>
                           |            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
                           |            jf:nprecedents="0"
                           |            jf:stream="/data/original/inline#stream"
                           |            jf:id="seg1"/>
                           |            <tei:ab jf:end="..." jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
                           |            jf:nprecedents="2"
                           |            jf:layer-id="/data/original/inline#div-layer"/>
                           |            <tei:div jf:end="div1" jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/inline#div-layer"/>
                           |          </jf:layer>
                           |        </j:concurrent>
                           |        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
                           |        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                           |        jf:id="stream">
                           |          <tei:seg xml:id="seg1">One segment</tei:seg>
                           |        </j:streamText>
                           |      </tei:text>
                           |    </tei:TEI>""".stripMargin)
        .assertXPath("$output//*:ab[@*:start]/@*:start=$output//*:ab[@*:end]/@*:end")
        .go
    }

    it("writes labels with positioning information with concurrent hierarchies and two inline elements in a row") {
      xq("""flatten:flatten-document(doc("/db/data/original/en/inline2.xml"), map {})""")
        .assertXPathEquals("$output//tei:label[1]", "label 1", """<tei:label xmlns:tei="http://www.tei-c.org/ns/1.0"
                                                      |      xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                                                      |      jf:position="1"
                                                      |      jf:relative="-1"
                                                      |      jf:nchildren="-1"
                                                      |      jf:nlevels="3"
                                                      |      jf:nprecedents="1"
                                                      |      jf:layer-id="/data/original/inline2#div-layer">Label 1</tei:label>""".stripMargin)
        .assertXPathEquals("$output//tei:label[2]", "label 2", """<tei:label xmlns:tei="http://www.tei-c.org/ns/1.0"
                                                      |      xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                                                      |      jf:position="1"
                                                      |      jf:relative="-1"
                                                      |      jf:nchildren="-1"
                                                      |      jf:nlevels="3"
                                                      |      jf:nprecedents="2"
                                                      |      jf:layer-id="/data/original/inline2#div-layer">Label 2</tei:label>""".stripMargin)
        .go
    }

    it("annotates labels with concurrent hierarchies with two inline elements, the second follows a ptr") {
      xq("""flatten:flatten-document(doc("/db/data/original/en/inline3.xml"), map {})""")
        .assertXPathEquals("$output//tei:label[1]", "label 1", """<tei:label xmlns:tei="http://www.tei-c.org/ns/1.0"
                                                      |      xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                                                      |      jf:position="1"
                                                      |      jf:relative="-1"
                                                      |      jf:nchildren="-1"
                                                      |      jf:nlevels="3"
                                                      |      jf:nprecedents="1"
                                                      |      jf:layer-id="/data/original/inline3#div-layer">Label 1</tei:label>""".stripMargin)
        .assertXPathEquals("$output//tei:label[2]", "label 2", """<tei:label xmlns:tei="http://www.tei-c.org/ns/1.0"
                                                    |      xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                                                    |      jf:position="1"
                                                    |      jf:relative="1"
                                                    |      jf:nchildren="1"
                                                    |      jf:nlevels="-3"
                                                    |      jf:nprecedents="3"
                                                    |      jf:layer-id="/data/original/inline3#div-layer">Label 2</tei:label>""".stripMargin)
        .go
    }

    it("flattens a document with pointers and labels") {
      xq("""flatten:flatten-document(doc("/db/data/original/en/inline4.xml"), map {})/*""")
        .assertXmlEquals("""<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
                           |      <tei:teiHeader>
                           |        <!-- leaving it blank... -->
                           |      </tei:teiHeader>
                           |      <tei:text>
                           |        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
                           |          <jf:layer xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" type="div"
                           |          jf:id="div-layer"
                           |          jf:layer-id="/data/original/inline4#div-layer">
                           |            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-2"
                           |            jf:nlevels="1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/inline4#div-layer"
                           |            jf:id="div1"/>
                           |            <tei:head jf:position="1" jf:relative="-1" jf:nchildren="-2" jf:nlevels="2"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/inline4#div-layer">title</tei:head>
                           |            <tei:ab jf:start="..." jf:position="1" jf:relative="-1" jf:nchildren="-2"
                           |            jf:nlevels="2"
                           |            jf:nprecedents="2"
                           |            jf:layer-id="/data/original/inline4#div-layer"/>
                           |            <tei:label jf:position="1" jf:relative="-1" jf:nchildren="-2" jf:nlevels="3"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/inline4#div-layer">Label 1</tei:label>
                           |            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
                           |            jf:nprecedents="0"
                           |            jf:stream="/data/original/inline4#stream"
                           |            jf:id="seg1"/>
                           |            <tei:label jf:position="1" jf:relative="1" jf:nchildren="2" jf:nlevels="-3"
                           |            jf:nprecedents="3"
                           |            jf:layer-id="/data/original/inline4#div-layer">Label 2</tei:label>
                           |            <jf:placeholder jf:position="2" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
                           |            jf:nprecedents="0"
                           |            jf:stream="/data/original/inline4#stream"
                           |            jf:id="seg2"/>
                           |            <tei:label jf:position="2" jf:relative="1" jf:nchildren="2" jf:nlevels="-3"
                           |            jf:nprecedents="5"
                           |            jf:layer-id="/data/original/inline4#div-layer">Label 3</tei:label>
                           |            <tei:ab jf:end="..." jf:position="2" jf:relative="1" jf:nchildren="2" jf:nlevels="-2"
                           |            jf:nprecedents="2"
                           |            jf:layer-id="/data/original/inline4#div-layer"/>
                           |            <tei:label jf:position="2" jf:relative="1" jf:nchildren="2" jf:nlevels="-2"
                           |            jf:nprecedents="3"
                           |            jf:layer-id="/data/original/inline4#div-layer">Label 4</tei:label>
                           |            <tei:div jf:end="div1" jf:position="2" jf:relative="1" jf:nchildren="2" jf:nlevels="-1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/inline4#div-layer"/>
                           |          </jf:layer>
                           |        </j:concurrent>
                           |        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
                           |        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                           |        jf:id="stream">
                           |          <tei:seg xml:id="seg1">One segment</tei:seg>
                           |          <tei:seg xml:id="seg2">Two segments</tei:seg>
                           |        </j:streamText>
                           |      </tei:text>
                           |    </tei:TEI>""".stripMargin)
    }

    it("flattens a document with two level suspend and continue") {
      xq("""flatten:flatten-document(doc("/db/data/original/en/suspend.xml"), map {})/*""")
        .assertXmlEquals("""<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
                           |      <tei:teiHeader>
                           |        <!-- leaving it blank... -->
                           |      </tei:teiHeader>
                           |      <tei:text>
                           |        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
                           |          <jf:layer xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" type="div"
                           |          jf:id="div-layer"
                           |          jf:layer-id="/data/original/suspend#div-layer">
                           |            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend#div-layer"
                           |            jf:id="div1"/>
                           |            <tei:ab jf:start="ab1" jf:id="ab1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="2"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend#div-layer"/>
                           |            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
                           |            jf:nprecedents="0"
                           |            jf:stream="/data/original/suspend#stream"
                           |            jf:id="seg1"/>
                           |            <tei:ab jf:suspend="ab1" jf:position="1" jf:relative="1" jf:nchildren="1"
                           |            jf:nlevels="-2"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend#div-layer"/>
                           |            <tei:div jf:suspend="div1" jf:position="1" jf:relative="1" jf:nchildren="1"
                           |            jf:nlevels="-1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend#div-layer"/>
                           |            <tei:div jf:continue="div1" jf:position="3" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend#div-layer"/>
                           |            <tei:ab jf:continue="ab1" jf:position="3" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="2"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend#div-layer"/>
                           |            <jf:placeholder jf:position="3" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
                           |            jf:nprecedents="0"
                           |            jf:stream="/data/original/suspend#stream"
                           |            jf:id="seg3"/>
                           |            <tei:ab jf:end="ab1" jf:position="3" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend#div-layer"/>
                           |            <tei:div jf:end="div1" jf:position="3" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend#div-layer"/>
                           |          </jf:layer>
                           |        </j:concurrent>
                           |        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
                           |        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                           |        jf:id="stream">
                           |          <tei:seg xml:id="seg1">One segment</tei:seg>
                           |          <tei:seg xml:id="seg2">Two segments</tei:seg>
                           |          <tei:seg xml:id="seg3">Three segments</tei:seg>
                           |        </j:streamText>
                           |      </tei:text>
                           |    </tei:TEI>""".stripMargin)
        .go
    }

    it("flattens with suspend and continue with labels") {
      xq("""flatten:flatten-document(doc("/db/data/original/en/suspend2.xml"), map {})/*""")
        .assertXmlEquals("""<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
                           |      <tei:teiHeader>
                           |        <!-- leaving it blank... -->
                           |      </tei:teiHeader>
                           |      <tei:text>
                           |        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
                           |          <jf:layer xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" type="div"
                           |          jf:id="div-layer"
                           |          jf:layer-id="/data/original/suspend2#div-layer">
                           |            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend2#div-layer"
                           |            jf:id="div1"/>
                           |            <tei:label jf:id="lbl1" jf:position="1" jf:relative="-1" jf:nchildren="-1" jf:nlevels="2"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend2#div-layer">before</tei:label>
                           |            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
                           |            jf:nprecedents="0"
                           |            jf:stream="/data/original/suspend2#stream"
                           |            jf:id="seg1"/>
                           |            <tei:label jf:id="lbl2" jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
                           |            jf:nprecedents="3"
                           |            jf:layer-id="/data/original/suspend2#div-layer">after 1</tei:label>
                           |            <tei:div jf:suspend="div1" jf:position="1" jf:relative="1" jf:nchildren="1"
                           |            jf:nlevels="-1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend2#div-layer"/>
                           |            <tei:div jf:continue="div1" jf:position="3" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend2#div-layer"/>
                           |            <jf:placeholder jf:position="3" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
                           |            jf:nprecedents="0"
                           |            jf:stream="/data/original/suspend2#stream"
                           |            jf:id="seg3"/>
                           |            <tei:label jf:id="lbl3" jf:position="3" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
                           |            jf:nprecedents="5"
                           |            jf:layer-id="/data/original/suspend2#div-layer">after 3</tei:label>
                           |            <tei:div jf:end="div1" jf:position="3" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend2#div-layer"/>
                           |          </jf:layer>
                           |        </j:concurrent>
                           |        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
                           |        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                           |        jf:id="stream">
                           |          <tei:seg xml:id="seg1">One segment</tei:seg>
                           |          <tei:seg xml:id="seg2">Two segments</tei:seg>
                           |          <tei:seg xml:id="seg3">Three segments</tei:seg>
                           |        </j:streamText>
                           |      </tei:text>
                           |    </tei:TEI>""".stripMargin)
        .go
    }

    it("flattens with multi-level suspend and continue with unequal numbers of levels") {
      xq("""flatten:flatten-document(doc("/db/data/original/en/suspend3.xml"), map {})/*""")
        .assertXmlEquals("""<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
                           |      <tei:teiHeader>
                           |        <!-- leaving it blank... -->
                           |      </tei:teiHeader>
                           |      <tei:text>
                           |        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
                           |          <jf:layer xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" type="div"
                           |          jf:id="div-layer"
                           |          jf:layer-id="/data/original/suspend3#div-layer">
                           |            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend3#div-layer"
                           |            jf:id="div1"/>
                           |            <tei:ab jf:start="ab1" jf:id="ab1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="2"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend3#div-layer"/>
                           |            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
                           |            jf:nprecedents="0"
                           |            jf:stream="/data/original/suspend3#stream"
                           |            jf:id="seg1"/>
                           |            <tei:ab jf:end="ab1" jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend3#div-layer"/>
                           |            <tei:div jf:suspend="div1" jf:position="1" jf:relative="1" jf:nchildren="1"
                           |            jf:nlevels="-1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend3#div-layer"/>
                           |            <tei:div jf:continue="div1" jf:position="3" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend3#div-layer"/>
                           |            <jf:placeholder jf:position="3" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
                           |            jf:nprecedents="0"
                           |            jf:stream="/data/original/suspend3#stream"
                           |            jf:id="seg3"/>
                           |            <tei:div jf:end="div1" jf:position="3" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend3#div-layer"/>
                           |          </jf:layer>
                           |        </j:concurrent>
                           |        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
                           |        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                           |        jf:id="stream">
                           |          <tei:seg xml:id="seg1">One segment</tei:seg>
                           |          <tei:seg xml:id="seg2">Two segments</tei:seg>
                           |          <tei:seg xml:id="seg3">Three segments</tei:seg>
                           |        </j:streamText>
                           |      </tei:text>
                           |    </tei:TEI>""".stripMargin)
        .go
    }

    it("flattens with multi-level suspend and continue with end and start at the suspend position") {
      xq("""flatten:flatten-document(doc("/db/data/original/en/suspend4.xml"), map {})/*""")
        .assertXmlEquals("""<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
                           |      <tei:teiHeader>
                           |        <!-- leaving it blank... -->
                           |      </tei:teiHeader>
                           |      <tei:text>
                           |        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
                           |          <jf:layer xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" type="div"
                           |          jf:id="div-layer"
                           |          jf:layer-id="/data/original/suspend4#div-layer">
                           |            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend4#div-layer"
                           |            jf:id="div1"/>
                           |            <tei:ab jf:start="ab1" jf:id="ab1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="2"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend4#div-layer"/>
                           |            <jf:placeholder jf:position="1" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
                           |            jf:nprecedents="0"
                           |            jf:stream="/data/original/suspend4#stream"
                           |            jf:id="seg1"/>
                           |            <tei:ab jf:end="ab1" jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend4#div-layer"/>
                           |            <tei:div jf:suspend="div1" jf:position="1" jf:relative="1" jf:nchildren="1"
                           |            jf:nlevels="-1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend4#div-layer"/>
                           |            <tei:div jf:continue="div1" jf:position="3" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend4#div-layer"/>
                           |            <tei:ab jf:start="ab2" jf:id="ab2" jf:position="3" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="2"
                           |            jf:nprecedents="2"
                           |            jf:layer-id="/data/original/suspend4#div-layer"/>
                           |            <jf:placeholder jf:position="3" jf:relative="0" jf:nchildren="0" jf:nlevels="0"
                           |            jf:nprecedents="0"
                           |            jf:stream="/data/original/suspend4#stream"
                           |            jf:id="seg3"/>
                           |            <tei:ab jf:end="ab2" jf:position="3" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
                           |            jf:nprecedents="2"
                           |            jf:layer-id="/data/original/suspend4#div-layer"/>
                           |            <tei:div jf:end="div1" jf:position="3" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="/data/original/suspend4#div-layer"/>
                           |          </jf:layer>
                           |        </j:concurrent>
                           |        <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
                           |        xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                           |        jf:id="stream">
                           |          <tei:seg xml:id="seg1">One segment</tei:seg>
                           |          <tei:seg xml:id="seg2">Two segments</tei:seg>
                           |          <tei:seg xml:id="seg3">Three segments</tei:seg>
                           |        </j:streamText>
                           |      </tei:text>
                           |    </tei:TEI>""".stripMargin)
        .go
    }
  }

  describe("flatten:resolve-stream") {
    it("replaces placeholders with stream elements") {
      xq("""flatten:resolve-stream(doc("/db/data/original/en/resolve.xml"), map {})/*""")
        .assertXmlEquals("""<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
                           |      <tei:teiHeader>
                           |        <!-- leaving it blank... -->
                           |      </tei:teiHeader>
                           |      <tei:text>
                           |        <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
                           |          <jf:merged xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0">
                           |            <tei:div jf:start="div1" jf:position="1" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="div-layer"
                           |            jf:id="div1"/>
                           |            <tei:head jf:position="1" jf:relative="-1" jf:nchildren="-1" jf:nlevels="2"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="div-layer">title</tei:head>
                           |            <tei:ab jf:start="..." jf:position="1" jf:relative="-1" jf:nchildren="-1"
                           |            jf:nlevels="2"
                           |            jf:nprecedents="2"
                           |            jf:layer-id="div-layer"/>
                           |            <tei:label jf:position="1" jf:relative="-1" jf:nchildren="-1" jf:nlevels="3"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="div-layer">Label</tei:label>
                           |            <tei:seg jf:id="seg1" jf:stream="stream">One segment</tei:seg>
                           |            <tei:ab jf:end="..." jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-2"
                           |            jf:nprecedents="2"
                           |            jf:layer-id="div-layer"/>
                           |            <tei:div jf:end="div1" jf:position="1" jf:relative="1" jf:nchildren="1" jf:nlevels="-1"
                           |            jf:nprecedents="1"
                           |            jf:layer-id="div-layer"/>
                           |          </jf:merged>
                           |        </j:concurrent>
                           |      </tei:text>
                           |    </tei:TEI>""".stripMargin)
        .go
    }
  }
  
  describe("format:flatten") {
    it("flattens a parallel document") {
      xq(
        """let $linkage-doc := doc("/db/data/linkage/flatten-par.xml")
          return format:flatten($linkage-doc, map {}, $linkage-doc)""")
        .assertXPath("""$output//tei:TEI[contains(@jf:document, '/flatten-parA')]//j:streamText/tei:seg[@jf:id="A1"]="A-1" """,
          "parA reproduces its own streamText")
        .assertXPath("""exists($output//tei:TEI[contains(@jf:document, '/flatten-parA')]//j:concurrent[count(jf:layer)=1]/jf:layer[@type="parallel"])""",
          "parA has 1 flattened parallel layer")
        .assertXPath("""exists($output//tei:TEI[contains(@jf:document, '/flatten-parA')]//j:concurrent/jf:layer[@type="parallel"][count(jf:parallelGrp[@jf:start])=3][count(jf:parallel[@jf:start])=3][count(jf:placeholder[@jf:stream="/data/original/flatten-parA#stream"])=6])""",
          "parA layer has flattened parallelGrps")
        .assertXPath(
          """every $ph in $output//tei:TEI[contains(@jf:document, '/flatten-parA')]//j:concurrent/jf:layer[@type="parallel"]/jf:placeholder
            satisfies starts-with($ph/@jf:id, "A")""", "parA layer placeholders point to their segs")
        .assertXPath("""$output//tei:TEI[contains(@jf:document, '/flatten-parB')]//j:streamText/tei:seg[@jf:id="A1"]="B-1"""",
          "parB reproduces its own streamText")
        .assertXPath("""exists($output//tei:TEI[contains(@jf:document, '/flatten-parB')]//j:concurrent[count(jf:layer)=2]/jf:layer[@type="parallel"])""",
          "parB has 1 flattened parallel layer and 2 flattened layers")
        .assertXPath("""exists($output//tei:TEI[contains(@jf:document, '/flatten-parB')]//j:concurrent/jf:layer[@type="parallel"][count(jf:parallelGrp[@jf:start])=3][count(jf:parallel[@jf:start])=3][count(jf:placeholder[@jf:stream="/data/original/flatten-parB#stream"])=7])""",
          "one parB layer has flattened parallelGrps")
        .assertXPath("""exists($output//tei:TEI[contains(@jf:document, '/flatten-parB')]//j:concurrent/jf:layer[@type="p"][count(tei:p[@jf:start])=1][count(jf:placeholder[@jf:stream="/data/original/flatten-parB#stream"])=9])""",
          "one parB layer has flattened paragraphs")
        .assertXPath(
          """every $ph in $output//tei:TEI[contains(@jf:document, '/flatten-parB')]//j:concurrent/jf:layer[@type="parallel"]/jf:placeholder
            satisfies starts-with($ph/@jf:id, "A")""", "parB layer placeholders point to their segs")
        .assertXPath(
          """every $pe in $output//jf:parallelGrp|$output//jf:parallel
            satisfies $pe/@jf:nchildren=(-19,19)""", "parallel elements are prioritized")
        .go
    }
  }
  
  describe("format:merge") {
    it("merges a parallel document") {
      xq(
        """let $d := doc("/db/data/linkage/flatten-par.xml")
          return format:merge($d, map {}, $d)""")
        .assertXPath("""exists($output//tei:TEI[contains(@jf:document, '/flatten-parA')]//jf:merged)""", "parA has a merged element")
        .assertXPath("""count($output//tei:TEI[contains(@jf:document, '/flatten-parA')]//jf:merged/jf:placeholder[contains(@jf:stream, 'parA')][starts-with(@jf:id,'A')])=9""", 
          "parA merged element contains all the elements from the parA streamText")
        .assertXPath("""exists($output//tei:TEI[contains(@jf:document, '/flatten-parA')]//jf:concurrent[count(jf:layer)=1]/jf:layer[count(node())=0])""",
          "parA has a concurrent element that makes reference to its layers")
        .assertXPath("""exists($output//tei:TEI[contains(@jf:document, '/flatten-parB')]//jf:merged)""", "parB has a merged element")
        .assertXPath("""count($output//tei:TEI[contains(@jf:document, '/flatten-parB')]//jf:merged/jf:placeholder[contains(@jf:stream,'parB')][starts-with(@jf:id,'A')])=9""", "parB merged element contains all the elements from the parB streamText")
        .assertXPath(
          """every $layer in $output//tei:TEI[contains(@jf:document, '/flatten-parB')]//jf:concurrent[count(jf:layer)=2]/jf:layer 
            satisfies count($layer/node())=0""", "parB has a concurrent element that makes reference to its layers")
        .go

        }
  }
  
  describe("format:resolve") {
    it("resolves a parallel document") {
      xq(
        """let $d := doc("/db/data/linkage/flatten-par.xml")
         return format:resolve($d, map {}, $d)""")
        .assertXPath("""empty($output//j:streamText)""", "streamText has been removed")
        .assertXPath("""count($output//tei:TEI[contains(@jf:document, '/flatten-parA')]//jf:merged/tei:seg[contains(@jf:stream, 'parA')][starts-with(.,'A-')])=9""",
          "parA merged element contains all the seg elements from the parA streamText")
        .assertXPath("""count($output//tei:TEI[contains(@jf:document, '/flatten-parB')]//jf:merged/tei:seg[contains(@jf:stream,'parB')][starts-with(.,'B-')])=9""",
          "parB merged element contains all the seg elements from the parB streamText")
        .go
    }
  }
}
