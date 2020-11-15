package org.opensiddur.api.data

import org.opensiddur.DbTest

trait CommonTestTransliteration {
  val prolog =
    """xquery version '3.1';
      import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
       at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

      import module namespace tran="http://jewishliturgy.org/api/transliteration"
        at "xmldb:exist:///db/apps/opensiddur-server/api/data/transliteration.xqm";
      import module namespace data="http://jewishliturgy.org/modules/data"
        at "xmldb:exist:///db/apps/opensiddur-server/api/modules/data.xqm";
      import module namespace magic="http://jewishliturgy.org/magic"
        at "xmldb:exist:///db/apps/opensiddur-server/magic/magic.xqm";

      declare namespace html="http://www.w3.org/1999/xhtml";
      declare namespace tei="http://www.tei-c.org/ns/1.0";
      declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
      declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";
      declare namespace http="http://expath.org/ns/http-client";
      declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
      declare namespace a="http://jewishliturgy.org/ns/access/1.0";

      """
}

class TestTransliteration extends DbTest with CommonTestTransliteration {
  override def beforeAll()  {
    super.beforeAll()

    setupUsers(2)
    setupResource("src/test/resources/api/data/transliteration/Test.tr.xml", "Test", "transliteration", 1)
    setupResource("src/test/resources/api/data/transliteration/Test%202.tr.xml", "Test%202", "transliteration", 1)
    setupResource("src/test/resources/api/data/transliteration/Mivchan.tr.xml", "Mivchan", "transliteration", 1)
    setupResource("src/test/resources/api/data/transliteration/Garbage.tr.xml", "Garbage", "transliteration", 1)
    setupResource("src/test/resources/api/data/transliteration/NoWrite.tr.xml", "NoWrite", "transliteration", 2,
      None, Some("everyone"), Some("rw-r--r--"))
  }

  override def afterAll()  {
    // tear down users that were created by tests
    teardownResource("NoWrite", "transliteration", 2)
    teardownResource("Garbage", "transliteration", 1)
    teardownResource("Mivchan", "transliteration", 1)
    teardownResource("Test%202", "transliteration", 1)
    teardownResource("Test", "transliteration", 1)
    teardownUsers(2)

    super.afterAll()
  }

  override def beforeEach(): Unit = {
    super.beforeEach()
  }

  override def afterEach(): Unit = {
    super.afterEach()
  }

  describe("tran:get") {
    it("gets an existing resource (authenticated)") {
      xq("""tran:get("Test")""")
        .user("xqtest1")
        .assertXPath("""exists($output/tr:schema)""", "returns a transliteration schema")
        .go
    }

    it("gets an existing resource (unauthenticated)") {
      xq("""tran:get("Test")""")
        .assertXPath("""exists($output/tr:schema)""", "returns a transliteration schema")
        .go
    }
    
    it("fails to get a non-existing resource") {
      xq("""tran:get("DoesNotExist")""")
        .assertHttpNotFound
        .go
    }
  }
  
  describe("tran:list") {
    it("""list all resources""") {
      xq("""tran:list("", 1, 100)""")
        .assertSearchResults
        .assertXPath("""count($output//html:li[@class="result"])>=3""", "returns at least 3 results")
        .assertXPath("""
          every $li in $output//html:li[@class="result"]
          satisfies exists($li/html:a[@class="alt"][@property="access"])
        """, "results include a pointer to access API")
        .go
    }
    
    it("lists some resources") {
      xq("""tran:list("", 1, 2)""")
        .assertSearchResults
        .assertXPath("""count($output//html:li[@class="result"])=2""", "returns 2 results")
        .go
    }
    
    it("responds to a query") {
      xq("""tran:list("Test", 1, 100)""")
        .assertSearchResults
        .assertXPath("""count($output//html:ol[@class="results"]/html:li)=3""", "returns 3 results")
        .go
    }
  }
  
