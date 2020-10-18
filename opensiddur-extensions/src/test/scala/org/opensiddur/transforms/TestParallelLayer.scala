package org.opensiddur.transforms

import org.opensiddur.DbTest

class TestParallelLayer extends DbTest {
  override val prolog =
    """xquery version '3.1';

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
at "xmldb:exist:///db/apps/opensiddur-server/modules/format.xqm";
import module namespace pla="http://jewishliturgy.org/transform/parallel-layer"
  at "xmldb:exist:///db/apps/opensiddur-server/transforms/parallel-layer.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "xmldb:exist:///db/apps/opensiddur-server/modules/refindex.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

    """

  override def beforeAll: Unit = {
    super.beforeAll
    setupUsers(1)
    setupResource("src/test/resources/transforms/identity.xml", "identity", "original", 1, Some("en"))
    setupResource("src/test/resources/transforms/parA.xml", "parA", "original", 1, Some("en"))
    setupResource("src/test/resources/transforms/parB.xml", "parB", "original", 1, Some("en"))
    setupResource("src/test/resources/transforms/par.xml", "par", "linkage", 1)
  }

  override def afterAll(): Unit = {
    teardownResource("par", "linkage", 1)
    teardownResource("parA", "original", 1)
    teardownResource("parB", "original", 1)
    teardownResource("identity", "original", 1)
    teardownUsers(1)
    super.afterAll()
  }

  describe("pla:parallel-layer-document") {
    it("acts as an identity transform when there is no parallel text") {
      val expectedData = readXmlFile("src/test/resources/transforms/identity.xml")

      xq("""pla:parallel-layer-document(
                           doc("/db/data/original/en/identity.xml"),
                           map {}
                         )/*""")
        .user("xqtest1")
        .assertXmlEquals(expectedData)
        .go
    }
  }
  
  describe("format:parallel-layer") {
    it("produces a parallel document, given the linkage and original docs") {
      xq("""let $d := doc("/db/data/linkage/par.xml")
           return format:parallel-layer($d, map {}, $d)""")
        .user("xqtest1")
        .assertXPath("""exists($output/jf:parallel-document[tei:idno='Test'])""", "produces one jf:paellel-document")
        .assertXPath("""count($output//@xml:id)=0 and count($output//@jf:id) > 0""", "all xml:ids have been converted into @jf:id")
        .assertXPath("""count($output/jf:parallel-document/tei:TEI)=2""", "two tei:TEI elements exist")
        .assertXPath("""contains($output/jf:parallel-document/tei:TEI[1]/@jf:document, "/parA") and contains($output/jf:parallel-document/tei:TEI[2]/@jf:document, "/parB")""", "each tei:TEI element has a @jf:document")
        .assertXPath("""contains($output/jf:parallel-document/tei:TEI[1]/@xml:base, "/parA") and contains($output/jf:parallel-document/tei:TEI[2]/@xml:base, "/parB")""", "each tei:TEI element has an @xml:base")
        .assertXPath("""exists($output/jf:parallel-document/tei:TEI[1]//j:concurrent[count(j:layer)=1]/j:layer[@type='parallel'])""", "a j:concurrent and j:layer have been added to parA")
        .assertXPath("""exists($output/jf:parallel-document/tei:TEI[2]//j:concurrent[count(j:layer)=2]/j:layer[@type='parallel'])""", "a j:layer has been added to parB")
        .assertXPath("""every $layer in $output//j:concurrent/j:layer[@type='parallel'] satisfies count($layer/jf:parallelGrp/jf:parallel/tei:ptr)=3""", "the added layer contains the same number of tei:ptr as the parallel document contains links")
        .assertXPath("""every $ptr in $output//j:concurrent/j:layer[@type='parallel']/jf:parallelGrp/jf:parallel/tei:ptr satisfies starts-with($ptr/@target, '#') and string-length($ptr/@target)>1""", "Each tei:ptr is a local ptr")
        .go
    }
  }

}
