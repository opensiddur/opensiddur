package org.opensiddur.transforms

import org.opensiddur.DbTest

class TestCompile extends DbTest {
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
import module namespace compile="http://jewishliturgy.org/transform/compile"
  at "xmldb:exist:///db/apps/opensiddur-server/transforms/compile.xqm";
import module namespace user="http://jewishliturgy.org/api/user"
  at "xmldb:exist:///db/apps/opensiddur-server/api/user.xqm";
    """

  def setupResourceForTest(resourceName: String, dataType: String = "original") = {
    setupResource("src/test/resources/transforms/" + resourceName + ".xml",
      resourceName, dataType, 1, if (dataType == "original") Some("en") else None,
      Some("everyone"), Some("rw-rw-r--"))
    xq(
      s"""
          let $$name := '/db/data/$dataType/${if (dataType == "original") "en/" else ""}$resourceName.xml'
          let $$segmented := format:combine(doc($$name), map {}, doc($$name))
          return ()""").go
  }
  
  def setupUsersForTest() {
    xq("""let $u1 := user:put(
                             "xqtest1",
                             document {
                               <j:contributor>
                                   <tei:idno>xqtest1</tei:idno>
                                   <tei:name>Test User 10</tei:name>
                               </j:contributor>
                             }
                         )
                   let $u2 := user:put(
                             "xqtest2",
                             document {
                                 <j:contributor>
                                     <tei:idno>xqtest2</tei:idno>
                                     <tei:orgName>Organization</tei:orgName>
                                 </j:contributor>
                             }
                             )
                   return ()
         """)
  }

  override def beforeAll: Unit = {
    super.beforeAll
    setupUsers(2)
    setupUsersForTest()
    setupResourceForTest("combine1")
    setupResourceForTest("combine3")
    setupResourceForTest("compile1")
    setupResourceForTest("compile2")
    setupResourceForTest("compile3")
    setupResourceForTest("compile4")
  }

  override def afterAll(): Unit = {
    teardownResource("compile4", "original", 1)
    teardownResource("compile3", "original", 1)
    teardownResource("compile2", "original", 1)
    teardownResource("compile1", "original", 1)
    teardownResource("combine3", "original", 1)
    teardownResource("combine1", "original", 1)
    teardownUsers(2)
    super.afterAll()
  }

  describe("compile:compile-document") {
    it("acts as an identity transform") {
      xq("""compile:compile-document(
           mirror:doc($format:combine-cache, "/db/data/original/en/combine1.xml"),
           map {})""")
        .assertXPath("""exists($output/tei:TEI/tei:text/jf:combined[@jf:id="stream"]/tei:seg[@jf:id="seg1"][ends-with(@jf:stream,"#stream")])
      """, "acts as an identity transform for unflattened text")
        .assertXPath("""exists($output/tei:TEI/tei:text/tei:back/tei:div[@type="licensing"])""", "a license statement is added")
        .assertXPath("""count($output//tei:div[@type="licensing"]/tei:div[@type="license-statement"]/tei:ref[@target="http://www.creativecommons.org/publicdomain/zero/1.0"])=1""", "the license statement references 1 license")
        .go
    }
    
    it("compiles with an external pointer inclusion") {
      xq("""compile:compile-document(
          mirror:doc($format:combine-cache, "/db/data/original/en/combine3.xml"),
          map {})""")
        .assertXPath("""exists($output/tei:TEI/tei:text/tei:back/tei:div[@type="licensing"])""", "a license statement is added")
        .assertXPath("""
          let $statements := $output//tei:div[@type="licensing"]/tei:div[@type="license-statement"]
          return
          count($statements)=2 and
          exists($statements/tei:ref[@target="http://www.creativecommons.org/publicdomain/zero/1.0"]) and
          exists($statements/tei:ref[@target="http://www.creativecommons.org/licenses/by/3.0"])
        """, "the license statement references 2 licenses")
        .go
    }
    
    it("compiles the contributor list from change elements") {
      xq("""compile:compile-document(
                               mirror:doc($format:combine-cache, "/db/data/original/en/compile1.xml"),
                               map {}
                           )""")
        .assertXPath("""count($output//tei:back/tei:div[@type="contributors"]/tei:list[tei:head="Editors"]/tei:item)=2""", "returns a list of editors")
        .assertXPath("""$output//tei:div[@type="contributors"]/tei:list/(tei:item[1]/j:contributor/tei:idno="xqtest1" and tei:item[2]/j:contributor/tei:idno="xqtest2")""", "sorted by name")
        .go
    }
    
    it("compiles a contributor list from respStmt elements") {
      xq("""compile:compile-document(
                               mirror:doc($format:combine-cache, "/db/data/original/en/compile2.xml"),
                               map {}
                           )""")
      .assertXPath("""count($output//tei:back/tei:div[@type="contributors"]/tei:list)=2""", "returns a list for each key in the respStmt")
        .assertXPath("""$output//tei:div[@type="contributors"]/tei:list[tei:head="Funders"]/tei:item/j:contributor/tei:idno="xqtest2"""", "references contributor of type 'fnd' in funders list")
        .assertXPath("""$output//tei:div[@type="contributors"]/tei:list[tei:head="Transcribers"]/tei:item/j:contributor/tei:idno="xqtest1"""", "references contributor of type 'trc' in transcribers list")
        .go
    }

    it("dedupes the same user referenced more than once for the same contribution") {
      xq("""compile:compile-document(
                               mirror:doc($format:combine-cache, "/db/data/original/en/compile3.xml"),
                               map {}
                           )""")
        .assertXPath("""count($output//tei:div[@type="contributors"]/tei:list/tei:item)=1""", "returns only one reference")
        .go
    }

    it("compiles a bibliography") {
      xq("""compile:compile-document(
                               mirror:doc($format:combine-cache, "/db/data/original/en/compile4.xml"),
                               map {}
                           )""")
        .assertXPath("""count($output//tei:back/tei:div[@type="bibliography"]/tei:listBibl/tei:biblStruct)=1""", "generates a bibliography with one entry")
        .go
    }
  }

}
