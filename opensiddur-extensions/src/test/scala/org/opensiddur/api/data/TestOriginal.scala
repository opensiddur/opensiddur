package org.opensiddur.api.data

import org.opensiddur.DbTest

trait OriginalDataTestFixtures extends DbTest {
  override val prolog =
    """xquery version '3.1';

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

import module namespace orig="http://jewishliturgy.org/api/data/original"
  at "xmldb:exist:///db/apps/opensiddur-server/api/data/original.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "xmldb:exist:///db/apps/opensiddur-server/modules/format.xqm";
import module namespace crest="http://jewishliturgy.org/modules/common-rest"
  at "xmldb:exist:///db/apps/opensiddur-server/api/modules/common-rest.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "xmldb:exist:///db/apps/opensiddur-server/api/modules/refindex.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:///db/apps/opensiddur-server/magic/magic.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace a="http://jewishliturgy.org/ns/access/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";
declare namespace http="http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
"""

  def setup() = {
    setupUsers(2)

    setupResource("src/test/resources/api/data/original/existing.xml",
      "existing", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/api/data/original/existing.xml",
      "no_access", "original", 2, Some("en"),
      group=Some("everyone"),permissions=Some("rw-------"))
    setupResource("src/test/resources/api/data/original/existing.xml",
      "no_write_access", "original", 2, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/query_result.xml",
      "query_result", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/api/data/original/has_transclude.xml",
      "has_transclude", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/api/data/original/transcluded.xml",
      "transcluded", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/api/data/original/external_reference.xml",
      "external_reference", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/with_revisiondesc_and_change.xml",
      "with_revisiondesc_and_change", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/with_revisiondesc_and_changelog.xml",
      "with_revisiondesc_and_changelog", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/with_no_revisiondesc.xml",
      "with_no_revisiondesc", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/with_empty_revisiondesc.xml",
      "with_empty_revisiondesc", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/test_doc_1.xml",
      "test_doc_1", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/test_doc_2.xml",
      "test_doc_2", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/link_doc_1.xml",
      "link_doc_1", "linkage", 1, None,
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/link_doc_2.xml",
      "link_doc_2", "linkage", 1, None,
      group=Some("everyone"),permissions=Some("rw-r--r--"))
  }

  def tearDown(): Unit = {
    teardownResource("link_doc_2", "linkage", 1)
    teardownResource("link_doc_1", "linkage", 1)
    teardownResource("test_doc_2", "original", 1)
    teardownResource("test_doc_1", "original", 1)
    teardownResource("with_no_revisiondesc", "original", 1)
    teardownResource("with_empty_revisiondesc", "original", 1)
    teardownResource("with_revisiondesc_and_changelog", "original", 1)
    teardownResource("with_revisiondesc_and_change", "original", 1)
    teardownResource("test_invalid_external_reference", "original", 1)
    teardownResource("test_valid_external_reference", "original", 1)
    teardownResource("valid", "original", 1)
    teardownResource("existing", "original", 1)
    teardownResource("no_access", "original", 2)
    teardownResource("no_write_access", "original", 2)
    teardownResource("query_result", "original", 1)
    teardownResource("has_transclude", "original", 1)
    teardownResource("transcluded", "original", 1)
    teardownResource("external_reference", "original", 1)

    teardownUsers(2)
  }

}

class TestOriginal extends OriginalDataTestFixtures {

  override def beforeAll = {
    super.beforeAll()
    setup()
  }

  override def beforeEach() = {
    super.beforeEach()
  }

  override def afterAll = {
    tearDown()
    super.afterAll()
  }

  override def afterEach(): Unit = {
    super.afterEach()
  }

