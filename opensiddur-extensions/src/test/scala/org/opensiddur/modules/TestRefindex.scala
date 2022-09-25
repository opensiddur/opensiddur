package org.opensiddur.modules

import org.opensiddur.DbTest

class BaseTestRefindex extends DbTest {
  override val prolog =
    """xquery version '3.1';
      import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
       at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

      import module namespace ridx="http://jewishliturgy.org/modules/refindex"
        at "xmldb:exist:///db/apps/opensiddur-server/modules/refindex.xqm";
      import module namespace mirror="http://jewishliturgy.org/modules/mirror"
        at "xmldb:exist:///db/apps/opensiddur-server/modules/mirror.xqm";
      import module namespace magic="http://jewishliturgy.org/magic"
        at "xmldb:exist:///db/apps/opensiddur-server/magic/magic.xqm";

      declare namespace tei="http://www.tei-c.org/ns/1.0";
      declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
      """
  override def beforeAll() {
    super.beforeAll()

    xq(
      """
    let $users := tcommon:setup-test-users(1)
    let $index-collection :=
      if (xmldb:collection-available($ridx:ridx-path))
      then ()
      else system:as-user("admin", $magic:password,
        let $setup := ridx:setup()
        let $indicator := xmldb:store($ridx:ridx-path, "created-by-test.xml", <created/>)
        return ()
        )
    return ()
    """)
      .go
  }

  override def afterAll()  {
    xq(
      """
        let $users := tcommon:teardown-test-users(1)
        let $index :=
          if (doc-available($ridx:ridx-path || "/created-by-test.xml"))
          then system:as-user("admin", $magic:password, xmldb:remove($ridx:ridx-path))
          else ()
        return ()
        """)
      .go

    super.afterAll()
  }

}

class TestRefindex extends BaseTestRefindex {

  override def beforeAll()  {
    super.beforeAll()

    setupResource("src/test/resources/modules/refindex/reference-target.xml", "reference-target", "original", 1, Some("en"))
    setupResource("src/test/resources/modules/refindex/reference-source.xml", "reference-source", "original", 1, Some("en"))
  }

  override def afterAll()  {
    teardownResource("reference-source", "original", 1)
    teardownResource("reference-target", "original", 1)

    super.afterAll()
  }
  
  describe("ridx:is-enabled") {
    it("returns false after the index is disabled") {
      xq(
        """let $disabled := ridx:disable()
                  return ridx:is-enabled()""")
        .user("admin")
        .assertFalse
        .assertXPath("""doc-available($ridx:ridx-path || "/" || $ridx:disable-flag)""", "disable flag is present")
        .go
    }

    it("returns true after the index is enabled") {
      xq(
        """let $disabled := ridx:enable()
                  return ridx:is-enabled()""")
        .user("admin")
        .assertTrue
        .assertXPath("""not(doc-available($ridx:ridx-path || "/" || $ridx:disable-flag))""", "disable flag is removed")
        .go
    }
  }
  
  describe("ridx:reindex") {
    it("indexes the source document") {
      xq(
        """ridx:reindex("/db/data/original/en", "reference-source.xml")"""
      )
        .user("xqtest1")
        .assertXPath("""doc-available("/db/refindex/original/en/reference-source.xml")""", "reference document created")
        .assertXPath("""count(doc("/db/refindex/original/en/reference-source.xml")//ridx:entry) > 1""", "reference document has some index entries")
        .assertXPath("""count(doc("/db/refindex/original/en/reference-source.xml")//ridx:broken)=2""", "reference document has 2 broken links")
        .go
    }

    it("indexes the target document") {
      xq("""ridx:reindex("/db/data/original/en", "reference-target.xml")""")
        .user("xqtest1")
        .assertXPath("""doc-available("/db/refindex/original/en/reference-target.xml")""", "target document exists in reference index")
        .assertXPath("""empty(doc("/db/refindex/original/en/reference-target.xml")/*/*)""", "target document in reference index is empty")
        .go
    }
  }
  
