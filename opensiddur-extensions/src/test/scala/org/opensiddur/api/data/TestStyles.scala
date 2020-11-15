package org.opensiddur.api.data

import org.opensiddur.DbTest

trait CommonTestStyles {
  val prolog =
    """xquery version '3.1';
      import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
       at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

      import module namespace sty="http://jewishliturgy.org/api/data/styles"
        at "xmldb:exist:///db/apps/opensiddur-server/api/data/styles.xqm";
      import module namespace magic="http://jewishliturgy.org/magic"
        at "xmldb:exist:///db/apps/opensiddur-server/magic/magic.xqm";
        
      declare namespace html="http://www.w3.org/1999/xhtml";
      declare namespace tei="http://www.tei-c.org/ns/1.0";
      declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
      declare namespace http="http://expath.org/ns/http-client";
      declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
      declare namespace a="http://jewishliturgy.org/ns/access/1.0";

      """
}

class TestStyles extends DbTest with CommonTestStyles {
  override def beforeAll()  {
    super.beforeAll()

    setupUsers(2)
    setupResource("src/test/resources/api/data/styles/Existing.xml", "Existing", "styles", 1)
    setupResource("src/test/resources/api/data/styles/Existing.xml", "NoAccess", "styles", 2, 
      None, Some("everyone"), Some("rw-------"))
    setupResource("src/test/resources/api/data/styles/NoWriteAccess.xml", "NoWriteAccess", "styles", 2,
      None, Some("everyone"), Some("rw-r--r--"))
    
  }

  override def afterAll()  {
    // tear down users that were created by tests
    teardownResource("NoWriteAccess", "styles", 2)
    teardownResource("NoAccess", "styles", 2)
    teardownResource("Existing", "styles", 1)
    teardownResource("Valid", "styles", 1)
    teardownUsers(2)

    super.afterAll()
  }

  override def beforeEach(): Unit = {
    super.beforeEach()
  }

  override def afterEach(): Unit = {
    super.afterEach()
  }

  describe("sty:get-xml") {
    it("gets an existing resource") {
      xq("""sty:get-xml("Existing")""")
        .assertXPath("""exists($output/tei:TEI)""", "Returns a TEI resource")
        .go
    }
    
    it("fails to get a nonexisting resource") {
      xq("""sty:get-xml("DoesNotExist")""")
        .assertHttpNotFound
        .go
    }
    
    it("fails to get a resource with no read access") {
      xq("""sty:get-xml("NoAccess")""")
        .assertHttpNotFound
        .go
    }
  }  
  
  describe("sty:get-css") {
    it("gets an existing resource") {
      xq("""sty:get-css("Existing")""")
        .assertXPath("""$output instance of xs:string and contains($output, ".tei-seg")""", 
        "Returns a string containing the CSS")
        .go
    }
    
    it("fails to get a nonexisting resource") {
      xq("""sty:get-css("DoesNotExist")""")
        .assertHttpNotFound
        .go
    }
    
    it("fails to get a resource with no read access") {
      xq("""sty:get-css("NoAccess")""")
        .assertHttpNotFound
        .go
    }
  }
  
  describe("sty:list") {
    it("lists all resources") {
      xq("""sty:list("", 1, 100)""")
        .user("xqtest1")
        .assertSearchResults
        .assertXPath("""count($output//html:li[@class="result"])>=1""", "returns at least 1 result")
        .assertXPath("""
          every $li in $output//html:li[@class="result"]
          satisfies exists($li/html:a[@class="alt"][@property="access"])
        """, "results include a pointer to access API")
        .go
    }

    it("does not list resources with no access when unauthenticated") {
      xq("""sty:list("", 1, 100)""")
        .assertSearchResults
        .assertXPath("""count($output//html:li[@class="result"])>=1""", "returns at least 1 result")
        .assertXPath("""empty($output//html:li[@class="result"]/html:a[@class="document"]/@href[contains(., "NoAccess")])""", 
          "does not list resource with no read access")
        .go
    }
    
    it("lists some resources") {
      xq("""sty:list("", 1, 2)""")
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"])=2""", "returns 2 results")
        .assertSearchResults
        .go
    }
    
