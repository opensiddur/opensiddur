package org.opensiddur.modules

import org.opensiddur.DbTest

class TestDocindex extends DbTest {
  /** imports, namespaces and variables */
  override val prolog: String =
    """xquery version '3.1';

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";
import module namespace deepequality="http://jewishliturgy.org/modules/deepequality"
  at "xmldb:exist:/db/apps/opensiddur-server/modules/deepequality.xqm";

import module namespace didx="http://jewishliturgy.org/modules/docindex"
  at "xmldb:exist:/db/apps/opensiddur-server/modules/didx.xqm";

import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:/db/apps/opensiddur-server/magic/magic.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
    """

  override def beforeAll: Unit = {
    super.beforeAll()

    setupUsers(1)
    setupCollection("/db/data/original", "test", Some("xqtest1"), Some("xqtest1"), Some("rwxrwxrwx"))
  }

  override def afterAll(): Unit = {
    teardownCollection("/db/data/original/test")
    teardownUsers(1)
    super.afterAll()
  }

  override def beforeEach(): Unit = {
    super.beforeEach()

    setupResource("src/test/resources/modules/docindex/test_docindex.xml", "test_docindex", "original", 1, Some("en"))
    setupResource("src/test/resources/modules/docindex/test_docindex.xml", "test_docindex_2", "original", 1, Some("test"))

  }

  override def afterEach(): Unit = {
    teardownResource("test_docindex_2", "original", 1)
    teardownResource("test_docindex", "original", 1)
    super.afterEach()
  }

  describe("didx:reindex") {
    it("indexed the document (in tcommon:setup-resource)") {
      xq("""xmldb:collection-available($didx:didx-path)""")
        .assertTrue
        .go

      xq("""exists(doc($didx:didx-path || "/" || $didx:didx-resource))""")
        .assertTrue
        .go

      xq(
        """doc($didx:didx-path || "/" || $didx:didx-resource)//
          didx:entry[@db-path="/db/data/original/en/test_docindex.xml"]""")
        .assertXPath("exists($output)", "The document was not indexed")
        .assertXPath("count($output) = 1", "The document was not indexed exactly once")
        .assertXPath("$output/@collection='/db/data/original/en'", "the collection was recorded incorrectly")
        .assertXPath("$output/@resource='test_docindex'", "the resource was recorded incorrectly")
        .assertXPath("$output/@data-type='original'", "the data type was recorded incorrectly")
        .assertXPath("$output/@document-name='test_docindex.xml'", "The document name was recorded incorrectly")
        .go
    }

    it("does not add an additional entry when a document is reindexed twice") {
      xq(
        """let $reindex := didx:reindex("/db/data/original", "test_docindex.xqm")
          return doc($didx:didx-path || "/" || $didx:didx-resource)//
          didx:entry[@db-path="/db/data/original/en/test_docindex.xml"]""")
        .assertXPath("count($output) = 1", "The document was not indexed exactly once")
        .go
    }
  }

  describe("didx:remove") {
    it("deletes an existing entry from the index") {
      xq("""didx:remove("/db/data/original/en", "test_docindex.xml")""")
        .assertXPath("empty(doc($didx:didx-path || \"/\" || $didx:didx-resource)//didx:entry[@db-path=\"/db/data/original/en/test_docindex.xml\"])",
        "The entry was not removed")
        .assertXPath("""exists(doc($didx:didx-path || "/" || $didx:didx-resource)//didx:entry[@collection="/db/data/original/test"]) """)
        .go
    }

    it("deletes an entire collection from the index with remove#2") {
      xq("""didx:remove("/db/data/original/test", ())""")
        .assertXPath("""empty(doc($didx:didx-path || "/" || $didx:didx-resource)//didx:entry[@collection="/db/data/original/test"]) """)
        .go
    }

    it("deletes an entire collection from the index with remove#1") {
      xq("""didx:remove("/db/data/original/test")""")
        .assertXPath("""empty(doc($didx:didx-path || "/" || $didx:didx-resource)//didx:entry[@collection="/db/data/original/test"]) """)
        .go
    }

    it("does nothing when a document does not exist") {
      xq("""didx:remove("/db/data/original", "test_docindex_does_not_exist.xml")""")
        .go
    }
  }

  describe("didx:query-path") {
    it("returns a result for an existing path") {
      xq("""didx:query-path("original", "test_docindex")""")
        .assertXPath("count($output) = 1", "The query did not return exactly 1 result")
        .assertEquals("/db/data/original/en/test_docindex.xml")
        .go
    }

    it("returns empty for a nonexisting path") {
      xq("""didx:query-path("original", "nonexistent_docindex_entry")""")
        .assertEmpty
        .go
    }
  }

  describe("didx:query-by-path") {
    it("returns a result for an existing path") {
      xq("""didx:query-by-path("/db/data/original/en/test_docindex.xml")""")
        .assertXPath("exists($output)", "The document was not indexed")
        .assertXPath("count($output) = 1", "The document was not indexed exactly once")
        .assertXPath("$output/@resource='test_docindex'", "the resource was recorded incorrectly")
        .assertXPath("$output/@data-type='original'", "the data type was recorded incorrectly")
        .assertXPath("$output/@document-name='test_docindex.xml'", "The document name was recorded incorrectly")
        .go
    }

    it("returns no result for a nonexisting path") {
      xq("""didx:query-by-path("/db/data/original/en/test_docindex_does_not_exist.xml")""")
        .assertEmpty
        .go
    }
  }
}
