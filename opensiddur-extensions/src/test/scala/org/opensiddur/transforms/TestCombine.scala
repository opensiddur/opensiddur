package org.opensiddur.transforms

import org.opensiddur.DbTest

class TestCombine extends DbTest {
  override val prolog =
    """xquery version '3.1';

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

import module namespace format="http://jewishliturgy.org/modules/format"
  at "xmldb:exist:///db/apps/opensiddur-server/modules/format.xqm";
import module namespace mirror="http://jewishliturgy.org/modules/mirror"
  at "xmldb:exist:///db/apps/opensiddur-server/modules/mirror.xqm";
import module namespace combine="http://jewishliturgy.org/transform/combine"
  at "xmldb:exist:///db/apps/opensiddur-server/transforms/combine.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "xmldb:exist:///db/apps/opensiddur-server/modules/refindex.xqm";
"""

  def setupResourceForTest(resourceName: String, dataType: String = "original") = {
    setupResource("src/test/resources/transforms/" + resourceName + ".xml",
      resourceName, dataType, 1, if (dataType == "original") Some("en") else None,
      Some("everyone"), Some("rw-rw-r--"))
    xq(
      s"""
          let $$name := '/db/data/$dataType/${if (dataType == "original") "en/" else ""}$resourceName.xml'
          let $$segmented := format:unflatten-dependencies(doc($$name), map {})
          return ()""").go
  }
  
  override def beforeAll: Unit = {
    super.beforeAll
    setupUsers(1)
    setupResourceForTest("combine1")
    setupResourceForTest("combine2")
    setupResourceForTest("combine3")
    setupResourceForTest("combine-repeat")
    setupResourceForTest("combine-cond1")
    setupResourceForTest("combine-cond2")
    setupResourceForTest("combine-cond3")
    setupResourceForTest("combine-inline-dest")
    setupResourceForTest("combine-inline-source")
    setupResourceForTest("combine-settings")
    setupResourceForTest("parallel-simple-A")
    setupResourceForTest("parallel-same-A")
    setupResourceForTest("parallel-simple-B")
    setupResourceForTest("parallel-part-A")
    setupResourceForTest("parallel-part-B")
    setupResourceForTest("include-simple-1")
    setupResourceForTest("include-part-1")
    setupResourceForTest("include-part-2")
    setupResourceForTest("linkage-simple", "linkage")
    setupResourceForTest("linkage-same", "linkage")
    setupResourceForTest("linkage-part", "linkage")
    setupResourceForTest("combine-cond-parA")
    setupResourceForTest("combine-cond-parB")
    setupResourceForTest("combine-cond-incl")
    setupResourceForTest("combine-cond-par", "linkage")
    setupResourceForTest("combine-ann-notes", "notes")
    setupResourceForTest("combine-ann1")
    setupResourceForTest("combine-ann2")
    setupResourceForTest("combine-ann-parA")
    setupResourceForTest("combine-ann-parB")
    setupResourceForTest("combine-ann-par", "linkage")
    setupResourceForTest("combine-ann-incl")
    setupResourceForTest("combine-style-2")
    setupResourceForTest("combine-style-1")
    setupResourceForTest("combine-segGen-1")
    setupResourceForTest("combine-translit-note-1", "notes")
    setupResourceForTest("combine-translit-1")
    setupResource("src/test/resources/transforms/testtable.xml", "testtable", "transliteration", 1)
  }