  describe("ridx:query#3($position, $include-ancestors=true())") {
    it("returns the link when position=1, where the query is in position 1") {
      xq("""ridx:query(
        doc("/db/data/original/en/reference-source.xml")//tei:link,
        doc("/db/data/original/en/reference-source.xml")/id("segA"), 
        1
      )""")
        .assertXPath("""$output/self::tei:link[@type="note"]""", "the link is returned")
        .go
    }

    it("returns the link when position=2, where the query is in position 2") {
      xq("""ridx:query(
        doc("/db/data/original/en/reference-source.xml")//tei:link,
        doc("/db/data/original/en/reference-target.xml")/id("note"), 
        2
      )""")
        .assertXPath("""$output/self::tei:link[@type="note"]""", "the link is returned")
        .go
    }
    
    it("returns empty for position=1, where the query is in position 2") {
      xq("""ridx:query(
        doc("/db/data/original/en/reference-source.xml")//tei:link,
        doc("/db/data/original/en/reference-target.xml")/id("note"),
        1
      )""")
        .assertEmpty
        .go
    }

    it("returns empty for position=2, where the query is in position 1") {
      xq("""ridx:query(
        doc("/db/data/original/en/reference-source.xml")//tei:link,
        doc("/db/data/original/en/reference-source.xml")/id("segA"), 
        2
      )""")
        .assertEmpty
        .go
    }
    
    it("returns a result for a query through an ancestor") {
      xq("""ridx:query(
        doc("/db/data/original/en/reference-source.xml")//tei:ptr,
        doc("/db/data/original/en/reference-source.xml")/id("child"),
        ()
      )""")
        .assertXPath("""count($output)=1""", "returns 1 result")
        .assertXPath("""$output/self::tei:ptr[@xml:id="ptr_to_ancestor"]""", "result is a ptr to the ancestor")
        .go
    }
  }

  describe("ridx:query#4 ($include-ancestors=false())") {
    it("returns results for a query for all references") {
      xq("""ridx:query(
          doc("/db/data/original/en/reference-source.xml")//j:textStream/tei:ptr,
          doc("/db/data/original/en/reference-source.xml")//j:textStream/tei:seg, 
          (), 
          false()
      )""")
        .assertXPath("""count($output)=3""", "there are 3 results")
        .assertXPath("""count($output/self::tei:ptr)=3""", "all results are tei:ptr")
        .go
    }

    it("returns results for a shorthand pointer reference") {
      xq("""ridx:query(
          doc("/db/data/original/en/reference-source.xml")//tei:ptr,
          doc("/db/data/original/en/reference-source.xml")/id("segA"), 
          (), false()
      )""")
        .assertXPath("""count($output)=1""", "there is 1 result")
        .assertXPath("""$output/self::tei:ptr[@xml:id="ptr_to_seg"]""", "one result is a tei:ptr")
        .go
    }

    it("returns a result where the query is the beginning of a range") {
      xq("""ridx:query(
          doc("/db/data/original/en/reference-source.xml")//tei:ptr,
          doc("/db/data/original/en/reference-source.xml")/id("segB"), 
          (), false()
      )""")
        .assertXPath("""count($output)=1""", "there is 1 result")
        .assertXPath("""$output/self::tei:ptr[@xml:id="ptr_to_range"]""", "one result is a tei:ptr")
        .go
    }

    it("returns a result where the query result is inside a range, any position, no ancestors") {
      xq("""ridx:query(
          doc("/db/data/original/en/reference-source.xml")//tei:ptr,
          doc("/db/data/original/en/reference-source.xml")/id("segBC"), 
          (), false()
      )""")
        .assertXPath("""count($output)=1""", "there is 1 result")
        .assertXPath("""$output/self::tei:ptr[@xml:id="ptr_to_range"]""", "one result is a tei:ptr")
        .go
    }

    it("returns a results where the query result in at the end of the range, any position, no ancestors") {
      xq("""ridx:query(
          doc("/db/data/original/en/reference-source.xml")//tei:ptr,
          doc("/db/data/original/en/reference-source.xml")/id("segC"), 
          (), false()
      )""")
        .assertXPath("""count($output)=1""", "there is 1 result")
        .assertXPath("""$output/self::tei:ptr[@xml:id="ptr_to_range"]""", "one result is a tei:ptr")
        .go
    }
    
    it("returns empty when querying for a child where only ancestors are targetted") {
      xq("""ridx:query(
          doc("/db/data/original/en/reference-source.xml")//tei:ptr,
          doc("/db/data/original/en/reference-source.xml")/id("child"), 
          (), false()
      )""")
        .assertEmpty
        .go
    }
    
    it("returns results when querying for an external target") {
      xq("""ridx:query(
          doc("/db/data/original/en/reference-source.xml")//tei:ptr,
          doc("/db/data/original/en/reference-target.xml")/id("seg1"), 
          (), false()
      )""")
        .assertXPath("""count($output)=1""", "there is 1 result")
        .assertXPath("""$output/self::tei:ptr[@xml:id="external"]""", "one result is a tei:ptr")
        .go
    }
    
    it("returns results when querying for an external target inside a range") {
      xq("""ridx:query(
          doc("/db/data/original/en/reference-source.xml")//tei:ptr,
          doc("/db/data/original/en/reference-target.xml")/id("seg3"), 
          (), false()
      )""")
        .assertXPath("""count($output)=1""", "there is 1 result")
        .assertXPath("""$output/self::tei:ptr[@xml:id="external_range"]""", "one result is a tei:ptr")
        .go
    }
    
    it("returns results when querying for an external target from a link") {
      xq("""ridx:query(
          doc("/db/data/original/en/reference-source.xml")//tei:link,
          doc("/db/data/original/en/reference-target.xml")/id("note"), 
          (), false()
      )""")
        .assertXPath("""count($output)=1""", "there is 1 result")
        .assertXPath("""$output/self::tei:link[@type="note"]""", "one result is a tei:link")
        .go
    }
    
    it("returns empty when querying for a reference through an ancestor") {
      xq("""ridx:query(
        doc("/db/data/original/en/reference-source.xml")//tei:ptr,
        doc("/db/data/original/en/reference-source.xml")/id("child"),
        (), false()
      )""")
        .assertEmpty
        .go
    }
  }

