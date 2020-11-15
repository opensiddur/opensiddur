package org.opensiddur.transforms

import org.opensiddur.DbTest

class TestUnflatten extends DbTest {
  override val prolog =
    """xquery version '3.1';

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:/db/apps/opensiddur-server/magic/magic.xqm";
import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

import module namespace unflatten="http://jewishliturgy.org/transform/unflatten"
  at "xmldb:exist:///db/apps/opensiddur-server/transforms/unflatten.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "xmldb:exist:///db/apps/opensiddur-server/modules/format.xqm";

    """

  override def beforeAll: Unit = {
    super.beforeAll
    setupUsers(1)
    setupResource("src/test/resources/transforms/unflatten-order-bug.xml", "unflatten-order-bug", "original", 1, Some("en"))
    setupResource("src/test/resources/transforms/unflatten-parA.xml", "unflatten-parA", "original", 1, Some("en"))
    setupResource("src/test/resources/transforms/unflatten-parB.xml", "unflatten-parB", "original", 1, Some("en"))
    setupResource("src/test/resources/transforms/unflatten-par.xml", "unflatten-par", "linkage", 1)
  }

  override def afterAll(): Unit = {
    teardownResource("unflatten-par", "linkage", 1)
    teardownResource("unflatten-parA", "original", 1)
    teardownResource("unflatten-parB", "original", 1)
    teardownResource("unflatten-order-bug", "original", 1)
    teardownUsers(1)
    super.afterAll()
  }

  describe("unflatten:unopened-tags") {
    it("produces no output for no unopened tags") {
      xq(
        """unflatten:unopened-tags(
          (<jf:temp>
            <tei:div jf:start="div1" jf:id="div1"/>
            <tei:ab jf:continue="ab1" jf:id="ab1"/>
            <tei:label jf:id="lbl1">Label</tei:label>
            <tei:ab jf:suspend="ab1"/>
            <tei:div jf:end="div1"/>
          </jf:temp>)/*)""")
        .assertEmpty
        .go
    }

    it("returns the ended element one ended unopened tag") {
      xq(
        """unflatten:unopened-tags(
          (<jf:temp>
            <tei:label jf:id="lbl1">Label</tei:label>
            <tei:div jf:end="div1"/>
          </jf:temp>)/*)""")
        .assertXmlEquals(
          """<tei:div xmlns:tei="http://www.tei-c.org/ns/1.0"
            |                     xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
            |                     jf:end="div1"/>""".stripMargin)
        .go
    }

    it("returns the suspended element for a suspended unopened tag") {
      xq(
        """unflatten:unopened-tags(
          (<jf:temp>
            <tei:label jf:id="lbl1">Label</tei:label>
            <tei:div jf:suspend="div1"/>
          </jf:temp>)/*)""")
        .assertXmlEquals(
          """<tei:div xmlns:tei="http://www.tei-c.org/ns/1.0"
            |                     xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
            |                     jf:suspend="div1"/>""".stripMargin)
        .go
    }
  }
  
  describe("unflatten:unclosed-tags") {
    it("returns empty on no unclosed tags") {
      xq("""let $tags := 
                     <jf:temp>
                       <tei:div jf:start="div1" jf:id="div1"/>
                       <tei:ab jf:continue="ab1" jf:id="ab1"/>
                       <tei:label jf:id="lbl1">Label</tei:label>
                       <tei:ab jf:suspend="ab1"/>
                       <tei:div jf:end="div1"/>
                     </jf:temp>
                   return
                     unflatten:unclosed-tags(
                       $tags/*
           )""")
        .assertEmpty
        .go
    }
    
    it("returns the started element when there is one unclosed tag") {
      xq("""let $tags := 
                      <jf:temp>
                        <tei:div jf:start="div1" jf:id="div1"/>
                        <tei:label jf:id="lbl1">Label</tei:label>
                      </jf:temp>
                   return
                     unflatten:unclosed-tags(
                       $tags/*
           )""")
        .assertXmlEquals("""<tei:div xmlns:tei="http://www.tei-c.org/ns/1.0"
                           |                     xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                           |                     jf:start="div1"
                           |                     jf:id="div1"/>""".stripMargin)
        .go
    }
    
    it("it returns the continued element when there is a continued unclosed tag") {
      xq("""let $tags := 
                      <jf:temp>
                        <tei:div jf:continue="div1" jf:id="div1"/>
                        <tei:label jf:id="lbl1">Label</tei:label>
                      </jf:temp>
                   return
                     unflatten:unclosed-tags(
                       $tags/*
           )""")
        .assertXmlEquals("""<tei:div xmlns:tei="http://www.tei-c.org/ns/1.0"
                           |                     xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                           |                     jf:continue="div1"
                           |                     jf:id="div1"/>""".stripMargin)
        .go
    }
  }