  override def afterAll(): Unit = {
    teardownResource("testtable", "transliteration", 1)
    teardownResource("combine-translit-note-1", "notes", 1)
    teardownResource("combine-translit-1", "original", 1)
    teardownResource("combine-segGen-1", "original", 1)
    teardownResource("combine-style-1", "original", 1)
    teardownResource("combine-style-2", "original", 1)
    teardownResource("combine-ann-incl", "original", 1)
    teardownResource("combine-ann-par", "linkage", 1)
    teardownResource("combine-ann-parB", "original", 1)
    teardownResource("combine-ann-parA", "original", 1)
    teardownResource("combine-ann2", "original", 1)
    teardownResource("combine-ann1", "original", 1)
    teardownResource("combine-ann-notes", "notes", 1)
    teardownResource("combine-cond-par", "linkage", 1)
    teardownResource("combine-cond-incl", "original", 1)
    teardownResource("combine-cond-parB", "original", 1)
    teardownResource("combine-cond-parA", "original", 1)
    teardownResource("linkage-part", "linkage", 1)
    teardownResource("linkage-same", "linkage", 1)
    teardownResource("linkage-simple", "linkage", 1)
    teardownResource("include-part-2", "original", 1)
    teardownResource("include-part-1", "original", 1)
    teardownResource("include-simple-1", "original", 1)
    teardownResource("parallel-part-B", "original", 1)
    teardownResource("parallel-part-A", "original", 1)
    teardownResource("parallel-simple-B", "original", 1)
    teardownResource("parallel-same-A", "original", 1)
    teardownResource("parallel-simple-A", "original", 1)
    teardownResource("combine-settings", "original", 1)
    teardownResource("combine-inline-source", "original", 1)
    teardownResource("combine-inline-dest", "original", 1)
    teardownResource("combine-cond3", "original", 1)
    teardownResource("combine-cond2", "original", 1)
    teardownResource("combine-cond1", "original", 1)
    teardownResource("combine-repeat", "original", 1)
    teardownResource("combine3", "original", 1)
    teardownResource("combine2", "original", 1)
    teardownResource("combine1", "original", 1)
    teardownUsers(1)
    super.afterAll()
  }

  describe("combine:combine-document") {
    it("acts as an identity transform") {
      xq("""combine:combine-document(
           mirror:doc($format:unflatten-cache, "/db/data/original/en/combine1.xml"),
           map {})""")
        .assertXPath("""matches($output/tei:TEI/@jf:document,"^((/exist/restxq)?/api)?/data/original/combine1$")""", "has @jf:document on root element")
        .assertXPath("""exists($output/tei:TEI/tei:text/jf:combined[@jf:id="stream"]/tei:seg[@jf:id="seg1"][ends-with(@jf:stream,"#stream")])""", "acts as an identity transform for unflattened text")
        .go
    }
    
    it("incorporates a local pointer with one segment in place") {
      xq("""combine:combine-document(
          mirror:doc($format:unflatten-cache, "/db/data/original/en/combine2.xml"),
          map {})""")
        .assertXPath("""matches($output/tei:TEI/@jf:document,"^((/exist/restxq)?/api)?/data/original/combine2$")""", "has @jf:document on root element")
        .assertXPath("""exists($output/tei:TEI/tei:text/jf:combined[@jf:id="stream"]/jf:ptr[@jf:id="ptr1"][ends-with(@jf:stream,"#stream")]/tei:seg[@jf:id="seg1"])""", "incorporate destination in-place")
        .assertXPath("""empty($output/tei:TEI/tei:text/jf:combined[@jf:id="stream"]/jf:ptr[@jf:id="ptr1"][ends-with(@jf:stream,"#stream")]/@jf:document)""",
          "no @jf:document attribute on jf:ptr")
        .go
    }
    
    it("incorporates a local pointer with multiple repeats") {
      xq("""combine:combine-document(
                               mirror:doc($format:unflatten-cache, "/db/data/original/en/combine-repeat.xml"),
                               map {}
                           )""")
      .assertXPath("""count($output/tei:TEI/tei:text/jf:combined[@jf:id="stream"]/jf:ptr[ends-with(@jf:stream,"#stream")]/tei:seg[@jf:id="repeated"])=3""",
        "incorporate destination in-place once each time it is referenced")
        .assertXPath("""every $repeat in $output/tei:TEI/tei:text/jf:combined[@jf:id="stream"]/jf:ptr[ends-with(@jf:stream,"#stream")] satisfies count($repeat/tei:seg[@jf:id="repeated"])=1
        """, "incorporate destination in-place once each time it is referenced")
        .assertXPath("""
          empty($output/tei:TEI/tei:text/jf:combined[@jf:id="stream"]/jf:ptr/@jf:document)
        """, "no @jf:document attribute on any jf:ptr")
        .go
    }
    
    it("combines data with inclusion for an external pointer") {
      xq("""combine:combine-document(
                               mirror:doc($format:unflatten-cache, "/db/data/original/en/combine3.xml"),
                               map {}
                           )""")
      .assertXPath("""matches($output/tei:TEI/@jf:document,"^((/exist/restxq)?/api)?/data/original/combine3$")""", "has @jf:document on root element")
        .assertXPath("""matches($output/tei:TEI//jf:ptr[@jf:id="ptr1"]/@jf:document,"^((/exist/restxq)?/api)?/data/original/combine1$")""", "has @jf:document on the included element")
        .assertXPath("""exists($output/tei:TEI/tei:text/jf:combined[@jf:id="stream"]/jf:ptr[@jf:id="ptr1"][ends-with(@jf:stream,"#stream")]/tei:seg[@jf:id="seg1"])
        """, "incorporate destination in-place")
        .go
    }

    it("combines an inline range pointer") {
      xq("""combine:combine-document(
                               mirror:doc($format:unflatten-cache, "/db/data/original/en/combine-inline-source.xml"),
                               map {}
                           )""")
        .assertXPath("""count($output/tei:TEI/tei:text/jf:combined[@jf:id="stream"]/tei:p[@jf:layer-id]/jf:ptr[@type="inline"][@jf:id="ptr2"][ends-with(@jf:stream, "#stream")]/tei:seg)=3""",
          "inline pointer included in place")
        .go
    }

  }

