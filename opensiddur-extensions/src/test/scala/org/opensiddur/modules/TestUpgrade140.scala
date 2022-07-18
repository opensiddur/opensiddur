package org.opensiddur.modules

import org.opensiddur.DbTest

class BaseTestUpgrade140 extends DbTest {
  /** imports, namespaces and variables */
  override val prolog: String =
    """xquery version '3.1';

import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:/db/apps/opensiddur-server/magic/magic.xqm";
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

class TestUpgradeChangesMap extends BaseTestUpgrade140 {
  override def beforeEach(): Unit = {
    super.beforeEach()

    // set up a test root collection
    setupCollection("/db/data/original", "test_upgrade_map", Option("xqtest1"), Option("xqtest1"))
    // set up one file with anchors (internal, external, and canonical)
    setupResource("src/test/resources/modules/upgrade140/anchors.xml", "anchors", "original", 1,
      Option("test_upgrade_map"))
    // set up a file that references the anchors
    setupResource("src/test/resources/modules/upgrade140/references.xml", "references", "original", 1,
      Option("test_upgrade_map"))
    // reindex the reference index
  }

  override def afterEach(): Unit = {
    // clear the reference index
    teardownResource("references", "original", 1)
    teardownResource("anchors", "original", 1)
    // remove test root collection
    teardownCollection("/db/data/original/test_upgrade_map")
    super.afterEach()
  }

  describe("upg14:get-upgrade-changes-map") {
    it("returns a map of anchors that need new types") {
      xq(
        """upg14:get-upgrade-changes-map("/db/data/original/test_upgrade_map")""")
        .user("xqtest1")
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_reference")("type") = "internal" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_reference")("id") = "with_internal_reference" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_reference")("old_id") = "with_internal_reference" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_reference")("reference_doc") = "/db/data/original/test_upgrade_map/anchors.xml" """)
        .assertXPath(
          """util:node-by-id(doc("/db/data/original/test_upgrade_map/anchors.xml"),
            $output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_reference")("reference_id"))/@xml:id = "ptr_to_internal_reference" """)

        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_start")("type") = "internal" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_start")("id") = "with_internal_start" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_start")("old_id") = "with_internal_start" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_start")("reference_doc") = "/db/data/original/test_upgrade_map/anchors.xml" """)
        .assertXPath(
          """util:node-by-id(doc("/db/data/original/test_upgrade_map/anchors.xml"),
            $output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_start")("reference_id"))/@target = "#range(with_internal_start,with_internal_end)" """)

        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_end")("type") = "internal" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_end")("id") = "with_internal_end" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_end")("old_id") = "with_internal_end" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_end")("reference_doc") = "/db/data/original/test_upgrade_map/anchors.xml" """)
        .assertXPath(
          """util:node-by-id(doc("/db/data/original/test_upgrade_map/anchors.xml"),
            $output("/db/data/original/test_upgrade_map/anchors.xml#with_internal_end")("reference_id"))/@target = "#range(with_internal_start,with_internal_end)" """)

        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_external_reference")("type") = "external" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_external_reference")("id") = "with_external_reference" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_external_reference")("old_id") = "with_external_reference" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_external_reference")("reference_doc") = "/db/data/original/test_upgrade_map/references.xml" """)
        .assertXPath(
          """util:node-by-id(doc("/db/data/original/test_upgrade_map/references.xml"),
            $output("/db/data/original/test_upgrade_map/anchors.xml#with_external_reference")("reference_id"))/@target = "/data/original/anchors#with_external_reference" """)

        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_external_start")("type") = "external" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_external_start")("id") = "with_external_start" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_external_start")("old_id") = "with_external_start" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_external_start")("reference_doc") = "/db/data/original/test_upgrade_map/references.xml" """)
        .assertXPath(
          """util:node-by-id(doc("/db/data/original/test_upgrade_map/references.xml"),
            $output("/db/data/original/test_upgrade_map/anchors.xml#with_external_start")("reference_id"))/@target = "/data/original/anchors#range(with_external_start,with_external_end)" """)

        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_external_end")("type") = "external" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_external_end")("id") = "with_external_end" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_external_end")("old_id") = "with_external_end" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#with_external_end")("reference_doc") = "/db/data/original/test_upgrade_map/references.xml" """)
        .assertXPath(
          """util:node-by-id(doc("/db/data/original/test_upgrade_map/references.xml"),
            $output("/db/data/original/test_upgrade_map/anchors.xml#with_external_end")("reference_id"))/@target = "/data/original/anchors#range(with_external_start,with_external_end)" """)

        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg1")("type") = "canonical" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg1")("id") = "v10_seg1" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg1")("old_id") = "" """)
        .assertXPath("""empty($output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg1")("reference_doc")) """)
        .assertXPath(
          """empty($output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg1")("reference_id")) """)

        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg1_end")("type") = "canonical" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg1_end")("id") = "v10_seg1_end" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg1_end")("old_id") = "" """)
        .assertXPath("""empty($output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg1_end")("reference_doc")) """)
        .assertXPath(
          """empty($output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg1_end")("reference_id")) """)

        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg2")("type") = "canonical" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg2")("id") = "v10_seg2" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg2")("old_id") = "" """)
        .assertXPath("""empty($output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg1_end")("reference_doc")) """)
        .assertXPath(
          """empty($output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg1_end")("reference_id"))""")


        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg2_end")("type") = "canonical" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg2_end")("id") = "v10_seg2_end" """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg2_end")("old_id") = "" """)
        .assertXPath("""empty($output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg2_end")("reference_doc")) """)
        .assertXPath(
          """empty($output("/db/data/original/test_upgrade_map/anchors.xml#v10_seg2_end")("reference_id"))""")

        .assertXPath("""count($output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_start")) = 2 """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_start")[1]("type") = ("internal", "external") """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_start")[1]("id") = ("multiple_reference_start_1", "multiple_reference_start_2") """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_start")[1]("old_id") = "multiple_reference_start" """)
        .assertXPath(
          """$output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_start")[1]("reference_doc") = (
              "/db/data/original/test_upgrade_map/anchors.xml",
              "/db/data/original/test_upgrade_map/references.xml"
            ) """)

        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_start")[2]("type") = ("internal", "external") """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_start")[2]("id") = ("multiple_reference_start_1", "multiple_reference_start_2") """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_start")[2]("old_id") = "multiple_reference_start" """)
        .assertXPath(
          """$output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_start")[2]("reference_doc") = (
              "/db/data/original/test_upgrade_map/anchors.xml",
              "/db/data/original/test_upgrade_map/references.xml"
            ) """)

        .assertXPath("""count($output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_end")) = 2 """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_end")[1]("type") = ("internal", "external") """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_end")[1]("id") = ("multiple_reference_end_1", "multiple_reference_end_2") """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_end")[1]("old_id") = "multiple_reference_end" """)

        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_end")[2]("type") = ("internal", "external") """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_end")[2]("id") =  ("multiple_reference_end_1", "multiple_reference_end_2") """)
        .assertXPath("""$output("/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_end")[2]("old_id") = "multiple_reference_end" """)
        .go
    }
  }

  describe("upg14:do-upgrade-changes") {
    it("does nothing when provided with no changes") {
      xq("""upg14:do-upgrade-changes(map {})""")
        .user("xqtest1")
        .assertXPathEquals(""" doc("/db/data/original/test_upgrade_map/anchors.xml")/* """,
          "anchors file has not changed",
          readXmlFile("src/test/resources/modules/upgrade140/anchors.xml")
        )
        .go
    }

    it("updates the type of a canonical anchor") {
      xq(
        """upg14:do-upgrade-changes(map {
            "/db/data/original/test_upgrade_map/anchors.xml#v10_seg1" : map {
              "type": "canonical",
              "id": "v10_seg1"
            }
          })""")
        .user("xqtest1")
        .assertXPath("""doc("/db/data/original/test_upgrade_map/anchors.xml")//tei:anchor[@xml:id="v10_seg1"]/@type="canonical" """)
        .go
    }

    it("updates the type of an anchor where the new and old id are the same") {
      xq(
        """upg14:do-upgrade-changes(map {
            "/db/data/original/test_upgrade_map/anchors.xml#with_internal_reference" : map {
              "type": "internal",
              "id": "with_internal_reference",
              "old_id" : "with_internal_reference"
            }
          })""")
        .user("xqtest1")
        .assertXPath("""doc("/db/data/original/test_upgrade_map/anchors.xml")//tei:anchor[@xml:id="with_internal_reference"]/@type="internal" """)
        .go
    }

    it("creates a new anchor and updates the references to it if the new and old ids are different") {
      xq(
        """
           let $anchors-file := doc("/db/data/original/test_upgrade_map/anchors.xml")
           let $reference-file := doc("/db/data/original/test_upgrade_map/references.xml")
           return upg14:do-upgrade-changes(map {
            "/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_start" : (
            map {
              "type": "internal",
              "id": "multiple_reference_start_0",
              "old_id" : "multiple_reference_start",
              "reference_doc": document-uri($anchors-file),
              "reference_id": util:node-id($anchors-file//tei:ptr[@xml:id="multi_ref"])
            } ,
            map {
              "type": "external",
              "id": "multiple_reference_start_1",
              "old_id" : "multiple_reference_start",
              "reference_doc": document-uri($reference-file),
              "reference_id": util:node-id($reference-file//tei:ptr[@xml:id="multi_ref"])
            }
            )
          })""")
        .user("xqtest1")
        .assertXPath("""doc("/db/data/original/test_upgrade_map/anchors.xml")//tei:anchor[@xml:id="multiple_reference_start_0"]/@type="internal" """)
        .assertXPath("""doc("/db/data/original/test_upgrade_map/anchors.xml")//tei:ptr[@xml:id="multi_ref"]/@target="#range(multiple_reference_start_0,multiple_reference_end)" """)
        .assertXPath("""doc("/db/data/original/test_upgrade_map/anchors.xml")//tei:anchor[@xml:id="multiple_reference_start_1"]/@type="external" """)
        .assertXPath("""doc("/db/data/original/test_upgrade_map/references.xml")//tei:ptr[@xml:id="multi_ref"]/@target="/data/original/anchors#range(multiple_reference_start_1,multiple_reference_end)" """)
        .assertXPath("""empty(doc("/db/data/original/test_upgrade_map/anchors.xml")//tei:anchor[@xml:id="multiple_reference_start"])""")
        .go
    }

    it("can make changes to the beginnings and ends of the same range reference") {
      xq(
        """
           let $anchors-file := doc("/db/data/original/test_upgrade_map/anchors.xml")
           let $reference-file := doc("/db/data/original/test_upgrade_map/references.xml")
           return upg14:do-upgrade-changes(map {
            "/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_start" : (
            map {
              "type": "internal",
              "id": "multiple_reference_start_0",
              "old_id" : "multiple_reference_start",
              "reference_doc": document-uri($anchors-file),
              "reference_id": util:node-id($anchors-file//tei:ptr[@xml:id="multi_ref"])
            },
            map {
              "type": "external",
              "id": "multiple_reference_start_1",
              "old_id" : "multiple_reference_start",
              "reference_doc": document-uri($reference-file),
              "reference_id": util:node-id($reference-file//tei:ptr[@xml:id="multi_ref"])
            }
            ),
            "/db/data/original/test_upgrade_map/anchors.xml#multiple_reference_end" : (
            map {
              "type": "internal",
              "id": "multiple_reference_end_0",
              "old_id" : "multiple_reference_end",
              "reference_doc": document-uri($anchors-file),
              "reference_id": util:node-id($anchors-file//tei:ptr[@xml:id="multi_ref"])
            },
            map {
              "type": "external",
              "id": "multiple_reference_end_1",
              "old_id" : "multiple_reference_end",
              "reference_doc": document-uri($reference-file),
              "reference_id": util:node-id($reference-file//tei:ptr[@xml:id="multi_ref"])
            }
            )
          })""")
        .user("xqtest1")
        .assertXPath("""doc("/db/data/original/test_upgrade_map/anchors.xml")//tei:anchor[@xml:id="multiple_reference_start_0"]/@type="internal" """)
        .assertXPath("""doc("/db/data/original/test_upgrade_map/anchors.xml")//tei:anchor[@xml:id="multiple_reference_start_1"]/@type="external" """)
        .assertXPath("""doc("/db/data/original/test_upgrade_map/anchors.xml")//tei:ptr[@xml:id="multi_ref"]/@target="#range(multiple_reference_start_0,multiple_reference_end_0)" """)
        .assertXPath("""doc("/db/data/original/test_upgrade_map/anchors.xml")//tei:anchor[@xml:id="multiple_reference_end_0"]/@type="internal" """)
        .assertXPath("""doc("/db/data/original/test_upgrade_map/anchors.xml")//tei:anchor[@xml:id="multiple_reference_end_1"]/@type="external" """)
        .assertXPath("""doc("/db/data/original/test_upgrade_map/references.xml")//tei:ptr[@xml:id="multi_ref"]/@target="/data/original/anchors#range(multiple_reference_start_1,multiple_reference_end_1)" """)
        .assertXPath("""empty(doc("/db/data/original/test_upgrade_map/anchors.xml")//tei:anchor[@xml:id="multiple_reference_start"])""")
        .assertXPath("""empty(doc("/db/data/original/test_upgrade_map/anchors.xml")//tei:anchor[@xml:id="multiple_reference_end"])""")
        .go
    }
  }
}