  describe("orig:get") {
    it("returns a successful http call for an existing document when authenticated") {
      xq("orig:get('existing')")
        .user("xqtest1")
        .assertXPath("""exists($output/tei:TEI)""", "Returns a TEI resource")
        .go
    }

    it("returns a successful http call for an existing document when unauthenticated") {
      xq("orig:get('existing')")
        .assertXPath("""exists($output/tei:TEI)""", "Returns a TEI resource")
        .go
    }

    it("returns not found for a nonexisting resource") {
      xq("""orig:get("does_not_exist")""")
        .assertHttpNotFound
        .go
    }

    it("returns not found where there is no read access when authenticated") {
      xq("""orig:get("no_access")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("returns not found where there is no read access when unauthenticated") {
      xq("""orig:get("no_access")""")
        .assertHttpNotFound
        .go
    }
  }

  describe("orig:get-flat") {
    it("returns a flattened existing TEI resource") {
      xq("""orig:get-flat("existing")""")
        .assertXPath("""exists($output/tei:TEI)""", "the output is a TEI resource")
        .assertXPath("""exists($output/tei:TEI//jf:merged)""", "the returned resource is flattened")
        .go
    }

    it("returns 404 for a nonexisting resource") {
      xq("""orig:get-flat("does_not_exist")""")
        .assertHttpNotFound
        .go
    }

    it("returns 404 for a resource with no read access") {
      xq("""orig:get-flat("no_access")""")
        .assertHttpNotFound
        .go
    }
  }

  describe("orig:get-combined") {
    it("returns an untranscluded resource when transclude=false()") {
      xq("""orig:get-combined("has_transclude", false())""")
        .assertXPath("exists($output/tei:TEI)", "the resource is a TEI document")
        .assertXPath("exists($output/tei:TEI//jf:unflattened)", "the resource is unflattened")
        .assertXPath("exists($output/tei:TEI//tei:ptr[ancestor::jf:unflattened])", "the pointers are intact")
        .go
    }

    it("returns a transcluded resource when transclude=true()") {
      xq("""orig:get-combined("has_transclude", true())""")
        .assertXPath("exists($output/tei:TEI)", "the resource is a TEI document")
        .assertXPath("exists($output/tei:TEI//jf:combined)", "the resource is combined")
        .assertXPath("exists($output/tei:TEI//jf:ptr[ancestor::jf:combined])", "the pointers are converted to jf:ptr")
        .assertXPath("""exists($output/tei:TEI//tei:seg[@jf:id="tr_seg1"])""", "a section is transcluded")
        .go
    }

    it("returns HTTP 404 on a nonexisting resource") {
      xq("""orig:get-combined("does_not_exist", false())""")
        .assertHttpNotFound
        .go
    }

    it("returns HTTP 404 on an inaccessible resource") {
      xq("""orig:get-combined("no_access", false())""")
        .assertHttpNotFound
        .go
    }
  }

  describe("orig:get-combined-html") {
    it("returns an HTML resource when transclude=false()") {
      xq("""orig:get-combined-html("has_transclude", false())""")
        .assertXPath("exists($output/html:html)", "the resource is an HTML document")
        .go
    }

    it("returns a transcluded resource when transclude=true()") {
      xq("""orig:get-combined-html("has_transclude", true())""")
        .assertXPath("exists($output/html:html)", "the resource is an HTML document")
        .assertXPath("""exists($output/html:html//html:div[matches(@data-document,"^((/exist/restxq)?/api)?/data/original/transcluded$")])""", "the resource is combined")
        .assertXPath("""exists($output/html:html//html:div[contains(@class,"id-tr_seg1")])""", "a section is transcluded")
        .go
    }

    it("returns HTTP 404 on a nonexisting resource") {
      xq("""orig:get-combined-html("does_not_exist", false())""")
        .assertHttpNotFound
        .go
    }

    it("returns HTTP 404 on an inaccessible resource") {
      xq("""orig:get-combined-html("no_access", false())""")
        .assertHttpNotFound
        .go
    }
  }

  describe("orig:post-combined-job") {
    it("returns a job header and location on an existing document") {
      xq("""orig:post-combined-job("existing", false(), "html")""")
        .assertXPath("$output/self::rest:response/http:response/@status=202", "returns status 202")
        .assertXPath("$output/self::rest:response/http:response/http:header[@name='Location'][matches(@value, '/api/jobs/\\d+-\\d+')]", "returns the location header with job id")
        .go
    }

    it("returns HTTP 404 on a nonexisting resource") {
      xq("""orig:post-combined-job("does_not_exist", false(), "html")""")
        .assertHttpNotFound
        .go
    }

    it("returns HTTP 400 for an invalid format") {
      xq("""orig:post-combined-job("existing", false(), "invalid")""")
        .assertHttpBadRequest
        .go
    }

    it("returns HTTP 404 on an inaccessible resource") {
      xq("""orig:post-combined-job("no_access", false(), "html")""")
        .assertHttpNotFound
        .go
    }

  }

  describe("orig:list") {
    it("lists all resources when authenticated") {
      xq("""orig:list("", 1, 100)""")
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"])>=1""", "Returns at least one result")
        .assertXPath("""every $li in $output//html:li[@class="result"]
                       satisfies exists($li/html:a[@class="alt"][@property="access"])""", "Results include a pointer to the access API")
        .assertSearchResults
        .go
    }

    it("does not list resources for which there is no read access when unauthenticated") {
      xq("""orig:list("", 1, 100)""")
        .assertXPath("""count($output//html:li[@class="result"])>=1""", "Returns at least one result")
        .assertXPath("""empty($output//html:li[@class="result"]/html:a[@class="document"]/@href[contains(., "no_access")])""",
          "Does not list resources for which there is no access")
        .assertSearchResults
        .go
    }

    it("lists a limited number of resources") {
      xq("""orig:list("", 1, 2)""")
        .assertXPath("""count($output//html:li[@class="result"])=2""", "2 results returned")
        .assertSearchResults
        .go
    }

    it("responds to a query") {
      xq("""orig:list("query", 1, 100)""")
        .assertXPath("""count($output//html:ol[@class="results"]/html:li)=1""", "1 result returned")
        .assertSearchResults
        .go
    }
  }

  describe("orig:post") {
    it("posts a valid resource") {
      val validContent = readXmlFile("src/test/resources/api/data/original/valid.xml")

      xq(s"""orig:post(document { $validContent })""")
        .user("xqtest1")
        .assertHttpCreated
        .assertXPath(
          """collection('/db/data/original/en')
            [util:document-name(.)=tokenize($output//http:header[@name='Location']/@value,'/')[last()] || '.xml']
            //tei:revisionDesc/tei:change[1][@who="/user/xqtest1"][@type="created"]""", "A change record has been added")
        .go
    }

    it("validates a valid resource") {
      val validContent = readXmlFile("src/test/resources/api/data/original/valid.xml")

      xq(s"""orig:post(document { $validContent }, "true")""")
        .assertXPath("""$output/self::report/status='valid'""")
        .go
    }

    it("""invalidates an invalid resource""") {
      val invalidContent = readXmlFile("src/test/resources/api/data/original/invalid.xml")
      xq(s"""orig:post(document { $invalidContent }, "true")""")
        .assertXPath("$output/self::report/status = 'invalid'")
        .go
    }

    it("returns unauthorized when posting a valid resource unauthenticated") {
      val validContent = readXmlFile("src/test/resources/api/data/original/valid.xml")

      xq(s"""orig:post(document { $validContent })""")
        .assertHttpUnauthorized
        .go
    }

    it("rejects a post of an invalid resource") {
      val invalidContent = readXmlFile("src/test/resources/api/data/original/invalid.xml")
      xq(s"""orig:post(document { $invalidContent })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

    it("rejects a post of a resource lacking a title") {
      val invalidContent = readXmlFile("src/test/resources/api/data/original/no_title.xml")
      xq(s"""orig:post(document { $invalidContent })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

    it("updates a document with a valid external reference") {
      val validContent = readXmlFile("src/test/resources/api/data/original/test_valid_external_reference.xml")

      xq(s"""orig:post(document { $validContent })""")
        .user("xqtest1")
        .assertHttpCreated
        .go
    }

    it("rejects a resource with an invalid external reference") {
      val invalidContent = readXmlFile("src/test/resources/api/data/original/test_invalid_external_reference.xml")
      xq(s"""orig:post(document { $invalidContent })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }

  describe("orig:get-access") {
    it("returns an access structure for an existing document") {
      xq("""orig:get-access("existing", ())""")
        .user("xqtest1")
        .assertXPath("exists($output/self::a:access)", "an access structure is returned")
        .go
    }

    it("returns an access structure for an existing document when unauthenticated") {
      xq("""orig:get-access("existing", ())""")
        .assertXPath("exists($output/self::a:access)", "an access structure is returned")
        .go
    }

    it("returns not found for a nonexisting document") {
      xq("""orig:get-access("does_not_exist", ())""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
  }

  describe("orig:put-access") {
    it("returns 'no data' when setting access with a valid structure and authenticated") {
      xq(
        """orig:put-access("existing", document {
          <a:access>
            <a:owner>xqtest1</a:owner>
            <a:group write="true">everyone</a:group>
            <a:world read="true" write="true"/>
          </a:access>
        })""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }

    it("returns unauthorized on an existing document when unauthenticated") {
      xq(
        """orig:put-access("existing", document {
          <a:access>
            <a:owner>xqtest1</a:owner>
            <a:group write="false">everyone</a:group>
            <a:world read="false" write="false"/>
          </a:access>
        })""")
        .assertHttpUnauthorized
        .go
    }

    it("returns bad request when the access structure is invalid") {
      xq("""orig:put-access("existing", document {
                   <a:access>
                     <a:invalid/>
                   </a:access>
                 })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

    it("returns forbidden when there is no write access") {
      xq("""orig:put-access("no_write_access", document {
                   <a:access>
                     <a:owner>xqtest1</a:owner>
                     <a:group write="false">xqtest1</a:group>
                     <a:world write="false" read="false"/>
                   </a:access>
                 })""")
        .user("xqtest1")
        .assertHttpForbidden
        .go
    }

    it("returns not found when the document doesn't exist") {
      xq("""orig:put-access("does_not_exist", document {
                   <a:access>
                     <a:owner>xqtest1</a:owner>
                     <a:group write="false">xqtest1</a:group>
                     <a:world write="false" read="false"/>
                   </a:access>
                 })""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
  }

  describe("crest:record-change") {
    it("adds an edit record when there is a revisionDesc and change existing") {
      xq("""crest:record-change(doc("/db/data/original/en/with_revisiondesc_and_change.xml"), "edited")""")
        .user("xqtest1")
        .assertXPath(
          """doc('/db/data/original/en/with_revisiondesc_and_change.xml')//tei:revisionDesc/tei:change[1]
            [@when][@who='/user/xqtest1'][@type='edited']""", "change is recorded")
        .go
    }

    it("adds details to a record with revisionDesc and change log entry") {
      xq("""crest:record-change(doc("/db/data/original/en/with_revisiondesc_and_changelog.xml"), "edited")""")
        .user("xqtest1")
        .assertXPath("""count(doc('/db/data/original/en/with_revisiondesc_and_changelog.xml')//tei:revisionDesc/tei:change)=1""",
          "no change entry is inserted")
        .assertXPath(
          """doc('/db/data/original/en/with_revisiondesc_and_changelog.xml')//tei:revisionDesc/tei:change[1]
            [@when][@who='/user/xqtest1'][@type='edited']""", "change is recorded")
        .go
    }

    it("adds an edit record with empty revisionDesc") {
      xq("""crest:record-change(doc("/db/data/original/en/with_empty_revisiondesc.xml"), "edited")""")
        .user("xqtest1")
        .assertXPath(
          """doc('/db/data/original/en/with_empty_revisiondesc.xml')//tei:revisionDesc/tei:change[1]
            [@when][@who='/user/xqtest1'][@type='edited']""", "change is recorded")
        .go
    }

    it("adds an edit record with no revisionDesc") {
      xq("""crest:record-change(doc("/db/data/original/en/with_no_revisiondesc.xml"), "created")""")
        .user("xqtest1")
        .assertXPath(
          """doc('/db/data/original/en/with_no_revisiondesc.xml')//tei:revisionDesc/tei:change[1]
            [@when][@who='/user/xqtest1'][@type='created']""", "change is recorded in a new revisionDesc")
        .go
    }
  }

  describe("orig:linkage-query-function") {
    it("finds linkage documents associated with an original document") {
      xq("""orig:linkage-query-function(doc("/db/data/original/en/test_doc_1.xml"), ())""")
        .user("xqtest1")
        .assertXPath("""count($output) = 2 and $output/tei:idno="TEST" and $output/tei:idno="ANOTHER"""",
          "The expected linkages are returned")
        .go
    }

    it("finds linkage documents associated with an original document, when limited by a query string") {
      xq("""orig:linkage-query-function(doc("/db/data/original/en/test_doc_1.xml"), "TES")""")
        .user("xqtest1")
        .assertXPath("""count($output) = 1 and $output/tei:idno="TEST"""",
          "The expected linkages are returned")
        .go
    }
  }

  describe("orig:linkage-title-function") {
    val linkageData = readXmlFile("src/test/resources/api/data/original/link_doc_1.xml")

    it("returns the id of a linkage parallel group") {
      xq(
        s"""let $$data := document { $linkageData }
           return orig:linkage-title-function($$data//j:parallelText)""")
        .assertEquals("TEST")
        .go
    }
  }

  describe("orig:get-linkage") {
    it("returns a list of linkages and ids to an original document") {
      xq("""orig:get-linkage("test_doc_1", (), 1, 100)""")
        .assertXPath("""count($output//html:li[@class="result"])=2""", "2 results")
        .assertXPath("""every $id in ("TEST", "ANOTHER") satisfies $output//html:li[@class="result"]/html:a=$id""",
          "Expected ids are returned")
        .assertXPath("""every $link in $output//html:li[@class="result"]/html:a satisfies (
        let $expected-link :=
            if ($link = "TEST") then "link_doc_1"
            else if ($link = "ANOTHER") then "link_doc_2"
            else ()
        return
            matches($link/@href, "/api/data/linkage/" || $expected-link || "$"))""",
          "ids are connected to the correct documents")
        .go
    }
  }

  describe("orig:validate") {

    it("invalidates a document with duplicate xml:ids") {
      val invalidDupe = readXmlFile("src/test/resources/api/data/original/duplicate_xml_id.xml")
      xq(s"""orig:validate-report(document { $invalidDupe }, ())""")
        .assertXPath("$output/status = 'invalid'", "The document is marked invalid")
        .go
    }

    it("validates the same document without duplicate xml:ids") {
      val validNoDupe = readXmlFile("src/test/resources/api/data/original/no_duplicate_xml_id.xml")
      xq(s"""orig:validate-report(document { $validNoDupe }, ())""")
        .assertXPath("$output/status = 'valid'", "The document is marked valid")
        .go
    }

    it("invalidates a document with an invalid source (regression test for #208)") {
      val invalidBadSource = readXmlFile("src/test/resources/api/data/original/bad_source.xml")
      xq(s"""orig:validate-report(document { $invalidBadSource }, ())""")
        .assertXPath("$output/status = 'invalid'", "The document is marked invalid")
        .go
    }
  }

}

// delete will delete data and put will alter data, so we need a separate fixture
class TestOriginalWithReset extends OriginalDataTestFixtures {
  override def beforeEach = {
    super.beforeEach()
    setup()
  }

  override def afterEach = {
    tearDown()
    super.afterEach()
  }

  describe("orig:put") {
    it("successfully puts a valid resource to an existing resource") {
      val validContent = readXmlFile("src/test/resources/api/data/original/existing_after_put.xml")

      xq(s"""orig:put("existing", document { $validContent })""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath(
          """doc('/db/data/original/en/existing.xml')
            //tei:revisionDesc/tei:change[1][@who="/user/xqtest1"][@type="edited"][@who="/user/xqtest1"][@when]""", "A change record has been added")
        .assertXPath("""count(doc('/db/data/original/en/existing.xml')//tei:revisionDesc/tei:change)=2""", "There are 2 change records total")
        .go
    }

    it("returns unauthorized when putting a valid resource to an existing resource unauthenticated") {
      val validContent = readXmlFile("src/test/resources/api/data/original/existing_after_put.xml")

      xq(s"""orig:put("existing", document { $validContent })""")
        .assertHttpUnauthorized
        .go
    }

    it("flags an error when a resource is put to a nonexistent resource") {
      val validContent = readXmlFile("src/test/resources/api/data/original/valid.xml")

      xq(s"""orig:put("does_not_exist", document { $validContent })""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("flags an error when a resource is put to a nonexistent resource unauthenticated") {
      val validContent = readXmlFile("src/test/resources/api/data/original/valid.xml")

      xq(s"""orig:put("does_not_exist", document { $validContent })""")
        .assertHttpNotFound
        .go
    }


    it("flags an error on put of an invalid resource to an existing resource") {
      val invalidContent = readXmlFile("src/test/resources/api/data/original/invalid.xml")

      xq(s"""orig:put("existing", document { $invalidContent })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

    it("flags an error on a resource that is invalidated by an illegal change") {
      val invalidContent = readXmlFile("src/test/resources/api/data/original/invalid_after_put_illegal_revisiondesc.xml")

      xq(s"""orig:put("existing", document { $invalidContent })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }

  describe("orig:delete") {
    it("removes an existing resource") {
      xq("""orig:delete("existing")""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }

    it("returns unauthorized when unauthenticated") {
      xq("""orig:delete("existing")""")
        .assertHttpUnauthorized
        .go
    }

    it("returns HTTP 404 for removing a nonexistent resource") {
      xq("""orig:delete("does_not_exist")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("returns HTTP 404 for removing a nonexistent resource, when unauthenticated") {
      xq("""orig:delete("does_not_exist")""")
        .assertHttpNotFound
        .go
    }

    it("returns forbidden when removing a resource with no write access") {
      xq("""orig:delete("no_write_access")""")
        .user("xqtest1")
        .assertHttpForbidden
        .go
    }

    it("deletes a resource with only an internal reference") {
      xq("""orig:delete("external_reference")""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }
  }

  describe("orig:put-flat") {
    it("puts a valid flattened resource to an existing resource") {
      val existingFlat = readXmlFile("src/test/resources/api/data/original/existing_flat.xml")

      xq(s"""orig:put-flat("existing", document { $existingFlat })""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath(
          """(collection('/db/data/original/en')[util:document-name(.)='existing.xml']//tei:revisionDesc/tei:change)[1]
            [@type="edited"][@who="/user/xqtest1"][@when]""", "A change record has been added")
        .go
    }

    it("returns not found when the resource does not exist") {
      val validFlat = readXmlFile("src/test/resources/api/data/original/valid_flat.xml")
      xq(s"""orig:put-flat("does_not_exist", document { $validFlat })""")
        .assertHttpNotFound
        .go
    }

    it("returns bad request when the resource is not valid") {
      val invalidFlat = readXmlFile("src/test/resources/api/data/original/invalid_flat.xml")

      xq(s"""orig:put-flat("existing", document { $invalidFlat })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }
}

class TestOriginalDeleteWithExternalReference extends OriginalDataTestFixtures {
  override def beforeEach() = {
    super.beforeEach()
    setup()
    setupResource("src/test/resources/api/data/original/makes_external_reference.xml",
      "makes_external_reference", "original", 1,
      group=Some("everyone"),permissions=Some("rw-r--r--"))
  }

  override def afterEach() = {
    teardownResource("makes_external_reference", "original", 1)
    tearDown()
    super.afterEach()
  }

  describe("orig:delete") {
    it("refuses to delete a resource with an external reference") {
      xq("""orig:delete("external_reference")""")
        .user("xqtest1")
        .assertHttpBadRequest
        .assertXPath("""count($output//documents/document)=1 and ends-with(.//documents/document,"/data/original/makes_external_reference")""",
        "error message returns a reference to the document where the external reference is")
    }
  }
}