  describe("ridx:query-all#1 ($include-ancestors=true)") {
    it("returns results for querying a reference through an ancestor") {
      xq(
        """ridx:query-all(
        doc("/db/data/original/en/reference-source.xml")/id("child")
      )""")
        .assertXPath("""count($output)=1""", "returns 1 result")
        .assertXPath("""$output/self::tei:ptr[@xml:id="ptr_to_ancestor"]""", "result is a ptr to the ancestor")
        .go
    }
  }
  
  describe("ridx_query-all#2 ($position)") {
    it("returns results where position=1, where the query is in position 1") {
      xq("""ridx:query-all(
        doc("/db/data/original/en/reference-source.xml")/id("segA"), 
        1
      )""")
        .assertXPath("""$output/self::tei:link[@type="note"]""", "the link is returned")         
        .go
    }
    
    it("returns results for position=2, where the query is in position 2") {
      xq("""ridx:query-all(
        doc("/db/data/original/en/reference-target.xml")/id("note"), 
        2
      )""")
        .assertXPath("""$output/self::tei:link[@type="note"]""", "the link is returned")
        .go
    }

    it("returns empty for position=1, where the query is in position 2") {
      xq("""ridx:query-all(
        doc("/db/data/original/en/reference-target.xml")/id("note"), 
        1
      )""")
        .assertEmpty
        .go
    }

    it("returns empty for position=2, where the query is in position 1") {
      xq("""ridx:query-all(
        doc("/db/data/original/en/reference-source.xml")/id("segA"), 
        2
      )""")
        .assertEmpty
        .go
    }
  }

  describe("ridx:query-all#3 ($include-ancestors=false())") {
    it("returns results for a query for an reference, any position, no ancestors") {
      xq("""ridx:query-all(
          doc("/db/data/original/en/reference-source.xml")/id("segA"), 
          (), false()
      )""")
        .assertXPath("""count($output)=2""", "there are 2 results")
        .assertXPath("""$output/self::tei:ptr[@xml:id="ptr_to_seg"]""", "one result is a tei:ptr")
        .assertXPath("""$output/self::tei:link[@type="note"]""", "one result is is a link")
        .go
    }

    it("returns results for a query where the results include the beginning of a range, any position, no ancestors") {
      xq("""ridx:query-all(
          doc("/db/data/original/en/reference-source.xml")/id("segB"), 
          (), false()
      )""")
        .assertXPath("""count($output)=1""", "there is 1 result")
        .assertXPath("""$output/self::tei:ptr[@xml:id="ptr_to_range"]""", "one result is a tei:ptr")
        .go
    }

    it("returns results for a query where the result is inside a range, any position, no ancestors") {
      xq("""ridx:query-all(
          doc("/db/data/original/en/reference-source.xml")/id("segBC"), 
          (), false()
      )""")
        .assertXPath("""count($output)=1""", "there is 1 result")
        .assertXPath("""$output/self::tei:ptr[@xml:id="ptr_to_range"]""", "one result is a tei:ptr")
        .go
    }

    it("returns results for a query where the results are at the end of a range, any position, no ancestors") {
      xq("""ridx:query-all(
          doc("/db/data/original/en/reference-source.xml")/id("segC"), 
          (), false()
      )""")
        .assertXPath("""count($output)=1""", "there is 1 result")
        .assertXPath("""$output/self::tei:ptr[@xml:id="ptr_to_range"]""", "one result is a tei:ptr")
        .go
    }

    it("returns empty for the query of a child where only the ancestors are targetted") {
      xq("""ridx:query-all(
          doc("/db/data/original/en/reference-source.xml")/id("child"), 
          (), false()
      )""")
        .assertEmpty
        .go
    }
    
    it("returns results for the query of an external target") {
      xq("""ridx:query-all(
          doc("/db/data/original/en/reference-target.xml")/id("seg1"), 
          (), false()
        )""")
        .assertXPath("""count($output)=1""", "there is 1 result")
        .assertXPath("""$output/self::tei:ptr[@xml:id="external"]""", "one result is a tei:ptr")
        .go
    }
    
    it("returns results for the query of external target inside a range") {
      xq("""ridx:query-all(
          doc("/db/data/original/en/reference-target.xml")/id("seg3"), 
          (), false()
      )""")
        .assertXPath("""count($output)=1""", "there is 1 result")
        .assertXPath("""$output/self::tei:ptr[@xml:id="external_range"]""", "one result is a tei:ptr")
        .go
    }
    
    it("returns results for the query of an external target from a link") {
      xq("""ridx:query-all(
          doc("/db/data/original/en/reference-target.xml")/id("note"), 
          (), false()
      )""")
        .assertXPath("""count($output)=1""", "there is 1 result")
        .assertXPath("""$output/self::tei:link[@type="note"]""", "one result is a tei:link")
        .go
    }
  }
  