  describe("combine:tei-fs-to-map") {
    it("handles fs/f/symbol") {
      xq(
        """let $m := combine:tei-fs-to-map(
          <tei:fs type="FS">
            <tei:f name="FSYMBOL">
              <tei:symbol value="SYMBOL"/>
            </tei:f>
          </tei:fs>,
          map {}
        )
        return $m("FS->FSYMBOL")
          """)
        .assertXmlEquals("""<tei:string xmlns:tei="http://www.tei-c.org/ns/1.0">SYMBOL</tei:string>""")
        .go
    }
    
    it("handles fs/f/binary") {
      xq(
        """let $m := combine:tei-fs-to-map(
          <tei:fs type="FS">
            <tei:f name="FBINARY">
              <tei:binary value="1"/>
            </tei:f>
          </tei:fs>,
          map {}
        )
        return $m("FS->FBINARY")
          """)
        .assertXmlEquals("""<tei:string xmlns:tei="http://www.tei-c.org/ns/1.0">true</tei:string>""")
        .go
    }
    
    it("handles fs/f/yes") {
      xq(
        """let $m := combine:tei-fs-to-map(
          <tei:fs type="FS">
            <tei:f name="FYES">
              <j:yes/>
            </tei:f>
          </tei:fs>,
          map {}
        )
        return $m("FS->FYES")
          """)
        .assertXmlEquals("""<tei:string xmlns:tei="http://www.tei-c.org/ns/1.0">YES</tei:string>""")
        .go
    }
    
    it("handles fs/f/string") {
      xq(
        """let $m := combine:tei-fs-to-map(
          <tei:fs type="FS">
            <tei:f name="FSTRING"><tei:string>string</tei:string></tei:f>
          </tei:fs>,
          map {}
        )
        return $m("FS->FSTRING")
          """)
        .assertXmlEquals("""<tei:string xmlns:tei="http://www.tei-c.org/ns/1.0">string</tei:string>""")
        .go
    }
    
    it("handles fs/f/text()") {
      xq(
        """let $m := combine:tei-fs-to-map(
          <tei:fs type="FS">
            <tei:f name="FTEXT">text</tei:f>
          </tei:fs>,
          map {}
        )
        return $m("FS->FTEXT")
          """)
        .assertXmlEquals("""<tei:string xmlns:tei="http://www.tei-c.org/ns/1.0">text</tei:string>""")
        .go
    }

    it("handles fs/f/vColl") {
      xq(
        """let $m := combine:tei-fs-to-map(
          <tei:fs type="FS">
            <tei:f name="FVCOLL">
              <tei:vColl>
                <tei:symbol value="S1"/>
                <tei:symbol value="S2"/>
                <tei:symbol value="S3"/>
              </tei:vColl>
            </tei:f>
          </tei:fs>,
          map {}
        )
        return $m("FS->FVCOLL")
          """)
        .assertXmlEquals("""<tei:string xmlns:tei="http://www.tei-c.org/ns/1.0">S1</tei:string>""",
               """<tei:string xmlns:tei="http://www.tei-c.org/ns/1.0">S2</tei:string>""",
               """<tei:string xmlns:tei="http://www.tei-c.org/ns/1.0">S3</tei:string>""")
        .go
    }
  }