  describe("tran:post") {
    it("posts a valid transliteration") {
      val validData = readXmlFile("src/test/resources/api/data/transliteration/Valid.tr.xml")
      xq(s"""tran:post(document { $validData })""")
        .user("xqtest1")
        .assertHttpCreated
        .assertXPath("""exists($output/self::rest:response/http:response/http:header[@name="Location"])""",
        "A location header specifies where the document is stored")
        .assertXPath("""exists(data:doc("transliteration", "Valid"))""", 
          "A new document has been created at the location")
        .go
    }

    it("fails to post a valid transliteration unauthenticated") {
      val validData = readXmlFile("src/test/resources/api/data/transliteration/Valid.tr.xml")
      xq(s"""tran:post(document { $validData })""")
        .assertHttpUnauthorized
        .go
    }
    
    it("fails to post an invalid transliteration") {
      val invalidData = readXmlFile("src/test/resources/api/data/transliteration/Invalid.tr.xml")
      
      xq(s"""tran:post(document { $invalidData })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
    
    it("fails to post an invalid transliteration that is invalid because of the Schematron") {
      val invalidData = readXmlFile("src/test/resources/api/data/transliteration/InvalidSchema.tr.xml")

      xq(s"""tran:post(document { $invalidData })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }
  
  describe("tran:put") {
    val validData = readXmlFile("src/test/resources/api/data/transliteration/Valid.tr.xml")
    val invalidData = readXmlFile("src/test/resources/api/data/transliteration/Invalid.tr.xml")
    val invalidSchema = readXmlFile("src/test/resources/api/data/transliteration/InvalidSchema.tr.xml")
    it("succeeds in putting valid data to an existing resource") {
      
      xq(s"""tran:put("Garbage", document { $validData })""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath("""data:doc("transliteration", "Garbage")//tr:title="Valid"""", "document data has been changed")
        .go
    }

    it("fails to put valid data to an existing resource unauthenticated") {

      xq(s"""tran:put("Garbage", document { $validData })""")
        .assertHttpUnauthorized
        .go
    }
    
    it("fails to put data to a non-existing resource") {
      xq(s"""tran:put("DoesNotExist", document { $validData })""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
    
    it("fails to put invalid data to an existing resource") {
      xq(s"""tran:put("Garbage", document { $invalidData })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
    
    it("fails to put invalid data (by schematron) to an existing resource") {
      xq(s"""tran:put("Garbage", document { $invalidSchema })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
    
    it("fails to put valid data to an existing resource as an unauthorized user") {
      xq(s"""tran:put("Garbage", document { $validData })""")
        .user("xqtest2")
        .assertHttpForbidden
        .go

    }
  }
  
  describe("tran:get-access") {
    it("returns an access structure for an existing document") {
      xq("""tran:get-access("Garbage", ())""")
        .assertXPath("""exists($output/self::a:access)""")
        .go
    }
    
    it("fails to return an access structure for a nonexisting document") {
      xq("""tran:get-access("DoesNotExist", ())""")
        .assertHttpNotFound
        .go
    }
  }
  
  describe("tran:put-access") {
    it("sets access with a valid access structure, authenticated") {
      xq("""tran:put-access("Test", document{
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world write="true" read="true"/>
        </a:access>
      })""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }

    it("fails when the access structure is invalid") {
      xq("""tran:put-access("Test", document{
        <a:access>
          <a:invalid/>
        </a:access>
      })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

    it("fails when no write access") {
      xq("""tran:put-access("NoWrite", document{
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world write="true" read="true"/>
        </a:access>
      })""")
        .user("xqtest1")
        .assertHttpForbidden
        .go
    }

    it("fails for a nonexistent resource") {
      xq("""tran:put-access("DoesNotExist", document{
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world write="true" read="true"/>
        </a:access>
      })""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("fails to change access unauthenticated") {
      xq("""tran:put-access("Garbage", document{
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="false">everyone</a:group>
          <a:world read="false" write="false"/>
        </a:access>
        })""")
        .assertHttpUnauthorized
        .go
    }
  }
}

class TestTransliterationDelete extends DbTest with CommonTestTransliteration {

  override def beforeEach(): Unit = {
    super.beforeEach()

    setupUsers(2)
    setupResource("src/test/resources/api/data/transliteration/Garbage.tr.xml", "Garbage", "transliteration", 1, None,
      Some("everyone"), Some("rw-r--r--"))
  }

  override def afterEach(): Unit = {
    super.afterEach()

    teardownResource("Garbage", "transliteration", 1)
    teardownUsers(2)
  }

  describe("tran:delete") {
    it("deletes a transliteration that exists") {
      xq("""tran:delete("Garbage")""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath("""not(doc-available("/data/transliteration/Garbage.xml"))""", "data is removed")
        .go
    }

    it("fails to delete a transliteration that exists (unauthenticated)") {
      xq("""tran:delete("Garbage")""")
        .assertHttpUnauthorized
        .go
    }
    
    it("fails to delete a transliteration that does not exist") {
      xq("""tran:delete("NotExist")""")
        .assertHttpNotFound
        .go
    }
    
    it("fails to delete where no write access is granted") {
      xq("""tran:delete("Garbage")""")
        .user("xqtest2")
        .assertHttpForbidden
        .go
    }
    
    ignore("fails to delete a transliteration with an external reference") {
      xq("""tran:delete("ExternalReference")""")
        .assertHttpBadRequest
        .go
    }
  }
}