  describe("ridx:query-document#1 ($accept-same=false())") {
    it("returns results for a document with only internal references") {
      xq("""ridx:query-document(
        doc("/db/data/original/en/reference-source.xml")
      )""")
        .assertXPath("""count($output)=5""", "returns 5 results")
        .assertXPath("""count($output/self::tei:link)=1""", "one result is a link")
        .assertXPath("""count($output/self::tei:ptr)=4""", "the rest are ptr")
        .go
    }
    
    it("returns results for a document with external references") {
      xq("""ridx:query-document(doc("/db/data/original/en/reference-target.xml"))""")
        .assertXPath("""count($output)=3""", "returns 3 references")
        .assertXPath("""$output/self::tei:link[@type="note"]""", "1 reference is a link")
        .assertXPath("""$output/self::tei:ptr[@xml:id="external"]""", "1 reference comes from a #fragment type pointer")
        .assertXPath("""$output/self::tei:ptr[@xml:id="external_range"]""", "1 reference comes from a range pointer")
        .go
    }
  }
  
  describe("ridx:query-document#2 ($accept-same=true())") {
    it("returns results for a document with internal references") {
      xq("""ridx:query-document(
        doc("/db/data/original/en/reference-source.xml"),
        true()
      )""")
        .assertXPath("""count($output)=5""", "returns 5 results")
        .assertXPath("""count($output/self::tei:link)=1""", "one result is a link")
        .assertXPath("""count($output/self::tei:ptr)=4""", "the rest are ptr")
        .go
    }

    it("returns empty for a document with no internal references") {
      xq("""ridx:query-document(
        doc("/db/data/original/en/reference-target.xml"),
        true()
      )""")
        .assertEmpty
        .go
    }
  }
}

class TestRidxReindexCollection extends BaseTestRefindex {
  override def beforeEach(): Unit = {
    super.beforeEach()

    setupResource("src/test/resources/modules/refindex/reference-target.xml", "reference-target", "original", 1, Some("en"))
    setupResource("src/test/resources/modules/refindex/reference-source.xml", "reference-source", "original", 1, Some("en"))
    setupResource("src/test/resources/modules/refindex/reference-target-too.xml", "reference-target-too", "original", 1, Some("en"))
    setupResource("src/test/resources/modules/refindex/reference-source-too.xml", "reference-source-too", "original", 1, Some("en"))

    // remove 2 files without removing their index entries
    xq(
      """
        let $r1 := xmldb:remove("/db/data/original/en", "reference-source.xml")
        let $r2 := xmldb:remove("/db/data/original/en", "reference-target.xml")
        return ()""")
      .user("admin")
      .go
  }

  override def afterEach(): Unit = {
    teardownResource("reference-source", "original", 1)
    teardownResource("reference-target", "original", 1)
    teardownResource("reference-source-too", "original", 1)
    teardownResource("reference-target-too", "original", 1)

    super.afterEach()
  }

  describe("ridx:reindex#2") {
    // setupResource calls reindex already...


    it("removes the index entries for the removed files") {
      xq("""ridx:reindex("/db/data/original/en", ())""")
        .user("admin")
        .assertXPath("""mirror:collection-available($ridx:ridx-path, "/db/data/original/en")""")
        .assertXPath("""not(mirror:doc-available($ridx:ridx-path, "/db/data/original/en/reference-source.xml"))""")
        .assertXPath("""not(mirror:doc-available($ridx:ridx-path, "/db/data/original/en/reference-target.xml"))""")
        .assertXPath("""mirror:doc-available($ridx:ridx-path, "/db/data/original/en/reference-source-too.xml")""")
        .assertXPath("""mirror:doc-available($ridx:ridx-path, "/db/data/original/en/reference-target-too.xml")""")
        .go
    }
  }
}