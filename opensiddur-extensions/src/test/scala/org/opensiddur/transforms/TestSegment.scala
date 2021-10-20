package org.opensiddur.transforms

import org.opensiddur.DbTest

class TestSegment extends DbTest {
  override val prolog: String =
    """xquery version "3.1";

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";
import module namespace segment="http://jewishliturgy.org/transform/segment"
  at "xmldb:exist:/db/apps/opensiddur-server/transforms/segment.xqm";

import module namespace deepequality="http://jewishliturgy.org/modules/deepequality"
  at "xmldb:exist:/db/apps/opensiddur-server/modules/deepequality.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";
   """

  describe("segment:segment") {
    it("is an identity transform with no streamText in the input") {
      val inputData = readXmlFile("src/test/resources/transforms/no-streamtext-input.xml")

      xq(s"""segment:segment($inputData)""")
        .assertXmlEquals(inputData)
        .go
    }

    it("segments text nodes inside the streamText") {
      val streamTextInput = """<j:streamText>
    One text node
    <tei:ptr xml:id="ptr" target="somewhere"/>
    Another text node
    <tei:anchor xml:id="anchor"/>


    <tei:w>has no xml:id</tei:w>
    Space    inside    text
    nodes    is normalized.
  </j:streamText>"""

      val expectedOutput = """<j:streamText>
    <jf:textnode xml:id="...">One text node</jf:textnode>
    <tei:ptr xml:id="ptr" target="somewhere"/>
    <jf:textnode xml:id="...">Another text node</jf:textnode>
    <tei:anchor xml:id="anchor"/>
    <tei:w xml:id="...">has no xml:id</tei:w>
    <jf:textnode xml:id="...">Space inside text nodes is normalized.</jf:textnode>
  </j:streamText>"""

      xq(s"""segment:segment($streamTextInput)""")
        .assertXmlEquals(expectedOutput)
        .go
    }
  }
}
