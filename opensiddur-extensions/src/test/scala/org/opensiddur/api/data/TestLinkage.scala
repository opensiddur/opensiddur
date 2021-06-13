package org.opensiddur.api.data

import org.opensiddur.DbTest

class TestLinkage extends DbTest {
  override val prolog: String =
    """xquery version '3.1';
import module namespace lnk="http://jewishliturgy.org/api/data/linkage"
  at "xmldb:exist:/db/apps/opensiddur-server/api/data/linkage.xqm";
import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
 at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace a="http://jewishliturgy.org/ns/access/1.0";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";
declare namespace o="http://a9.com/-/spec/opensearch/1.1/";
declare namespace http="http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
"""

  override def beforeAll: Unit = {
    super.beforeAll
    setupUsers(2)
    setupResource("src/test/resources/api/data/linkage/original-a.xml", "a-he", "original", 1, Some("he"))
    setupResource("src/test/resources/api/data/linkage/original-b.xml", "b-en", "original", 1, Some("en"))
  }

  override def beforeEach: Unit = {
    super.beforeEach()
    setupResource("src/test/resources/api/data/linkage/existing.xml", "existing", "linkage", 1, Some("none"))
    setupResource("src/test/resources/api/data/linkage/existing.xml", "noaccess", "linkage", 2, Some("none"),
      Some("everyone"), Some("rw-------"))
    setupResource("src/test/resources/api/data/linkage/existing.xml", "nowriteaccess", "linkage", 2, Some("none"),
      Some("everyone"), Some("rw-r--r--"))
  }

  override def afterEach(): Unit = {
    teardownResource("nowriteaccess", "linkage", 2)
    teardownResource("noaccess", "linkage", 2)
    teardownResource("existing", "linkage", 1)
    teardownResource("valid", "linkage", 1)
    super.afterEach()
  }

  override def afterAll(): Unit = {
    teardownResource("existing", "linkage", 1)
    teardownResource("a-he", "original", 1)
    teardownResource("b-en", "original", 1)
    teardownUsers(2)
    super.afterAll()
  }

  describe("lnk:get") {
    it("returns an existing resource") {
      xq("""lnk:get("existing")""")
        .user("xqtest1")
        .assertXPath("exists($output/tei:TEI)", "Returns a resource")
        .go
    }

    it("returns an existing resource unauthenticated") {
      xq("""lnk:get("existing")""")
        .assertXPath("exists($output/tei:TEI)", "Returns a resource")
        .go
    }

    it("returns 404 for a nonexisting resource") {
      xq("""lnk:get("nonexisting")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("returns error when there is no read access") {
      xq("""lnk:get("noaccess")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
  }

  describe("lnk:get-combined") {
    it("returns a combined resource") {
      xq("""lnk:get-combined("existing")""")
        .user("xqtest1")
        .assertXPath("exists($output//tei:TEI//jf:unflattened)", "Returns unflattened data")
        .go
    }

    it("returns a combined resource unauthenticated") {
      xq("""lnk:get-combined("existing")""")
        .assertXPath("exists($output//tei:TEI//jf:unflattened)", "Returns unflattened data")
        .go
    }
  }

  describe("lnk:list") {
    it("returns a list of existing resources") {
      xq("""lnk:list("", 1, 100)""")
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"]) >= 1""", "returns at least 1 result")
        .assertXPath(
          """every $li in $output//html:li[@class="result"]
            satisfies exists($li/html:a[@class="alt"][@property="access"])""", "results include a pointer to access API")
        .assertXPath(
          """every $li in $output//html:li[@class="result"]
            satisfies exists($li/html:a[@class="alt"][@property="combined"])""", "results include a pointer to combined API")
        .assertSearchResults
        .go
    }

    it("returns a list of existing resources unauthenticated") {
      xq("""lnk:list("", 1, 100)""")
        .assertXPath("""count($output//html:li[@class="result"]) >= 1""", "returns at least 1 result")
        .assertXPath("""empty($output//html:li[@class="result"]/html:a[@class="document"]/@href[contains(., "noaccess")])""",
          "does not list the resource with no read access")
        .assertSearchResults
        .go
    }

    it("returns a limited number of results") {
      xq("""lnk:list("", 1, 2)""")
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"])=2""", "returns 2 results")
        .assertSearchResults
        .go
    }

    it("limits search results to a query") {
      xq("""lnk:list("Query", 1, 100)""")
        .user("xqtest1")
        .assertXPath("""count($output//html:ol[@class="results"]/html:li)=2""", "returns 2 results (Existing and NoWriteAccess)")
        .assertSearchResults
        .go
    }
  }

