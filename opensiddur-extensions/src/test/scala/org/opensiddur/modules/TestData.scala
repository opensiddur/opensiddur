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

    xq("""
    let $users := tcommon:setup-test-users(1)
    return ()
    """)
    .go
  }

  override def afterAll()  {
    xq(
      """
        let $users := tcommon:teardown-test-users(1)
        return ()
        """)
    .go

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
        .assertXPath("""$output = concat("/db/data/original/very%20long%20test%20title.xml")""")
        .go
    }

    it("returns a numbered resource when there is a resource with the same title") {
      xq("""data:new-path("original", "datatest")""")
        .assertXPath("""$output=concat(
                       "/db/data/original/datatest-1.xml"
                       )""")
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
