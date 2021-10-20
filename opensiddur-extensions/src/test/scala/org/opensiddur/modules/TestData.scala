package org.opensiddur.modules

import org.opensiddur.DbTest

class TestData extends DbTest {
  override val prolog =
    """xquery version '3.1';
      import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
       at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";
      
      import module namespace data="http://jewishliturgy.org/modules/data"
       at "xmldb:exist:/db/apps/opensiddur-server/modules/data.xqm";
      
      import module namespace magic="http://jewishliturgy.org/magic"
       at "xmldb:exist:/db/apps/opensiddur-server/magic/magic.xqm";
      
      declare namespace t="http://test.jewishliturgy.org/modules/data";
      declare namespace tei="http://www.tei-c.org/ns/1.0";
      declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
      declare namespace error="http://jewishliturgy.org/errors";
      
      declare variable $t:resource := "datatest";
      declare variable $t:noaccess := "noaccess";
      
      declare variable $t:resource-content := document {
       <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
         <tei:teiHeader>
           <tei:fileSpec>
             <tei:titleStmt>
               <tei:title>datatest</tei:title>
             </tei:titleStmt>
           </tei:fileSpec>
         </tei:teiHeader>
         <tei:text>
           Empty.
         </tei:text>
       </tei:TEI>
      };
      """

  override def beforeAll()  {
    super.beforeAll()

    setupUsers(2)
  }

  override def afterAll()  {
    teardownUsers(1)

    super.afterAll()
  }

  override def beforeEach(): Unit = {
    super.beforeEach()

    xq(
      """
        let $test-resource := tcommon:setup-resource($t:resource, "original", 1, $t:resource-content)
        let $noaccess-resource := tcommon:setup-resource($t:noaccess, "original", 1, $t:resource-content, (), "everyone", "rw-------")
        return ()
        """)
    .go
  }

  override def afterEach(): Unit = {
    xq(
      """
        let $test-resource := tcommon:teardown-resource($t:resource, "original", 1)
        let $noaccess-resource := tcommon:teardown-resource($t:noaccess, "original", 1)
        return ()
        """)
    .go

    super.afterEach()
  }

  describe("data:normalize-resource-title") {
    it("combines parts and words") {
      xq("""data:normalize-resource-title(("Part1", "Part2 Part3"), false())""")
        .assertEquals("part1-part2_part3")
        .go
    }

    it("preserves case when case-sensitive is true") {
      xq("""data:normalize-resource-title(("Part1", "Part2 Part3"), true())""")
        .assertEquals("Part1-Part2_Part3")
        .go
    }

    it("removes characters that are not letters, numbers, underscore or dash") {
      val alephPresentation = "\ufb21"
      val betDot = "\ufb31"

      val aleph = "\u05d0"
      val bet = "\u05d1"

      xq(s"""data:normalize-resource-title("a?b!c#d$$e%f^g&amp;h*i(j)k:l;m'n<o>p,q.r/s~t`u\\v|w+x=$alephPresentation$betDot", false())""")
        .assertEquals(s"abcdefghijklmnopqrstuvwx$aleph$bet")
        .go
    }

    it("disallows begin and end punctuators") {
      xq("""data:normalize-resource-title(("", "_abc-", ""), false())""")
        .assertEquals("abc")
        .go
    }

    it("disallows duplicate punctuators") {
      xq("""data:normalize-resource-title(("abc", "-def_ _ghi"), false())""")
        .assertEquals("abc-def_ghi")
        .go
    }

    it("disallows titles that start with a number") {
      xq("""data:normalize-resource-title("1 abc", false())""")
        .assertEquals("_1_abc")
        .go
    }

    it("disallows titles that are all spaces") {
      xq("""data:normalize-resource-title(("_-_", "_ _", "---"), false())""")
        .assertEquals("")
        .go
    }

    it("truncates super-long titles") {
      val superLongTitleString = "a" * 200
      xq(s"""data:normalize-resource-title("$superLongTitleString", false())""")
        .assertXPath("fn:string-length($output) = $data:max-resource-name-length")
        .go
    }
  }

  describe("data:db-path-to-api") {
    it("returns empty in a nonexistent hierarchy") {
      xq(
        "data:db-path-to-api(\"/db/code/tests/api/data.t.xml\")")
        .assertEmpty
        .go
    }

    it("returns the path to a user if the user exists") {
      xq(
        "data:db-path-to-api('/db/data/user/xqtest1.xml')"
      )
        .assertEquals("/api/user/xqtest1")
        .go
    }

    it("returns empty if a user does not exist") {
      xq("""data:db-path-to-api("/db/data/user/__nope__")""")
        .assertEmpty
        .go
    }

    it("returns the path to a document if the document exists") {
      xq("""data:db-path-to-api("/db/data/original/" || $t:resource || ".xml")""")
        .assertEquals("/api/data/original/datatest")
        .go
    }

    it("returns empty if a document does not exist") {
      xq("""data:db-path-to-api("/db/data/original/__nope__.xml")""")
        .assertEmpty
        .go
    }
  }

  describe("data:api-path-to-db") {
    it("returns the db path of a user that exists") {
      xq("""data:api-path-to-db("/api/user/xqtest1")""")
        .assertEquals("/db/data/user/xqtest1.xml")
        .go
    }

    it("returns empty when the user does not exist") {
      xq("""data:api-path-to-db("/api/user/__nope__")""")
        .assertEmpty
        .go
    }

    it("returns the db path of a document that exists") {
      xq("""data:api-path-to-db("/api/data/original/datatest")""")
        .assertEquals("/db/data/original/datatest.xml")
        .go
    }

    it("returns empty when the document does not exist") {
      xq("""data:api-path-to-db("/api/data/original/__nope__")""")
        .assertEmpty
        .go
    }

    it("throws an exception in an unsupported hierarchy") {
      xq("""data:api-path-to-db("/api/group/everyone")""")
        .assertThrows("error:NOTIMPLEMENTED")
        .go
    }
  }

  describe("data:new-path") {
    it("returns a full path when there is no resource with the same title") {
      xq("""data:new-path("original", "very long test title")""")
        .assertXPath("""$output = "/db/data/original/very%20long%20test%20title.xml" """)
        .go
    }

    it("returns a numbered resource when there is a resource with the same title") {
      xq("""data:new-path("original", "datatest")""")
        .assertXPath("""$output="/db/data/original/datatest-1.xml" """)
        .go
    }
  }

  describe("data:doc") {
    it("returns a document that exists by API path") {
      xq("""data:doc("/api/data/original/datatest")""")
        .assertXPath("$output instance of document-node()")
        .go
    }

    it("returns a document that exists by API path (without /api)") {
      xq("""data:doc("/data/original/datatest")""")
        .assertXPath("$output instance of document-node()")
        .go
    }

    it("returns empty for a nonexistent document by path") {
      xq("""data:doc("/api/data/original/__nope__")""")
        .assertEmpty
        .go
    }

    it("returns empty if a document is inaccessible") {
      xq("""data:doc("/api/data/original/noaccess")""")
        .assertEmpty
        .go
    }

    it("throws an exception for an inaccessible API") {
      xq("""data:doc("/api/test/something")""")
        .assertThrows("error:NOTIMPLEMENTED")
        .go
    }
  }
}