  describe("lnk:delete") {
    it("deletes an existing resource") {
      xq("""lnk:delete("existing")""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }

    it("returns an error deleting an existing resource unauthenticated") {
      xq("""lnk:delete("existing")""")
        .assertHttpUnauthorized
        .go
    }

    it("returns an error when deleting a nonexisting resource") {
      xq("""lnk:delete("nonexisting")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("returns an error when deleting a resource without write access") {
      xq("""lnk:delete("nowriteaccess")""")
        .user("xqtest1")
        .assertHttpForbidden
        .go
    }
  }

  describe("lnk:post") {
    val validContent = readXmlFile("src/test/resources/api/data/linkage/valid.xml")
    val invalidContent = readXmlFile("src/test/resources/api/data/linkage/invalid.xml")

    it("posts valid content") {
      xq(s"""lnk:post(document { $validContent })""")
        .user("xqtest1")
        .assertHttpCreated
        .assertXPathEquals(
          """collection('/db/data/linkage/none')
                      [util:document-name(.)=tokenize($output//http:header[@name='Location']/@value,'/')[last()] || '.xml']//
                      tei:revisionDesc/tei:change[1]""",
          "a change record has been added",
          """<tei:change xmlns:tei="http://www.tei-c.org/ns/1.0" type="created" who="/user/xqtest1"
                        when="..."/>"""
        )
        .go
    }

    it("returns an error when posting unauthenticated") {
      xq(s"""lnk:post(document { $validContent })""")
        .assertHttpUnauthorized
        .go
    }

    it("returns an error when posting invalid content") {
      xq(s"""lnk:post(document { $invalidContent })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }

  describe("lnk:put") {
    val validContent = readXmlFile("src/test/resources/api/data/linkage/existing-after-put.xml")
    val invalidContent = readXmlFile("src/test/resources/api/data/linkage/invalid.xml")

    it("puts a valid resource") {
      xq(s""" lnk:put("existing", document { $validContent })""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath("""count(doc('/db/data/linkage/none/existing.xml')//tei:revisionDesc/tei:change)=2""", "There are 2 change records total")
        .assertXPath("""doc('/db/data/linkage/none/existing.xml')//tei:revisionDesc/tei:change[1][@who="/user/xqtest1"][@type="edited"][@when]""",
        """a change record is added""")
        .go
    }

    it("returns an error when putting a valid resource unauthenticated") {
      xq(s""" lnk:put("existing", document { $validContent })""")
        .assertHttpUnauthorized
        .go
    }

    it("returns an error when putting a non-existent resource") {
      xq(s"""lnk:put("doesnotexist", document { $validContent })""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("returns an error when putting an invalid resource") {
      xq(s"""lnk:put("existing", document { $invalidContent })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

    it("returns an error when putting an valid resource with an invalid change") {
      val invalidChangeContent = readXmlFile("src/test/resources/api/data/linkage/existing-with-invalid-revision-desc.xml")

      xq(s"""lnk:put("existing", document { $invalidChangeContent })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }

  describe("lnk:get-access") {
    it("returns an access structure") {
      xq("""lnk:get-access("existing", ())""")
        .assertXPath("exists($output/self::a:access)", "an access structure is returned")
        .go
    }

    it("returns an error for a nonexisting document") {
      xq("""lnk:get-access("doesnotexist", ())""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
  }

  describe("lnk:put-access") {
    it("sets access") {
      xq("""lnk:put-access("existing", document{
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

    it("returns an error unauthenticated") {
      xq("""lnk:put-access("existing", document{
                                                      <a:access>
                                                        <a:owner>xqtest1</a:owner>
                                                        <a:group write="false">everyone</a:group>
                                                        <a:world read="false" write="false"/>
                                                      </a:access>
                                                      })""")
        .assertHttpUnauthorized
        .go
    }

    it("returns an error for a nonexisting document") {
      xq("""lnk:put-access("doesnotexist", document{
                                                      <a:access>
                                                        <a:owner>xqtest1</a:owner>
                                                        <a:group write="true">everyone</a:group>
                                                        <a:world read="true" write="true"/>
                                                      </a:access>
                                                      })""")
        .assertHttpNotFound
        .go
    }

    it("returns an error for no write access to the document") {
      xq("""lnk:put-access("nowriteaccess", document{
                                                    <a:access>
                                                      <a:owner>xqtest1</a:owner>
                                                      <a:group write="true">everyone</a:group>
                                                      <a:world read="true" write="true"/>
                                                    </a:access>
                                                      })""")
        .user("xqtest1")
        .assertHttpForbidden
        .go
    }

    it("returns an error for an invalid access structure") {
      xq("""lnk:put-access("existing", document{
          <a:access>
            <a:invalid/>
          </a:access>
        })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }

}
