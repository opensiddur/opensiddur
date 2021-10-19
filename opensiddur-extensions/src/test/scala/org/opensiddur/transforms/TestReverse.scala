package org.opensiddur.transforms

import org.opensiddur.DbTest

class TestReverse extends DbTest {
  /** imports, namespaces and variables */
  override val prolog: String =
    """xquery version '3.1';

  import module namespace reverse="http://jewishliturgy.org/transform/reverse"
    at "xmldb:exist:///db/apps/opensiddur-server/transforms/reverse.xqm";
  import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
    at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

  declare namespace tei="http://www.tei-c.org/ns/1.0";
  declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
  declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";
    """

  override def beforeAll: Unit = {
    super.beforeAll

    setupUsers(1)
  }

  override def afterAll(): Unit = {
    teardownUsers(1)

    super.afterAll()
  }
  
  describe("reverse:reverse-document") {
    it("reverses a document that only has a streamText") {
      val document = readXmlFile("src/test/resources/transforms/Reverse/reverse1.xml")
      
      xq(s"""reverse:reverse-document(
        document { $document }, 
        map {})""")
        .assertXPath("""empty($output//*[@jf:id]) """, "No @jf:id attributes")
        .assertXPath("""empty($output//*[@jf:stream]) """, "No @jf:stream attributes")
        .assertXPath("""exists($output//j:streamText[@xml:id][tei:seg]) """, "A j:streamText exists")
        .assertXPath("""count($output//j:streamText/*) = 3 and (every $child in $output//j:streamText/* satisfies exists($child/@xml:id)) """, "Every child of j:streamText has @xml:id")
        .go
    }
    
    it("reverses a streamText and one layer to j:concurrent content that includes a layer") {
      val document = readXmlFile("src/test/resources/transforms/Reverse/reverse2.xml")
      val expected = readXmlFile("src/test/resources/transforms/Reverse/reverse2-reversed.xml")

      xq(s"""reverse:reverse-document(
        document { $document }, 
        map {})/*""")
        .assertXPath("""exists($output//j:concurrent) """, "A j:concurrent exists")
        .assertXPath("""empty($output//jf:concurrent) """, "jf:concurrent does not exist")
        .assertXmlEquals(expected)
        .go
    }

    it("reverses streamText and concurrent layers to a j:concurrent that includes both layers") {
      val document = readXmlFile("src/test/resources/transforms/Reverse/reverse3.xml")
      val expected = readXmlFile("src/test/resources/transforms/Reverse/reverse3-reversed.xml")

      xq(s"""reverse:reverse-document(
        document { $document },
        map {})/*""")
        .assertXmlEquals(expected)
        .go
    }

    it("reverses a layer with suspend/resume to a j:concurrent with a reconstituted suspended layer") {
      val document = readXmlFile("src/test/resources/transforms/Reverse/reverse4.xml")
      val expected = readXmlFile("src/test/resources/transforms/Reverse/reverse4-reversed.xml")

      xq(s"""reverse:reverse-document(
        document { $document },
        map {})/*""")
        .assertXmlEquals(expected)
        .go
    }

    it("reverses concurrent layers with overlapping suspend/resume to a j:concurrent that includes the suspended layers") {
      val document = readXmlFile("src/test/resources/transforms/Reverse/reverse5.xml")
      val expected = readXmlFile("src/test/resources/transforms/Reverse/reverse5-reversed.xml")

      xq(s"""reverse:reverse-document(
        document { $document },
        map {})/*""")
        .assertXmlEquals(expected)
        .go
    }
  }
}
