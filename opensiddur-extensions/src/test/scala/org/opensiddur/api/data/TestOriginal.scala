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

    setupResource("src/test/resources/api/data/original/Existing.xml",
      "Existing", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/api/data/original/Existing.xml",
      "NoAccess", "original", 2, Some("en"),
      group=Some("everyone"),permissions=Some("rw-------"))
    setupResource("src/test/resources/api/data/original/Existing.xml",
      "NoWriteAccess", "original", 2, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/QueryResult.xml",
      "QueryResult", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/api/data/original/HasTransclude.xml",
      "HasTransclude", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/api/data/original/Transcluded.xml",
      "Transcluded", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/api/data/original/ExternalReference.xml",
      "ExternalReference", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/With-RevisionDesc-And-Change.xml",
      "WithRevisionDescAndChange", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/With-RevisionDesc-And-ChangeLog.xml",
      "WithRevisionDescAndChangeLog", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/With-No-RevisionDesc.xml",
      "WithNoRevisionDesc", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/With-Empty-RevisionDesc.xml",
      "WithEmptyRevisionDesc", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/TestDoc1.xml",
      "TestDoc1", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/TestDoc2.xml",
      "TestDoc2", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/LinkDoc1.xml",
      "LinkDoc1", "linkage", 1, None,
      group=Some("everyone"),permissions=Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/original/LinkDoc2.xml",
      "LinkDoc2", "linkage", 1, None,
      group=Some("everyone"),permissions=Some("rw-r--r--"))
  }

  def tearDown(): Unit = {
    teardownResource("LinkDoc2", "linkage", 1)
    teardownResource("LinkDoc1", "linkage", 1)
    teardownResource("TestDoc2", "original", 1)
    teardownResource("TestDoc1", "original", 1)
    teardownResource("WithNoRevisionDesc", "original", 1)
    teardownResource("WithEmptyRevisionDesc", "original", 1)
    teardownResource("WithRevisionDescAndChangeLog", "original", 1)
    teardownResource("WithRevisionDescAndChange", "original", 1)
    teardownResource("TestInvalidExternalReference", "original", 1)
    teardownResource("TestValidExternalReference", "original", 1)
    teardownResource("Valid", "original", 1)
    teardownResource("Existing", "original", 1)
    teardownResource("NoAccess", "original", 2)
    teardownResource("NoWriteAccess", "original", 2)
    teardownResource("QueryResult", "original", 1)
    teardownResource("HasTransclude", "original", 1)
    teardownResource("Transcluded", "original", 1)
    teardownResource("ExternalReference", "original", 1)

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
      xq("orig:get('Existing')")
        .user("xqtest1")
        .assertXPath("""exists($output/tei:TEI)""", "Returns a TEI resource")
        .go
    }

    it("returns a successful http call for an existing document when unauthenticated") {
      xq("orig:get('Existing')")
        .assertXPath("""exists($output/tei:TEI)""", "Returns a TEI resource")
        .go
    }

    it("returns not found for a nonexisting resource") {
      xq("""orig:get("DoesNotExist")""")
        .assertHttpNotFound
        .go
    }

    it("returns not found where there is no read access when authenticated") {
      xq("""orig:get("NoAccess")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("returns not found where there is no read access when unauthenticated") {
      xq("""orig:get("NoAccess")""")
        .assertHttpNotFound
        .go
    }
  }

  describe("orig:get-flat") {
    it("returns a flattened existing TEI resource") {
      xq("""orig:get-flat("Existing")""")
        .assertXPath("""exists($output/tei:TEI)""", "the output is a TEI resource")
        .assertXPath("""exists($output/tei:TEI//jf:merged)""", "the returned resource is flattened")
        .go
    }

    it("returns 404 for a nonexisting resource") {
      xq("""orig:get-flat("DoesNotExist")""")
        .assertHttpNotFound
        .go
    }

    it("returns 404 for a resource with no read access") {
      xq("""orig:get-flat("NoAccess")""")
        .assertHttpNotFound
        .go
    }
  }

  describe("orig:get-combined") {
    it("returns an untranscluded resource when transclude=false()") {
      xq("""orig:get-combined("HasTransclude", false())""")
        .assertXPath("exists($output/tei:TEI)", "the resource is a TEI document")
        .assertXPath("exists($output/tei:TEI//jf:unflattened)", "the resource is unflattened")
        .assertXPath("exists($output/tei:TEI//tei:ptr[ancestor::jf:unflattened])", "the pointers are intact")
        .go
    }

    it("returns a transcluded resource when transclude=true()") {
      xq("""orig:get-combined("HasTransclude", true())""")
        .assertXPath("exists($output/tei:TEI)", "the resource is a TEI document")
        .assertXPath("exists($output/tei:TEI//jf:combined)", "the resource is combined")
        .assertXPath("exists($output/tei:TEI//jf:ptr[ancestor::jf:combined])", "the pointers are converted to jf:ptr")
        .assertXPath("""exists($output/tei:TEI//tei:seg[@jf:id="tr_seg1"])""", "a section is transcluded")
        .go
    }

    it("returns HTTP 404 on a nonexisting resource") {
      xq("""orig:get-combined("DoesNotExist", false())""")
        .assertHttpNotFound
        .go
    }

    it("returns HTTP 404 on an inaccessible resource") {
      xq("""orig:get-combined("NoAccess", false())""")
        .assertHttpNotFound
        .go
    }
  }

  describe("orig:get-combined-html") {
    it("returns an HTML resource when transclude=false()") {
      xq("""orig:get-combined-html("HasTransclude", false())""")
        .assertXPath("exists($output/html:html)", "the resource is an HTML document")
        .go
    }

    it("returns a transcluded resource when transclude=true()") {
      xq("""orig:get-combined-html("HasTransclude", true())""")
        .assertXPath("exists($output/html:html)", "the resource is an HTML document")
        .assertXPath("""exists($output/html:html//html:div[matches(@data-document,"^((/exist/restxq)?/api)?/data/original/Transcluded$")])""", "the resource is combined")
        .assertXPath("""exists($output/html:html//html:div[contains(@class,"id-tr_seg1")])""", "a section is transcluded")
        .go
    }

    it("returns HTTP 404 on a nonexisting resource") {
      xq("""orig:get-combined-html("DoesNotExist", false())""")
        .assertHttpNotFound
        .go
    }

    it("returns HTTP 404 on an inaccessible resource") {
      xq("""orig:get-combined-html("NoAccess", false())""")
        .assertHttpNotFound
        .go
    }
  }

  describe("orig:post-combined-job") {
    it("returns a job header and location on an existing document") {
      xq("""orig:post-combined-job("Existing", false(), "html")""")
        .assertXPath("$output/self::rest:response/http:response/@status=202", "returns status 202")
        .assertXPath("$output/self::rest:response/http:response/http:header[@name='Location'][matches(@value, '/api/jobs/\\d+-\\d+')]", "returns the location header with job id")
        .go
    }

    it("returns HTTP 404 on a nonexisting resource") {
      xq("""orig:post-combined-job("DoesNotExist", false(), "html")""")
        .assertHttpNotFound
        .go
    }

    it("returns HTTP 400 for an invalid format") {
      xq("""orig:post-combined-job("Existing", false(), "invalid")""")
        .assertHttpBadRequest
        .go
    }

    it("returns HTTP 404 on an inaccessible resource") {
      xq("""orig:post-combined-job("NoAccess", false(), "html")""")
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
        .assertXPath("""empty($output//html:li[@class="result"]/html:a[@class="document"]/@href[contains(., "NoAccess")])""",
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
      xq("""orig:list("Query", 1, 100)""")
        .assertXPath("""count($output//html:ol[@class="results"]/html:li)=1""", "1 result returned")
        .assertSearchResults
        .go
    }
  }

  describe("orig:post") {
    it("posts a valid resource") {
      val validContent = readXmlFile("src/test/resources/api/data/original/Valid.xml")

      xq(s"""orig:post(document { $validContent })""")
        .user("xqtest1")
        .assertHttpCreated
        .assertXPath(
          """collection('/db/data/original/en')
            [util:document-name(.)=tokenize($output//http:header[@name='Location']/@value,'/')[last()] || '.xml']
            //tei:revisionDesc/tei:change[1][@who="/user/xqtest1"][@type="created"]""", "A change record has been added")
        .go
    }

    it("returns unauthorized when posting a valid resource unauthenticated") {
      val validContent = readXmlFile("src/test/resources/api/data/original/Valid.xml")

      xq(s"""orig:post(document { $validContent })""")
        .assertHttpUnauthorized
        .go
    }

    it("rejects a post of an invalid resource") {
      val invalidContent = readXmlFile("src/test/resources/api/data/original/Invalid.xml")
      xq(s"""orig:post(document { $invalidContent })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

    it("rejects a post of a resource lacking a title") {
      val invalidContent = readXmlFile("src/test/resources/api/data/original/Notitle.xml")
      xq(s"""orig:post(document { $invalidContent })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

    it("updates a document with a valid external reference") {
      val validContent = readXmlFile("src/test/resources/api/data/original/TestValidExternalReference.xml")

      xq(s"""orig:post(document { $validContent })""")
        .user("xqtest1")
        .assertHttpCreated
        .go
    }

    it("rejects a resource with an invalid external reference") {
      val invalidContent = readXmlFile("src/test/resources/api/data/original/TestInvalidExternalReference.xml")
      xq(s"""orig:post(document { $invalidContent })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }

  describe("orig:get-access") {
    it("returns an access structure for an existing document") {
      xq("""orig:get-access("Existing", ())""")
        .user("xqtest1")
        .assertXPath("exists($output/self::a:access)", "an access structure is returned")
        .go
    }

    it("returns an access structure for an existing document when unauthenticated") {
      xq("""orig:get-access("Existing", ())""")
        .assertXPath("exists($output/self::a:access)", "an access structure is returned")
        .go
    }

    it("returns not found for a nonexisting document") {
      xq("""orig:get-access("DoesNotExist", ())""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
  }

  describe("orig:put-access") {
    it("returns 'no data' when setting access with a valid structure and authenticated") {
      xq(
        """orig:put-access("Existing", document {
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
        """orig:put-access("Existing", document {
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
      xq("""orig:put-access("Existing", document {
                   <a:access>
                     <a:invalid/>
                   </a:access>
                 })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

    it("returns forbidden when there is no write access") {
      xq("""orig:put-access("NoWriteAccess", document {
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
      xq("""orig:put-access("DoesNotExist", document {
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
      xq("""crest:record-change(doc("/db/data/original/en/WithRevisionDescAndChange.xml"), "edited")""")
        .user("xqtest1")
        .assertXPath(
          """doc('/db/data/original/en/WithRevisionDescAndChange.xml')//tei:revisionDesc/tei:change[1]
            [@when][@who='/user/xqtest1'][@type='edited']""", "change is recorded")
        .go
    }

    it("adds details to a record with revisionDesc and change log entry") {
      xq("""crest:record-change(doc("/db/data/original/en/WithRevisionDescAndChangeLog.xml"), "edited")""")
        .user("xqtest1")
        .assertXPath("""count(doc('/db/data/original/en/WithRevisionDescAndChangeLog.xml')//tei:revisionDesc/tei:change)=1""",
          "no change entry is inserted")
        .assertXPath(
          """doc('/db/data/original/en/WithRevisionDescAndChangeLog.xml')//tei:revisionDesc/tei:change[1]
            [@when][@who='/user/xqtest1'][@type='edited']""", "change is recorded")
        .go
    }

    it("adds an edit record with empty revisionDesc") {
      xq("""crest:record-change(doc("/db/data/original/en/WithEmptyRevisionDesc.xml"), "edited")""")
        .user("xqtest1")
        .assertXPath(
          """doc('/db/data/original/en/WithEmptyRevisionDesc.xml')//tei:revisionDesc/tei:change[1]
            [@when][@who='/user/xqtest1'][@type='edited']""", "change is recorded")
        .go
    }

    it("adds an edit record with no revisionDesc") {
      xq("""crest:record-change(doc("/db/data/original/en/WithNoRevisionDesc.xml"), "created")""")
        .user("xqtest1")
        .assertXPath(
          """doc('/db/data/original/en/WithNoRevisionDesc.xml')//tei:revisionDesc/tei:change[1]
            [@when][@who='/user/xqtest1'][@type='created']""", "change is recorded in a new revisionDesc")
        .go
    }
  }

  describe("orig:linkage-query-function") {
    it("finds linkage documents associated with an original document") {
      xq("""orig:linkage-query-function(doc("/db/data/original/en/TestDoc1.xml"), ())""")
        .user("xqtest1")
        .assertXPath("""count($output) = 2 and $output/tei:idno="TEST" and $output/tei:idno="ANOTHER"""",
          "The expected linkages are returned")
        .go
    }

    it("finds linkage documents associated with an original document, when limited by a query string") {
      xq("""orig:linkage-query-function(doc("/db/data/original/en/TestDoc1.xml"), "TES")""")
        .user("xqtest1")
        .assertXPath("""count($output) = 1 and $output/tei:idno="TEST"""",
          "The expected linkages are returned")
        .go
    }
  }

  describe("orig:linkage-title-function") {
    val linkageData = readXmlFile("src/test/resources/api/data/original/LinkDoc1.xml")

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
      xq("""orig:get-linkage("TestDoc1", (), 1, 100)""")
        .assertXPath("""count($output//html:li[@class="result"])=2""", "2 results")
        .assertXPath("""every $id in ("TEST", "ANOTHER") satisfies $output//html:li[@class="result"]/html:a=$id""",
          "Expected ids are returned")
        .assertXPath("""every $link in $output//html:li[@class="result"]/html:a satisfies (
        let $expected-link :=
            if ($link = "TEST") then "LinkDoc1"
            else if ($link = "ANOTHER") then "LinkDoc2"
            else ()
        return
            matches($link/@href, "/api/data/linkage/" || $expected-link || "$"))""",
          "ids are connected to the correct documents")
        .go
    }
  }

  describe("orig:validate") {

    it("invalidates a document with duplicate xml:ids") {
      val invalidDupe = readXmlFile("src/test/resources/api/data/original/DuplicateXmlId.xml")
      xq(s"""orig:validate-report(document { $invalidDupe }, ())""")
        .assertXPath("$output/status = 'invalid'", "The document is marked invalid")
        .go
    }

    it("validates the same document without duplicate xml:ids") {
      val validNoDupe = readXmlFile("src/test/resources/api/data/original/NoDuplicateXmlId.xml")
      xq(s"""orig:validate-report(document { $validNoDupe }, ())""")
        .assertXPath("$output/status = 'valid'", "The document is marked valid")
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
      val validContent = readXmlFile("src/test/resources/api/data/original/Existing-After-Put.xml")

      xq(s"""orig:put("Existing", document { $validContent })""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath(
          """doc('/db/data/original/en/Existing.xml')
            //tei:revisionDesc/tei:change[1][@who="/user/xqtest1"][@type="edited"][@who="/user/xqtest1"][@when]""", "A change record has been added")
        .assertXPath("""count(doc('/db/data/original/en/Existing.xml')//tei:revisionDesc/tei:change)=2""", "There are 2 change records total")
        .go
    }

    it("returns unauthorized when putting a valid resource to an existing resource unauthenticated") {
      val validContent = readXmlFile("src/test/resources/api/data/original/Existing-After-Put.xml")

      xq(s"""orig:put("Existing", document { $validContent })""")
        .assertHttpUnauthorized
        .go
    }

    it("flags an error when a resource is put to a nonexistent resource") {
      val validContent = readXmlFile("src/test/resources/api/data/original/Valid.xml")

      xq(s"""orig:put("DoesNotExist", document { $validContent })""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("flags an error when a resource is put to a nonexistent resource unauthenticated") {
      val validContent = readXmlFile("src/test/resources/api/data/original/Valid.xml")

      xq(s"""orig:put("DoesNotExist", document { $validContent })""")
        .assertHttpNotFound
        .go
    }


    it("flags an error on put of an invalid resource to an existing resource") {
      val invalidContent = readXmlFile("src/test/resources/api/data/original/Invalid.xml")

      xq(s"""orig:put("Existing", document { $invalidContent })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

    it("flags an error on a resource that is invalidated by an illegal change") {
      val invalidContent = readXmlFile("src/test/resources/api/data/original/Invalid-After-Put-Illegal-RevisionDesc.xml")

      xq(s"""orig:put("Existing", document { $invalidContent })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }

  describe("orig:delete") {
    it("removes an existing resource") {
      xq("""orig:delete("Existing")""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }

    it("returns unauthorized when unauthenticated") {
      xq("""orig:delete("Existing")""")
        .assertHttpUnauthorized
        .go
    }

    it("returns HTTP 404 for removing a nonexistent resource") {
      xq("""orig:delete("DoesNotExist")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("returns HTTP 404 for removing a nonexistent resource, when unauthenticated") {
      xq("""orig:delete("DoesNotExist")""")
        .assertHttpNotFound
        .go
    }

    it("returns forbidden when removing a resource with no write access") {
      xq("""orig:delete("NoWriteAccess")""")
        .user("xqtest1")
        .assertHttpForbidden
        .go
    }

    it("deletes a resource with only an internal reference") {
      xq("""orig:delete("ExternalReference")""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }
  }

  describe("orig:put-flat") {
    it("puts a valid flattened resource to an existing resource") {
      val existingFlat = readXmlFile("src/test/resources/api/data/original/Existing-Flat.xml")

      xq(s"""orig:put-flat("Existing", document { $existingFlat })""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath(
          """(collection('/db/data/original/en')[util:document-name(.)='Existing.xml']//tei:revisionDesc/tei:change)[1]
            [@type="edited"][@who="/user/xqtest1"][@when]""", "A change record has been added")
        .go
    }

    it("returns not found when the resource does not exist") {
      val validFlat = readXmlFile("src/test/resources/api/data/original/Valid-Flat.xml")
      xq(s"""orig:put-flat("DoesNotExist", document { $validFlat })""")
        .assertHttpNotFound
        .go
    }

    it("returns bad request when the resource is not valid") {
      val invalidFlat = readXmlFile("src/test/resources/api/data/original/Invalid-Flat.xml")

      xq(s"""orig:put-flat("Existing", document { $invalidFlat })""")
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
    setupResource("src/test/resources/api/data/original/MakesExternalReference.xml",
      "MakesExternalReference", "original", 1,
      group=Some("everyone"),permissions=Some("rw-r--r--"))
  }

  override def afterEach() = {
    teardownResource("MakesExternalReference", "original", 1)
    tearDown()
    super.afterEach()
  }

  describe("orig:delete") {
    it("refuses to delete a resource with an external reference") {
      xq("""orig:delete("ExternalReference")""")
        .user("xqtest1")
        .assertHttpBadRequest
        .assertXPath("""count($output//documents/document)=1 and ends-with(.//documents/document,"/data/original/MakesExternalReference")""",
        "error message returns a reference to the document where the external reference is")
    }
  }
}