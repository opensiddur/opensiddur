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
    xq(
      """let $user := tcommon:setup-test-users(2)
         return ()
        """)
      .go
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
  }

  def tearDown(): Unit = {
    teardownResource("Existing", "original", 1)
    teardownResource("NoAccess", "original", 2)
    teardownResource("NoWriteAccess", "original", 2)
    teardownResource("QueryResult", "original", 1)
    teardownResource("HasTransclude", "original", 1)
    teardownResource("Transcluded", "original", 1)
    teardownResource("ExternalReference", "original", 1)
    xq(
      """let $user := tcommon:teardown-test-users(2)
         return ()
        """)
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
    it("returns a successful http call for an existing document") {
      xq("orig:get('Existing')")
        .assertXPath("""exists($output/tei:TEI)""", "Returns a TEI resource")
        .go
    }

    it("returns not found for a nonexisting resource") {
      xq("""orig:get("DoesNotExist")""")
        .assertHttpNotFound
        .go
    }

    it("returns not found where there is no read access") {
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
    it("lists all resources") {
      xq("""orig:list("", 1, 100)""")
        .assertXPath("""count($output//html:li[@class="result"])>=1""", "Returns at least one result")
        .assertXPath("""every $li in $output//html:li[@class="result"]
                       satisfies exists($li/html:a[@class="alt"][@property="access"])""", "Results include a pointer to the access API")
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

}

// delete will delete data, so we need a separate fixture
class TestOriginalDelete extends OriginalDataTestFixtures {
  override def beforeEach = {
    super.beforeEach()
    setup()
  }

  override def afterEach = {
    tearDown()
    super.afterEach()
  }
  describe("orig:delete") {
    it("removes an existing resource") {
      xq("""orig:delete("Existing")""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }

    it("returns HTTP 404 for removing a nonexistent resource") {
      xq("""orig:delete("DoesNotExist")""")
        .user("xqtest1")
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