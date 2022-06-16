package org.opensiddur.modules

import org.opensiddur.DbTest

class BaseTestUpgrade140 extends DbTest {
  /** imports, namespaces and variables */
  override val prolog: String =
    """xquery version '3.1';

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";
import module namespace upg14 = "http://jewishliturgy.org/modules/upgrade140"
  at "xmldb:exist:/db/apps/opensiddur-server/modules/upgrade140.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
    """

  override def beforeAll: Unit = {
    super.beforeAll()
    setupUsers(1)
  }

  override def afterAll(): Unit = {
    teardownUsers(1)
    super.afterAll()
  }


}

class TestUpgrade140 extends BaseTestUpgrade140 {

  override def beforeAll: Unit = {
    super.beforeAll()
    setupResource("src/test/resources/modules/upgrade122/test_file.xml", "test_file", "original", 1)

    setupCollection("/db/data", "needs_upgrade", Some("xqtest1"), Some("xqtest1"), Some("rwxrwxrwx"))
    store("src/test/resources/modules/upgrade140/needs_upgrade.xml",
      "/db/data/needs_upgrade", "needs_upgrade.xml", as="xqtest1")
    setupCollection("/db/data", "no_needs_upgrade", Some("xqtest1"), Some("xqtest1"), Some("rwxrwxrwx"))
    store("src/test/resources/modules/upgrade140/no_needs_upgrade.xml",
      "/db/data/no_needs_upgrade", "no_needs_upgrade.xml", as="xqtest1")
  }

  override def afterAll(): Unit = {
    teardownCollection("/db/data/no_needs_upgrade")
    teardownCollection("/db/data/needs_upgrade")

    teardownResource("test_file", "original", 1)
    super.afterAll()
  }

  describe("upg14:is-canonical") {
    it("says a start of a verse segment is canonical") {
      xq("""upg14:is-canonical(element tei:anchor { attribute xml:id { "v1_seg1" }})""")
        .assertTrue
        .go
    }

    it("says an end of a verse segment is canonical") {
      xq("""upg14:is-canonical(element tei:anchor { attribute xml:id { "v19_seg12_end" }})""")
        .assertTrue
        .go
    }

    it("says a non-verse segment is not canonical") {
      xq("""upg14:is-canonical(element tei:anchor { attribute xml:id { "notcanonical21" }})""")
        .assertFalse
        .go
    }
  }

  describe("upg14:needs-upgrade") {
    it("returns true for a collection that has an insufficient number of externals/canonicals") {
      xq("""upg14:needs-upgrade("/db/data/needs_upgrade")""")
        .assertTrue
        .go
    }

    it("returns false for a collection that has a minimal sufficient number of externals/canonicals") {
      xq("""upg14:needs-upgrade("/db/data/no_needs_upgrade")""")
        .assertFalse
        .go
    }
  }
}

class TestGetUpgradeMap extends BaseTestUpgrade140 {
  override def beforeAll: Unit = {
    super.beforeAll

    // set up a test root collection
    setupCollection("/db/data", "test_upgrade_map")
    // set up one file with anchors (internal, external, and canonical)
    // set up a file that references the anchors
    // reindex the reference index
  }

  override def afterAll(): Unit = {
    // clear the reference index
    // remove test root collection
    teardownCollection("/db/data/test_upgrade_map")
    super.afterAll()
  }
}