  describe("combine:update-settings-from-standoff-markup") {
    it("updates settings for a segment with inbound links") {
      xq(
        """
           let $m :=
        combine:update-settings-from-standoff-markup(
          mirror:doc($format:unflatten-cache, "/db/data/original/en/combine-settings.xml")//tei:seg[@jf:id="seg1"]/parent::jf:set,
          map { "combine:settings" : map {} },
          false()
        )
        return $m("combine:settings")("FS1->F1")
          """)
        .assertEquals("ONE")
        .go
    }
    
    it("updates settings for a segment with no inbound links") {
      xq("""let $m :=
        combine:update-settings-from-standoff-markup(
          mirror:doc($format:unflatten-cache, "/db/data/original/en/combine-settings.xml")//tei:seg[@jf:id="seg2"],
          map { "combine:settings" : map {} },
          false()
        )
        return count(map:keys($m("combine:settings")))""")
        .assertEquals(0)
        .go
    }
    
    it("updates settings with ancestors for segment with inbound link") {
      xq("""
        combine:update-settings-from-standoff-markup(
          mirror:doc($format:unflatten-cache, "/db/data/original/en/combine-settings.xml")//tei:seg[@jf:id="seg1"]/parent::jf:set,
          map { "combine:settings" : map {} },
          true()
        )""")
        .assertXPath("""$output("combine:settings")("FS1->F2")="THREE"""",
        "non-overridden setting from ancestor is retained")
        .assertXPath("""$output("combine:settings")("FS1->F1")="ONE"""", "overridden setting from ancestor is overridden")
        .assertXPath("""$output("combine:settings")("FS1->F3")="FOUR"""", "non-overridden setting from this is retained")
        .go
    }
  }

  describe("combine:combine-document") {
    it("handles parallel texts with simple inclusion set inside the stream") {
      xq(
        """combine:combine-document(
          mirror:doc($format:unflatten-cache, "/db/data/original/en/include-simple-1.xml"),
          map {})""")
        .assertXPath("""$output//jf:ptr[@jf:id="inc3"]/jf:combined[jf:parallelGrp]""", "the inclusion pointer is followed through a redirect")
        .assertXPath("""$output//jf:ptr[@jf:id="inc3"]/jf:combined/jf:parallelGrp/jf:parallel/@domain="/data/original/parallel-simple-A#stream"""", "the correct domain is chosen")
        .assertXPath("""$output//jf:ptr[@jf:id="inc3"]/jf:combined/jf:parallelGrp/jf:parallel[@domain="/data/original/parallel-simple-A#stream"]/tei:seg[.="A-1"]""", "the redirect includes the original text")
        .assertXPath("""$output//jf:ptr[@jf:id="inc3"]/jf:combined/jf:parallelGrp/jf:parallel[@domain="/data/original/parallel-simple-B#stream"]/tei:seg[.="B-1"]""", "the redirect includes the parallel text")
        .go
    }

    it("handles simple parallelism when the parallism is set in the same document as it is used") {
      xq(
        """combine:combine-document(
          mirror:doc($format:unflatten-cache, "/db/data/original/en/parallel-same-A.xml"),
          map {})""")
        .assertXPath("""exists($output//tei:text/jf:combined[@jf:id="stream"]/jf:combined[jf:parallelGrp])""", "the stream is redirected")
        .assertXPath("""$output//jf:combined/jf:parallelGrp[starts-with(@jf:layer-id, "/data/original/parallel-same-A")]""", "the correct domain is chosen")
        .assertXPath("""$output//jf:combined/jf:parallelGrp/jf:parallel[@domain="/data/original/parallel-same-A#stream"]/tei:seg[.="A-1"]""", "the redirect includes the original text")
        .assertXPath("""$output//jf:combined/jf:parallelGrp/jf:parallel[@domain="/data/original/parallel-simple-B#stream"]/tei:seg[.="B-1"]""", "the redirect includes the parallel text")
        .go
    }

    it("handles a request for a part of a parallel document: include where the boundaries are the same as the " +
      "boundaries of the parallelism") {
      xq(
        """combine:combine-document(
          mirror:doc($format:unflatten-cache, "/db/data/original/en/include-part-1.xml"),
          map {})""")
        .assertXPath("""exists($output//tei:text/jf:combined[@jf:id="stream"]/descendant::jf:ptr[@jf:id="inc1"]/jf:parallelGrp)""", "the stream is redirected")
        .assertXPath("""exists($output//jf:parallelGrp[starts-with(@jf:layer-id,"/data/original/parallel-part-A")])""", "the correct domain is chosen")
        .assertXPath("""$output//jf:ptr[@jf:id="inc1"]/jf:parallelGrp[1]/jf:parallel[@domain="/data/original/parallel-part-A#stream"]/tei:seg[1]/@jf:id="A2"""", "the redirect begins at the first requested part")
        .assertXPath("""$output//jf:ptr[@jf:id="inc1"]/jf:parallelGrp[last()]/jf:parallel[@domain="/data/original/parallel-part-A#stream"]/tei:seg[last()]/@jf:id="A7"""", "the redirect ends at the last requested part")
        .go
    }

    it("handles a request for a part of a parallel document: include where the boundaries are different from the " +
      "boundaries of the parallelism") {
      xq(
        """combine:combine-document(
          mirror:doc($format:unflatten-cache, "/db/data/original/en/include-part-2.xml"),
          map {})""")
        .assertXPath("""exists($output//tei:text/jf:combined[@jf:id="stream"]/descendant::jf:ptr[@jf:id="inc2"]/jf:parallelGrp)""", "the stream is redirected")
        .assertXPath("""exists($output//jf:parallelGrp[starts-with(@jf:layer-id,"/data/original/parallel-part-A")])""", "the correct domain is chosen")
        .assertXPath("""$output//jf:ptr[@jf:id="inc2"]/jf:parallelGrp[1]/jf:parallel[@domain="/data/original/parallel-part-A#stream"]/tei:seg[1]/@jf:id="A2"""", "the redirect begins at the first parallelGrp that includes the beginning of the first requested part")
        .assertXPath("""$output//jf:ptr[@jf:id="inc2"]/jf:parallelGrp[last()]/jf:parallel[@domain="/data/original/parallel-part-A#stream"]/tei:seg[last()]/@jf:id="A7"""", "the redirect ends at the last parallelGrp that includes the end of the last requested part")
        .go
    }

    it("handles conditionals during combine that affect the streamText: inside a streamText") {
      xq(
        """combine:combine-document(
          mirror:doc($format:unflatten-cache, "/db/data/original/en/combine-cond1.xml"),
          map {})""")
        .assertXPath("""exists($output//*[@jf:id="seg1"]/parent::jf:conditional)""", "seg1 exists and is directly enclosed in a jf:conditional")
        .assertXPath("""empty($output//*[@jf:id="seg2"])""", "seg2 does not exist at all")
        .assertXPath("""exists($output//*[@jf:id="seg3"]/parent::jf:conditional[jf:annotated])""", "seg3 has an instruction added")
        .go
    }

    it("handles conditionals during combine that affect layers") {
      xq(
        """combine:combine-document(
          mirror:doc($format:unflatten-cache, "/db/data/original/en/combine-cond2.xml"),
          map {})""")
        .assertXPath("""exists($output//*[@jf:id="div1"][@jf:conditional])""", "on condition has a @jf:conditional and exists")
        .assertXPath("""empty($output//*[@jf:id="div2"])""", "off condition: layer element that is off is not present ")
        .assertXPath("""empty($output//*[@jf:id="ab2"])""", "off condition: layer-based child of element that is off is not present")
        .assertXPath("""empty($output//tei:head[.="Heading2"])""", "off condition: layer element without xml:id is not present")
        .assertXPath("""exists($output//*[@jf:id="ab_wrapper"])""", "off condition: other layers are unaffected")
        .assertXPath("""exists($output//*[@jf:id="seg3"]) and exists($output//*[@jf:id="seg4"])""", "off condition: segments are present")
        .go
    }

    it("handles conditionals with j:option") {
      xq(
        """combine:combine-document(
          mirror:doc($format:unflatten-cache, "/db/data/original/en/combine-cond3.xml"),
          map {})""")
        .assertXPath("""empty($output//jf:conditional)""", "no jf:conditional elements have been added")
        .assertXPath("""exists($output//j:option[@jf:id="opt1"][@jf:conditional]) and exists($output//tei:seg[@jf:id="seg1"])""", "opt1 and seg1 exist")
        .assertXPath("""empty($output//j:option[@jf:id="opt2"]) and empty($output//tei:seg[@jf:id="seg2"])""", "opt2 and seg2 removed")
        .assertXPath(
          """exists($output//j:option[@jf:id="opt3"][@jf:conditional][@jf:conditional-instruction][descendant::jf:annotated]) 
            and exists($output//tei:seg[@jf:id="seg3"])""", "opt3 and seg3 exist, an instruction has been added")
        .assertXPath("""exists($output//j:option[@jf:id="opt4"][@jf:conditional][tei:w])""", "opt4 exists")
        .assertXPath("""empty($output//j:option[@jf:id="opt5"]) and empty($output//tei:w[.="E"])""", "opt5 removed")
        .assertXPath("""exists($output//j:option[@jf:id="opt6"][@jf:conditional][@jf:conditional-instruction][jf:annotated][tei:w])""", "opt6 exists, an instruction has been added")
        .go
    }

    it("handles conditionals and parallel texts together") {
      xq(
        """combine:combine-document(
                mirror:doc($format:unflatten-cache, "/db/data/original/en/combine-cond-incl.xml"),
                map {})""")
        .assertXPath("""exists($output//jf:parallel[starts-with(@jf:layer-id, "/data/original/combine-cond-parA")]/tei:seg[@jf:id="present"])""", "in parA, present is present")
        .assertXPath("""empty($output//jf:parallel[starts-with(@jf:layer-id, "/data/original/combine-cond-parA")]/descendant::tei:seg[@jf:id="offAext"])""", "in parA, segment turned off externally is not present")
        .assertXPath("""empty($output//jf:parallel[starts-with(@jf:layer-id, "/data/original/combine-cond-parA")]/descendant::tei:seg[@jf:id="offAint"])""", "in parA, segment turned off internally at streamText is not present")
        .assertXPath("""empty($output//jf:parallel[starts-with(@jf:layer-id, "/data/original/combine-cond-parA")]/descendant::tei:seg[@jf:id="offAintSetInt"])""", "in parA, segment turned off internally within stream is not present")
        .assertXPath("""exists($output//jf:parallel[starts-with(@jf:layer-id, "/data/original/combine-cond-parA")]/descendant::tei:seg[@jf:id="offBext"])""", "in parA, segment turned off externally in parB with the same id is present")
        .assertXPath("""exists($output//jf:parallel[starts-with(@jf:layer-id, "/data/original/combine-cond-parA")]/descendant::tei:seg[@jf:id="offBint"])""", "in parA, segment turned off internally in parB with the same id is present")
        .assertXPath("""exists($output//jf:parallel[starts-with(@jf:layer-id, "/data/original/combine-cond-parA")]/descendant::tei:seg[@jf:id="offBintSetInt"])""", "in parA, segment turned off internally within stream in parB is present")
        .assertXPath("""exists($output//jf:parallel[starts-with(@jf:layer-id, "/data/original/combine-cond-parB")]/tei:seg[@jf:id="present"])""", "in parB, present is present")
        .assertXPath("""empty($output//jf:parallel[starts-with(@jf:layer-id, "/data/original/combine-cond-parB")]/descendant::tei:seg[@jf:id="offBext"])""", "in parB, segment turned off externally is not present")
        .assertXPath("""empty($output//jf:parallel[starts-with(@jf:layer-id, "/data/original/combine-cond-parB")]/descendant::tei:seg[@jf:id="offBint"])""", "in parB, segment turned off internally at streamText is not present")
        .assertXPath("""empty($output//jf:parallel[starts-with(@jf:layer-id, "/data/original/combine-cond-parB")]/descendant::tei:seg[@jf:id="offBintSetInt"])""", "in parB, segment turned off internally within stream is not present")
        .go
    }
  }
  
  describe("format:combine") {
    it("handles annotations in a single text, notes of all types") {
      xq("""let $d := doc("/db/data/original/en/combine-ann1.xml")
        return
            format:combine($d, map {}, $d)""")
        .assertXPath("""exists($output//jf:combined[@jf:id="stream"][@jf:annotation]/jf:annotated/tei:note[@jf:id="stream_note"])""", "stream note is present")
        .assertXPath("""exists($output//jf:annotation[tei:seg[@jf:id="single"]]/jf:annotated/tei:note[@jf:id="single_note"])""", "single note is present")
        .assertXPath("""exists($output//jf:annotation[tei:seg[@jf:id="range1"] and tei:seg[@jf:id="range2"]]/jf:annotated/tei:note[@jf:id="range_note"])""", "range note is present")
        .assertXPath("""empty($output//tei:note[@jf:id="off_note"])""", "off note is not present")
        .assertXPath("""exists($output//tei:ab[@jf:id="ab1"][@jf:annotation]/jf:annotated/tei:note[@jf:id="layer_note"])""", "layer note is not present")
        .assertXPath("""exists($output//tei:w[@jf:id="word"][@jf:annotation]/jf:annotated/tei:note[@jf:id="word_note"])""", "word note is not present")
        .assertXPath("""every $annotated in $output//jf:annotated satisfies contains($annotated/@jf:document, "/combine-ann-notes") and $annotated/@jf:license="http://www.creativecommons.org/licenses/by/3.0"""", "annotations reference the document they came from and its license")
        .go
    }
    
    it("handles annotations in a parallel text") {
      xq("""let $d := doc("/db/data/original/en/combine-ann-incl.xml")
        return
            format:combine($d, map {}, $d)""")
        .assertXPath("""exists($output//jf:ptr[@jf:id="ptr2"]/jf:combined[@jf:id="stream"][@jf:annotation]/jf:annotated/tei:note[@jf:id="stream_note"])""", "stream annotation from parA is present")
        .assertXPath("""exists($output//jf:ptr[@jf:id="ptr2"]/descendant::jf:parallel[contains(@domain, "/combine-ann-parA")]/descendant::jf:annotation[tei:seg[@jf:id="single"]]/jf:annotated/tei:note[@jf:id="single_note"])""", "single annotation from parA is present")
        .assertXPath("""exists($output//jf:ptr[@jf:id="ptr2"]/descendant::jf:parallel[contains(@domain, "/combine-ann-parA")]/descendant::jf:annotation[tei:seg[@jf:id="range1"] and tei:seg[@jf:id="range2"]]/jf:annotated/tei:note[@jf:id="range_note"])""", "range annotation from parA is present")
        .assertXPath("""exists($output//jf:ptr[@jf:id="ptr2"]/descendant::jf:parallel[contains(@domain, "/combine-ann-parA")]/descendant::tei:seg[@jf:id="with_word"]/tei:w[@jf:annotation]/jf:annotated/tei:note[@jf:id="word_note"])""", "word annotation from parA is present")
        .assertXPath("""count($output//jf:ptr[@jf:id="ptr2"]/jf:combined[@jf:id="stream"][@jf:annotation]/jf:annotated/tei:note[@jf:id="stream_note"])=2""", "stream annotation from parB is present")
        .assertXPath("""exists($output//jf:ptr[@jf:id="ptr2"]/descendant::jf:parallel[contains(@domain, "/combine-ann-parB")]/descendant::jf:annotation[tei:seg[@jf:id="single"]]/jf:annotated/tei:note[@jf:id="single_note"])""", "single annotation from parB is present")
        .assertXPath("""exists($output//jf:ptr[@jf:id="ptr2"]/descendant::jf:parallel[contains(@domain, "/combine-ann-parB")]/descendant::jf:annotation[tei:seg[@jf:id="range1"] and tei:seg[@jf:id="range2"]]/jf:annotated/tei:note[@jf:id="range_note"])""", "range annotation from parB is present")
        .assertXPath("""exists($output//jf:ptr[@jf:id="ptr2"]/descendant::jf:parallel[contains(@domain, "/combine-ann-parB")]/descendant::tei:seg[@jf:id="with_word"]/tei:w[@jf:annotation]/jf:annotated/tei:note[@jf:id="word_note"])""", "word annotation from parB is present")
        .go
    }
    
    it("handles annotations that are broken up by concurrency") {
      xq("""let $d := doc("/db/data/original/en/combine-ann2.xml")
        return
            format:combine($d, map {}, $d)""")
        .assertXPath("""count($output//jf:annotated/tei:note[@jf:id="single_note"])=1""", "single note is present exactly once")
        .go
    }
    
    it("handles styling a document with inclusions") {
      xq("""let $d := doc("/db/data/original/en/combine-style-1.xml")
        return
            format:combine($d, map {}, $d)""")
        .assertXPath("""count($output//*[@jf:style])=1""", "only one @jf:style attribute is added")
        .assertXPath("""$output//@jf:style[1]="/data/styles/test_style"""", "the attribute points to the style in the opensiddur->style feature")
        .go
    }

    it("handles transliteration with segGen") {
      xq("""let $d := doc("/db/data/original/en/combine-segGen-1.xml")
        return
            format:combine($d, map {}, $d)""")
        .assertXPath("""$output//jf:combined/j:segGen[@jf:id="segGen1"]="ʾabbaʾ"""", "the segGen element contains the generated transliteration")
        .assertXPath("""$output//jf:combined/j:segGen[@jf:id="segGen1"]/@xml:lang="he-Latn"""", "the segGen element has an appropriate xml:lang")
        .assertXPath("""count($output//jf:combined/*)=1""", "no other elements are generated")
        .go
    }

    it("handles declared transliteration in a non-parallel document") {
      xq("""let $d := doc("/db/data/original/en/combine-translit-1.xml")
        return
            format:combine($d, map {}, $d)""")
      .assertXPath("""exists($output//jf:combined/tei:seg[@jf:id="not_transliterated"])""", "the untransliterated segment remains untransliterated")
        .assertXPath("""exists($output//jf:combined//tei:seg[@jf:id="bad_language"])""", "a transliterated segment that declares an untransliteratable xml:lang remains untransliterated")
        .assertXPath("""exists($output//jf:combined/jf:annotation/jf:annotated/tei:note/tei:seg) and empty($output//jf:combined/jf:annotation/jf:annotated/tei:note/jf:transliterated)""", "a segment inside an annotation does not get transliterated")
        .assertXPath("""exists($output//jf:combined//jf:transliterated/tei:seg[@jf:id="to_be_transliterated"]) and $output//jf:combined//jf:transliterated/tei:seg[@type="transliterated"]="ʾabbaʾ"""", "a segment inside the transliterated portion with the correct language is transliterated")
        .assertXPath("""exists($output//jf:combined//tei:seg[@jf:id="no_table"]) and empty($output//jf:combined//jf:transliterated/tei:seg[@jf:id="no_table"])""", "if the table does not exist, no transliteration")
        .go
    }
  }
}