    it("responds to a query") {
      xq("""sty:list("Query", 1, 100)""")
        .assertXPath("""count($output//html:ol[@class="results"]/html:li)=1""", "returns 1 results")
        .assertSearchResults
        .go
    }
  }
  
  describe("sty:post") {
    val validDoc = readXmlFile("src/test/resources/api/data/styles/Valid.xml")
    it("posts a valid resource") {
      xq(s"""sty:post(document { $validDoc })""")
        .user("xqtest1")
        .assertHttpCreated
        // does styles have language?
        .assertXPath(
          """collection('/db/data/styles')[util:document-name(.)=tokenize($output//http:header[@name='Location']/@value,'/')[last()] || '.xml']//
            tei:revisionDesc/tei:change[1][@type="created"][@who="/user/xqtest1"][@when]""", 
        "a change record has been added")
        .go
    }
    
    it("fails to post a valid resource unauthenticated") {
      xq(s"""sty:post(document { $validDoc })""")
        .assertHttpUnauthorized
        .go
    }
    
    it("fails to post an invalid resource") {
      val invalidDoc = readXmlFile("src/test/resources/api/data/styles/Invalid.xml")
      
      xq(s"""sty:post(document { $invalidDoc })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }
  
  describe("sty:put-xml") {
    val validDoc = readXmlFile("src/test/resources/api/data/styles/Existing-After-Put.xml")
    it("puts a valid resource to an existing resource") {
      xq(s"""sty:put-xml("Existing", document { $validDoc })""")
        .user("xqtest1")
        .assertHttpNoData
        // en?
        .assertXPath(
          """(collection('/db/data/styles')[util:document-name(.)='Existing.xml']//tei:revisionDesc/tei:change)[1]
            [@type="edited"][@who="/user/xqtest1"][@when]""", "a change record has been added")
        .go
    }
    
    it("fails to put a resource when unauthenticated") {
        xq(s"""sty:put-xml("Existing", document { $validDoc })""")
          .assertHttpUnauthorized
          .go
    }
    
    it("fails to put a valid resource to a nonexisting resource") {
      val validDoc = readXmlFile("src/test/resources/api/data/styles/Valid.xml")
      xq(s"""sty:put-xml("DoesNotExist", document { $validDoc })""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
    
    it("fails to put an invalid resource") {
      val invalidDoc = readXmlFile("src/test/resources/api/data/styles/Invalid.xml")
      xq(s"""sty:put-xml("Existing", document { $invalidDoc })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }
  
  describe("sty:put-css") {
    val validDoc = readXmlFile("src/test/resources/api/data/styles/Valid.xml")
  
    it("puts a valid resource to an existing resource") {
      xq(
        """sty:put-css("Existing", ".tei-div {display: none;}")""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath("""contains(
          (collection('/db/data/styles')
          [util:document-name(.)='Existing.xml']//j:stylesheet[@scheme="css"])[1],
          ".tei-div")""", "j:stylesheet content changed")
        .assertXPath(
          """(collection('/db/data/styles')[util:document-name(.)='Existing.xml']//tei:revisionDesc/tei:change)[1]
            [@type="edited"][@who="/user/xqtest1"][@when]""", "a change record has been added")
        .go
    }

    it("fails to put a valid resource to an existing resource when unauthenticated") {
      xq(
        """sty:put-css("Existing", ".tei-div {display: none;}")""")
        .assertHttpUnauthorized
        .go
    }

    it("fails to put a valid resource to a nonexisting resource") {
      xq("""sty:put-css("DoesNotExist", ".tei-div {display:none;}")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
    
    ignore("it fails to put an invalid resource") {
      xq("""sty:put-css("Existing", "xxxx")""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }
    
  describe("sty:get-access") {
    it("returns an access structure on an existing document") {
      xq("""sty:get-access("Existing", ())""")
        .assertXPath("""exists($output/self::a:access)""", "an access structure is returned")
        .go
    }

    it("fails to return an access structure for a nonexistent resource") {
      xq("""sty:get-access("DoesNotExist", ())""")
        .assertHttpNotFound
        .go
    }
  }
  
  describe("sty:put-access") {
    it("puts a valid access structure") {
      xq("""sty:put-access("Existing", document{
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="false">everyone</a:group>
          <a:world read="true" write="false"/>
        </a:access>
        })""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }

    it("fails to put unauthenticated") {
      xq("""sty:put-access("Existing", document{
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="false">everyone</a:group>
          <a:world read="false" write="false"/>
        </a:access>
        })""")
        .assertHttpUnauthorized
        .go
    }

    it("fails to put an invalid access structure") {
      xq("""sty:put-access("Existing", document{
        <a:access>
          <a:invalid/>
        </a:access>
        })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

    it("fails to put for a resource with no write access") {
      xq("""sty:put-access("NoWriteAccess", document{
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="false">everyone</a:group>
          <a:world read="false" write="false"/>
        </a:access>
        })""")
        .user("xqtest1")
        .assertHttpForbidden
        .go
    }

    it("fails to put for a nonexistent resource") {
      xq("""sty:put-access("DoesNotExist", document{
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="false">everyone</a:group>
          <a:world read="false" write="false"/>
        </a:access>
        })""")
        .assertHttpNotFound
        .go
    }
  }
}

class TestStylesDelete extends DbTest with CommonTestStyles {

  override def beforeEach(): Unit = {
    super.beforeEach()

    setupUsers(2)
    setupResource("src/test/resources/api/data/styles/Existing.xml", "Existing", "styles", 1)
    setupResource("src/test/resources/api/data/styles/NoWriteAccess.xml", "NoWriteAccess", "styles", 2,
      None, Some("everyone"), Some("rw-r--r--"))
  }

  override def afterEach(): Unit = {
    super.afterEach()

    teardownResource("Existing", "styles", 1)
    teardownResource("NoWriteAccess", "styles", 2)
    teardownUsers(2)
  }

  describe("sty:delete") {
    it("removes an existing resource") {
      xq("""sty:delete("Existing")""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }
    
    it("does not remove an existing resource when unauthenticated") {
      xq("""sty:delete("Existing")""")
        .assertHttpUnauthorized
        .go
    }

    it("fails to remove a nonexisting resource") {
      xq("""sty:delete("DoesNotExist")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("fails to remove a resource without write access") {
      xq("""sty:delete("NoWriteAccess")""")
        .user("xqtest1")
        .assertHttpForbidden
        .go
    }
  }
}