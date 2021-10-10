package org.opensiddur.transforms

import org.opensiddur.DbTest

class TestPhonyLayer extends DbTest {
  override val prolog: String =
    """xquery version '3.1';
    
    import module namespace phony="http://jewishliturgy.org/transform/phony-layer"
      at "xmldb:exist:///db/apps/opensiddur-server/transforms/phony-layer.xqm";
    import module namespace ridx="http://jewishliturgy.org/modules/refindex"
      at "xmldb:exist:///db/apps/opensiddur-server/modules/refindex.xqm";
    import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
      at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";
    import module namespace data="http://jewishliturgy.org/modules/data"
       at "xmldb:exist:/db/apps/opensiddur-server/modules/data.xqm";

    declare namespace tei="http://www.tei-c.org/ns/1.0";
    declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
    declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

    """

  override def beforeAll: Unit = {
    super.beforeAll

    setupUsers(1)
    setupResource("src/test/resources/transforms/PhonyLayer/phony1.xml", "phony1", "original", 1, Some("en"))
    setupResource("src/test/resources/transforms/PhonyLayer/phony2.xml", "phony2", "original", 1, Some("en"))
    setupResource("src/test/resources/transforms/PhonyLayer/phony3.xml", "phony3", "original", 1, Some("en"))
    setupResource("src/test/resources/transforms/PhonyLayer/phony4.xml", "phony4", "original", 1, Some("en"))
    setupResource("src/test/resources/transforms/PhonyLayer/phony5.xml", "phony5", "original", 1, Some("en"))
    setupResource("src/test/resources/transforms/PhonyLayer/phony6.xml", "phony6", "original", 1, Some("en"))
  }

  override def afterAll(): Unit = {
    teardownResource("phony6", "original", 1)
    teardownResource("phony5", "original", 1)
    teardownResource("phony4", "original", 1)
    teardownResource("phony3", "original", 1)
    teardownResource("phony2", "original", 1)
    teardownResource("phony1", "original", 1)

    teardownUsers(1)

    super.afterAll()
  }

