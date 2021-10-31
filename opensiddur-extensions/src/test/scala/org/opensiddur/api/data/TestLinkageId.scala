package org.opensiddur.api.data

import org.opensiddur.DbTest

class TestLinkageId extends DbTest {
  /** imports, namespaces and variables */
  override val prolog: String =
    """xquery version '3.1';

  import module namespace lnkid = 'http://jewishliturgy.org/api/data/linkageid'
    at "xmldb:exist:/db/apps/opensiddur-server/api/data/linkageid.xqm";
  import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
    at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

  declare namespace tei="http://www.tei-c.org/ns/1.0";
  declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
  declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
  declare namespace html="http://www.w3.org/1999/xhtml";
  declare namespace http="http://expath.org/ns/http-client";
  declare namespace rest="http://exquery.org/ns/restxq";
    """

  override def beforeAll: Unit = {
    super.beforeAll

    setupUsers(1)

    setupResource("src/test/resources/api/data/linkageid/original-a.xml", "original-a", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/linkageid/original-b.xml", "original-b", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/linkageid/original-c.xml", "original-c", "original", 1, Some("en"))

    setupResource("src/test/resources/api/data/linkageid/linkage-a-b.xml", "linkage-a-b", "linkage", 1, Some("none"))
    setupResource("src/test/resources/api/data/linkageid/linkage-a-c.xml", "linkage-a-c", "linkage", 1, Some("none"))
    setupResource("src/test/resources/api/data/linkageid/linkage-b-c.xml", "linkage-b-c", "linkage", 1, Some("none"))
  }

  override def afterAll(): Unit = {
    teardownResource("linkage-b-c", "linkage", 1)
    teardownResource("linkage-a-c", "linkage", 1)
    teardownResource("linkage-a-b", "linkage", 1)

    teardownResource("original-c", "original", 1)
    teardownResource("original-b", "original", 1)
    teardownResource("original-a", "original", 1)
    teardownUsers(1)

    super.afterAll()
  }

  describe("lnkid:list") {
    it("returns a list that includes the linkage ids linkage documents") {
      xq("""lnkid:list("", 1, 100)""")
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"]) >= 2""", "returns at least 2 results")
        .assertXPath("""$output//html:li[@class="result"]/html:a/string() = "identifier1" """, "one of the results is identifier1")
        .assertXPath("""ends-with($output//html:li[@class="result"]/html:a/@href/string(), "/api/data/linkageid/identifier1") """, "the url of identifier1 is referenced")
        .assertXPath("""$output//html:li[@class="result"]/html:a/string() = "identifier2" """, "one of the results is identifier2")
        .assertSearchResults
        .go
    }

    it("returns a limited list when given a search query") {
      xq("""lnkid:list("ifier2", 1, 100)""") // identifier2
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"]) = 1""", "returns 1 result")
        .assertSearchResults
        .go
    }

    it("returns a limited list when given start and max results") {
      xq("""lnkid:list("", 1, 1)""") // identifier2
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"]) = 1""", "returns 1 result")
        .assertSearchResults
        .go
    }
  }

  describe("lnkid:get") {
    it("returns Not found if the linkage id does not exist") {
      xq("""lnkid:get("DOESNOTEXIST")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("returns a list of linkage, left and right documents when called with an existing id") {
      xq("""lnkid:get("identifier1")""")
        .user("xqtest1")
        .assertSerializesAs("xhtml")
        .assertXPath("""count($output//html:li[@class="result"]) = 2""", "returns 2 linkage files")
        .assertXPath("""$output//html:li[@class="result"]/html:a[contains(@class, "linkage")]/@href = "/api/data/linkage/linkage-a-b" """, "linkage file referenced")
        .assertXPath("""$output//html:li[@class="result"]/html:a[contains(@class, "left")]/@href = "/api/data/original/original-a" """, "original file referenced")
        .assertXPath("""$output//html:li[@class="result"]/html:a[contains(@class, "right")]/@href = "/api/data/original/original-b" """, "original file referenced")
        .go
    }
  }
}
