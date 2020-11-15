package org.opensiddur.modules

import org.opensiddur.DbTest

class TestUpgrade12 extends DbTest {
  override val prolog =
    """xquery version '3.1';

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
 at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

import module namespace upg12="http://jewishliturgy.org/modules/upgrade12"
  at "xmldb:exist:/db/apps/opensiddur-server/modules/upgrade12.xqm";

import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "xmldb:exist:/db/apps/opensiddur-server/modules/refindex.xqm";
import module namespace didx="http://jewishliturgy.org/modules/docindex"
  at "xmldb:exist:/db/apps/opensiddur-server/modules/docindex.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:/db/apps/opensiddur-server/magic/magic.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

    """

    override def beforeAll: Unit = {
      super.beforeAll
      setupUsers(1)
      setupResource("src/test/resources/modules/upgrade12/referenced.xml", "Referenced_File", "original", 1, Some("en"))
      setupResource("src/test/resources/modules/upgrade12/external-references.xml", "External_References", "original", 1, Some("en"))
    }

    override def afterAll(): Unit = {
      teardownResource("Referenced_File", "original", 1)
      teardownResource("External_References", "original", 1)
      teardownUsers(1)
      super.afterAll()
    }

  describe("upg12:upgrade") {
    it("changes the reference file") {
      xq("""upg12:upgrade(doc("/db/data/original/en/Referenced_File.xml"))/*""")
        .assertXmlEquals("""<tei:TEI>
                           |    <tei:teiHeader>
                           |      <tei:fileDesc>
                           |        <tei:titleStmt>
                           |          <tei:title xml:lang="en">Test file</tei:title>
                           |        </tei:titleStmt>
                           |      </tei:fileDesc>
                           |      <tei:sourceDesc>
                           |        <tei:bibl j:docStatus="outlined">
                           |          <tei:title>Biblio</tei:title>
                           |          <tei:ptr xml:id="non_seg_internal_ptr" type="bibl-content" target="#stream"/>
                           |        </tei:bibl>
                           |      </tei:sourceDesc>
                           |    </tei:teiHeader>
                           |    <tei:text>
                           |      <j:streamText xml:id="stream">
                           |        <tei:anchor xml:id="begin_p_1"/>
                           |        <tei:anchor xml:id="seg_1"/>seg 1 middle segment. <tei:anchor xml:id="seg_3"/>
                           |        <tei:w>segment</tei:w>
                           |        <tei:w>with</tei:w>
                           |        <tei:w>internal</tei:w>
                           |        <tei:w>structure</tei:w>
                           |        <tei:anchor xml:id="seg_3_end"/> <tei:ptr xml:id="internal_ptr_to_segments" target="#range(seg_1,seg_3_end)"/>
                           |        <tei:ptr xml:id="internal_ptr_to_one_segment" target="#range(seg_3,seg_3_end)"/>
                           |        <tei:anchor xml:id="end_p_1"/>
                           |        <tei:anchor xml:id="seg_4"/>Referenced by an internal pointer Outside a streamText<tei:anchor xml:id="seg_5_end"/> <tei:anchor xml:id="begin_p_3"/>
                           |        <tei:anchor xml:id="seg_6"/>Referenced externally without a range<tei:anchor xml:id="seg_6_end"/> Unreferenced. <tei:anchor xml:id="seg_8"/>Referenced externally with a range.<tei:anchor xml:id="seg_10_end"/> <tei:anchor xml:id="seg_11"/>Multiple range<tei:anchor xml:id="seg_12_end"/> <tei:anchor xml:id="seg_13"/>references<tei:anchor xml:id="seg_13_end"/> <tei:anchor xml:id="seg_14"/>in the same ptr<tei:anchor xml:id="seg_15_end"/> <tei:ptr xml:id="external_ptr" type="url" target="http://www.external.com"/>
                           |        <tei:anchor xml:id="end_p_3"/>
                           |      </j:streamText>
                           |      <j:concurrent type="p">
                           |        <tei:p>
                           |          <tei:ptr xml:id="internal_ptr_to_anchors" target="#range(begin_p_1,end_p_1)"/>
                           |        </tei:p>
                           |        <tei:p>
                           |          <tei:ptr xml:id="internal_ptr_to_segs" target="#range(seg_4,seg_5_end)"/>
                           |        </tei:p>
                           |        <tei:p>
                           |          <tei:ptr xml:id="multiple_references_in_one" target="#range(seg_11,seg_12_end) #range(seg_13,seg_13_end) #range(seg_14,seg_15_end)"/>
                           |        </tei:p>
                           |      </j:concurrent>
                           |    </tei:text>
                           |  </tei:TEI>""".stripMargin)
        .go
    }

    it("changes the external reference file") {
      xq("""upg12:upgrade(doc("/db/data/original/en/External_References.xml"))/*""")
        .assertXmlEquals("""<tei:TEI>
                           |    <tei:teiHeader>
                           |      <tei:fileDesc>
                           |        <tei:titleStmt>
                           |          <tei:title xml:lang="en">External reference file</tei:title>
                           |        </tei:titleStmt>
                           |      </tei:fileDesc>
                           |    </tei:teiHeader>
                           |    <tei:text>
                           |      <j:streamText xml:id="stream">
                           |        <tei:ptr xml:id="external_reference_to_stream" target="/data/original/Referenced_File#stream"/>
                           |        <tei:ptr xml:id="external_reference_to_seg" target="/data/original/Referenced_File#range(seg_6,seg_6_end)"/>
                           |        <tei:ptr xml:id="external_reference_to_range" target="/data/original/Referenced_File#range(seg_8,seg_10_end)"/>
                           |        <tei:ptr xml:id="external_reference_to_ptr" target="/data/original/Referenced_File#external_ptr"/>
                           |      </j:streamText>
                           |    </tei:text>
                           |  </tei:TEI>""".stripMargin)
        .go
    }
  }
}