  describe("unflatten:unflatten-document") {
    it("unflattens a simple hierarchy") {
      val simpleDocument = readXmlFile("src/test/resources/transforms/unflatten1.xml")
      val unflattenedDocument = readXmlFile("src/test/resources/transforms/unflatten1-unflat.xml")

      xq(s"""unflatten:unflatten-document(document { $simpleDocument }, map {})/*""")
        .assertXmlEquals(unflattenedDocument)
        .go
    }

    it("unflattens a hierarchy with 2 levels with siblings") {
      val hierDocument = readXmlFile("src/test/resources/transforms/unflatten2.xml")
      val unflattenedDocument = readXmlFile("src/test/resources/transforms/unflatten2-unflat.xml")

      xq(s"""unflatten:unflatten-document(document { $hierDocument }, map {})/*""")
        .assertXmlEquals(unflattenedDocument)
        .go
    }

    it("unflattens a hierarchy with suspend and continue") {
      val hierDocument = readXmlFile("src/test/resources/transforms/unflatten3.xml")
      val unflattenedDocument = readXmlFile("src/test/resources/transforms/unflatten3-unflat.xml")

      xq(s"""unflatten:unflatten-document(document { $hierDocument }, map {})/*""")
        .assertXmlEquals(unflattenedDocument)
        .go
    }

    it("unflattens multiple hierarchies with a broken up element") {
      val hierDocument = readXmlFile("src/test/resources/transforms/unflatten4.xml")
      val unflattenedDocument = readXmlFile("src/test/resources/transforms/unflatten4-unflat.xml")

      xq(s"""unflatten:unflatten-document(document { $hierDocument }, map {})/*""")
        .assertXmlEquals(unflattenedDocument)
        .go
    }
  }
  
  describe("format:unflatten") {
    it("works correctly when an element is repeated (regression test)") {
      
      xq(
        """let $d := doc("/db/data/original/en/unflatten-order-bug.xml") 
           return format:unflatten($d, map {}, $d)/*""")
        .assertXPath("""empty($output//tei:head[ancestor::tei:ab])""", "tei:head is not a descendant of tei:ab")
        .assertXPath("""empty($output//tei:ab[@jf:id="ab2"][ancestor::tei:ab[@jf:id="ab2"]])""", "tei:ab[id=ab2] is not a descendant of itself")
        .go
    }
    
    it("unflattens a parallel document") {
      xq("""let $d := doc("/db/data/linkage/unflatten-par.xml")
                      return format:unflatten($d, map {}, $d)""")
      .assertXPath("""count($output//tei:TEI[contains(@jf:document, '/unflatten-parA')]//jf:unflattened//tei:p[@jf:id="p1"][count(descendant::tei:seg)=3]/ancestor::jf:parallel)=1""",
        "p1 is entirely contained in a single parallel element")
        .assertXPath("""
          let $p := $output//tei:TEI[contains(@jf:document, '/unflatten-parA')]//jf:unflattened//tei:p[@jf:part="p2"]
          return
          count($p)=2
          and not($p[1]/ancestor::jf:parallel)
          and $p[1]/descendant::tei:seg[@jf:id="A4"]
          and count($p[2]/ancestor::jf:parallel)=1
          and $p[2]/count(descendant::tei:seg)=2
          and $p[1]/@jf:part
          and $p[2]/@jf:part
        """, "p2 (break at beginning) is partially contained outside parallel and partially inside it")
        .assertXPath("""
          let $p := $output//tei:TEI[contains(@jf:document, '/unflatten-parA')]//jf:unflattened//tei:p[@jf:part="p3"]
          return
          count($p)=2
          and count($p[1]/ancestor::jf:parallel)=1
          and count($p[1]/descendant::tei:seg)=2
          and count($p[2]/ancestor::jf:parallel)=0
          and count($p[2]/descendant::tei:seg)=1
          and $p[1]/@jf:part
          and $p[2]/@jf:part
        """, "p3 (break at end) is partially contained outside parallel and partially inside it")
        .assertXPath("""
          let $p := $output//tei:TEI[contains(@jf:document, '/unflatten-parA')]//jf:unflattened//tei:p[@jf:part="p4"]
          return
          count($p)=3
          and $p[1]/descendant::tei:seg/@jf:id="A10"
          and count($p[2]/descendant::tei:seg)=2
          and count($p[2]/ancestor::jf:parallel)=1
          and $p[3]/descendant::tei:seg/@jf:id="A13"
          and (every $pp in $p satisfies $pp/@jf:part)
        """, "p4 (break at beginning and end) is partially contained outside parallel and partially inside it")
        .assertXPath("""
          let $p := $output//tei:TEI[contains(@jf:document, '/unflatten-parA')]//jf:unflattened//tei:p[@jf:part="p5"]
          return
          count($p)=2
          and (every $pp in $p satisfies count($pp/ancestor::jf:parallel)=1 and count($pp/ancestor::jf:parallelGrp)=1)
          and not($p[1]/ancestor::jf:parallelGrp is $p[2]/ancestor::jf:parallelGrp)
          and count($p[1]/descendant::tei:seg)=2
          and count($p[2]/descendant::tei:seg)=2
          and (every $pp in $p satisfies $pp/@jf:part)
        """, "p5 (broken up in the middle) is entirely contained within 2 parallel groups")
        .go
    }
  }


}