  describe("phony:phony-layer-document") {

    it("is an identity transform with no conditionals") {
      val identityXml = readXmlFile("src/test/resources/transforms/PhonyLayer/phony1.xml")
      
      xq("""phony:phony-layer-document(data:doc("original", "phony1"), map {})/*""")
        .user("xqtest1")
        .assertXmlEquals(identityXml)
        .go
    }
    
    it("performs a transform when there are conditionals and only a streamText with no concurrency") {
      xq("""phony:phony-layer-document(
                           data:doc("original", "phony2"),
                           map {}
                       )""")
        .user("xqtest1")
        .assertXPath("""$output//j:streamText/@jf:conditional="#cond1" """, "j:streamText has a @jf:conditional attribute")
        .assertXPath("""exists($output//j:concurrent[j:layer]) """, "new concurrent section added")
        .assertXPath("""count($output//j:concurrent/j:layer[@type="phony-conditional"])=3 """, "3 layers of type phony added")
        .assertXPath("""every $l in $output//j:concurrent/j:layer[@type="phony-conditional"] satisfies $l/@xml:id/string() """, "each of the layers has a @xml:id attribute")
        .assertXPath("""not($output//j:concurrent/j:layer[@type='phony-conditional'][1]/@xml:id/string()=$output//j:concurrent/j:layer[@type="phony-conditional"][2]/@xml:id/string()) """, "the first layer has an xml:id that is different from the second")
        .assertXPathEquals("$output//j:concurrent/j:layer[@type='phony-conditional'][1]/jf:conditional",
          "one layer represents the first conditional",
          """<jf:conditional xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" jf:conditional="#cond1">
              <tei:ptr xmlns:tei="http://www.tei-c.org/ns/1.0" target="#seg1"/>
             </jf:conditional>"""
        )
        .assertXPathEquals("$output//j:concurrent/j:layer[@type='phony-conditional'][2]/jf:conditional",
          "one layer represents the second conditional",
          """<jf:conditional xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" jf:conditional="#cond1">
                    <tei:ptr xmlns:tei="http://www.tei-c.org/ns/1.0" target="#range(seg2,seg3)"/>
                  </jf:conditional>""")
        .assertXPathEquals("$output//j:concurrent/j:layer[@type='phony-conditional'][3]/jf:conditional",
          "one layer represents the third conditional, references the instruction",
          """<jf:conditional xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" jf:conditional="#cond1"
                                  jf:conditional-instruction="#instruction">
                    <tei:ptr xmlns:tei="http://www.tei-c.org/ns/1.0" target="#seg4"/>
                  </jf:conditional>""")
        .assertXPath("""$output//j:option[@xml:id="opt1"]/(@jf:conditional="#cond1" and empty(@jf:conditional-instruction)) """, "first j:option has conditional attributes with no instruction")
        .assertXPath("""$output//j:option[@xml:id="opt2"]/(@jf:conditional="#cond2" and @jf:conditional-instruction="#instruction") """, "second j:option has conditional attributes and instruction")
        .go
    }

    it("transforms when there are settings and only a streamText") {
      xq("""phony:phony-layer-document(
                           data:doc("original", "phony4"),
                           map {}
                       )""")
        .user("xqtest1")
        .assertXPath("""$output//j:streamText/@jf:set="#set1" """, "j:streamText has a @jf:set attribute")
        .assertXPath("""exists($output//j:concurrent[j:layer]) """, "new concurrent section added")
        .assertXPath("""count($output//j:concurrent/j:layer[@type="phony-set"])=2 """, "2 layers of type phony-set added")
        .assertXPath("""every $l in $output//j:concurrent/j:layer[@type="phony-set"] satisfies $l/@xml:id/string() """, "each of the layers has a @xml:id attribute")
        .assertXPath("""not($output//j:concurrent/j:layer[@type='phony-set'][1]/@xml:id/string()=$output//j:concurrent/j:layer[@type="phony-set"][2]/@xml:id/string()) """, "the first layer has an xml:id that is different from the second")
        .assertXPathEquals("$output//j:concurrent/j:layer[@type='phony-set'][1]/jf:set",
          "one layer represents the first setting",
          """<jf:set xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" jf:set="#set1">
                    <tei:ptr xmlns:tei="http://www.tei-c.org/ns/1.0" target="#seg1"/>
                  </jf:set>""")
        .assertXPathEquals("$output//j:concurrent/j:layer[@type='phony-set'][2]/jf:set",
          "one layer represents the second setting",
          """<jf:set xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" jf:set="#set1">
                    <tei:ptr xmlns:tei="http://www.tei-c.org/ns/1.0" target="#range(seg2,seg3)"/>
                  </jf:set>""")
        .assertXPath("""$output//tei:w[@xml:id="w1"]/@jf:set="#set2" """, "a setting referenced inside a streamText element results in @jf:set")
        .go
    }

    it("adds a phony layer with conditionals") {
      xq("""
          phony:phony-layer-document(
          data:doc("original", "phony3"),
          map {}
          )
      """)
        .user("xqtest1")
        .assertXPath("""count($output//j:concurrent/j:layer[@type="phony-conditional"])=1 """, "1 layer of type phony added")
        .assertXPath("""count($output//j:layer/tei:div[contains(@jf:conditional, "#cond2")])=2 """, "concurrent condition appears as an attribute on all divs in the layer")
        .assertXPath("""count($output/*[contains(@jf:conditional, "#cond2")][not(parent::j:layer)])=0 """, "concurrent condition does not appear as an attribute on any elements that are not direct descendents of j:layer")
        .assertXPath("""every $ab in $output//tei:ab[@xml:id=("ab1","ab2")] satisfies $ab/@jf:conditional="#cond1" """, "range reference results in @jf:conditional")
        .assertXPath("""contains($output//tei:div[@xml:id="div2"]/@jf:conditional, "#cond1") """, "direct reference results in @jf:conditional, along with concurrent condition")
        .assertXPath("""empty($output//tei:ab[@xml:id="ab3"]/@jf:conditional) """, "@jf:conditional is not added when there is no condition")
        .assertXPath("""empty($output//j:layer/@jf:conditional) """, "@jf:conditional is not added for j:layer")
        .go
    }

    it("adds a phony layer with settings") {
      xq("""
          phony:phony-layer-document(
          data:doc("original", "phony5"),
          map {}
          )
        """)
        .user("xqtest1")
        .assertXPath("""count($output//j:concurrent/j:layer[@type="phony-set"])=1 """, "1 layer of type phony added")
        .assertXPath("""count($output//j:layer/tei:div[contains(@jf:set, "#set2")])=2 """, "concurrent setting appears as an attribute on all divs in the layer")
        .assertXPath("""count($output/*[contains(@jf:set, "#set2")][not(parent::j:layer)])=0 """, "concurrent setting does not appear as an attribute on any elements that are not direct descendents of j:layer")
        .assertXPath("""every $ab in $output//tei:ab[@xml:id=("ab1","ab2")] satisfies $ab/@jf:set="#set1" """, "range reference results in @jf:set")
        .assertXPath("""contains($output//tei:div[@xml:id="div2"]/@jf:set, "#set1") """, "direct reference results in @jf:set, along with concurrent condition")
        .assertXPath("""empty($output//tei:ab[@xml:id="ab3"]/@jf:set) """, "@jf:set is not added when there is no condition")
        .assertXPath("""empty($output//j:layer/@jf:set) """, "@jf:set is not added for j:layer")
        .go
    }

    it("adds a phony layer for annotations") {
      xq("""
          phony:phony-layer-document(
          data:doc("original", "phony6"),
          map {}
          )
        """)
        .user("xqtest1")
        .assertXPath("""exists($output//j:concurrent[j:layer]) """, "new concurrent section added")
        .assertXPath("""count($output//j:concurrent/j:layer[@type="phony-annotation"])=2 """, "2 layers of type phony-annotation added")
        .assertXPath("""every $l in $output//j:concurrent/j:layer[@type="phony-annotation"] satisfies $l/@xml:id/string() """, "each of the layers has a @xml:id attribute")
        .assertXPath("""not($output//j:concurrent/j:layer[@type='phony-annotation'][1]/@xml:id/string()=$output//j:concurrent/j:layer[@type="phony-annotation"][2]/@xml:id/string()) """, "the first layer has an xml:id that is different from the second")
        .assertXPathEquals("$output//j:concurrent/j:layer[@type='phony-annotation'][1]/jf:annotation",
          "one layer represents the note",
          """<jf:annotation xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" jf:annotation="#note1">
                    <tei:ptr xmlns:tei="http://www.tei-c.org/ns/1.0" target="#seg1"/>
                  </jf:annotation>""")
        .assertXPathEquals("$output//j:concurrent/j:layer[@type='phony-annotation'][2]/jf:instruction",
          "one layer represents the instruction",
            """<jf:instruction xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0" jf:annotation="#inst1">
                      <tei:ptr xmlns:tei="http://www.tei-c.org/ns/1.0" target="#seg2"/>
                    </jf:instruction>""")
        .go
    }
  }
}