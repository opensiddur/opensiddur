package org.opensiddur.api.data

import org.opensiddur.DbTest

trait CommonTestSources {
  val prolog =
    """xquery version '3.1';
      import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
       at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

      import module namespace src="http://jewishliturgy.org/api/data/sources"
        at "xmldb:exist:///db/apps/opensiddur-server/api/data/sources.xqm";
      import module namespace magic="http://jewishliturgy.org/magic"
        at "xmldb:exist:///db/apps/opensiddur-server/magic/magic.xqm";
        
      declare namespace html="http://www.w3.org/1999/xhtml";
      declare namespace tei="http://www.tei-c.org/ns/1.0";
      declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
      declare namespace http="http://expath.org/ns/http-client";
      declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
      """
}

class TestSources extends DbTest with CommonTestSources {
  override def beforeAll()  {
    super.beforeAll()

    setupUsers(2)
    setupResource("src/test/resources/api/data/sources/Existing.xml", "Existing", "sources", 1)
    setupResource("src/test/resources/api/data/sources/Existing.xml", "NoAccess", "sources", 2,
      None, Some("everyone"), Some("rw-------"))
    setupResource("src/test/resources/api/data/sources/Existing.xml", "NoWriteAccess", "sources", 2,
      None, Some("everyone"), Some("rw-r--r--"))
    setupResource("src/test/resources/api/data/sources/TestBibliography.xml", "TestBibliography", "sources", 1)
    setupResource("src/test/resources/api/data/sources/TestDocument1.xml", "TestDocument1", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/sources/TestDocument2.xml", "TestDocument2", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/sources/TestDocument3.xml", "TestDocument3", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/sources/TestDocument4.xml", "TestDocument4", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/sources/TestDocument5.xml", "TestDocument5", "original", 1, Some("en"))

  }

  override def afterAll()  {
    teardownResource("TestDocument5", "original", 1)
    teardownResource("TestDocument4", "original", 1)
    teardownResource("TestDocument3", "original", 1)
    teardownResource("TestDocument2", "original", 1)
    teardownResource("TestDocument1", "original", 1)
    teardownResource("TestBibliography", "sources", 1)
    teardownResource("NoWriteAccess", "sources", 2)
    teardownResource("NoAccess", "sources", 2)
    teardownResource("Existing", "sources", 1)
    teardownResource("Valid", "sources", 1)
    teardownUsers(2)

    super.afterAll()
  }

  override def beforeEach(): Unit = {
    super.beforeEach()
  }

  override def afterEach(): Unit = {
    super.afterEach()
  }

  describe("src:get") {
    it("gets an existing resource") {
      xq("""src:get("Existing")""")
        .assertXPath("""exists($output/tei:biblStruct)""", "Returns a TEI resource")
        .go
    }
    
    it("fails to get a nonexisting resource") {
      xq("""src:get("DoesNotExist")""")
        .assertHttpNotFound
        .go
    }
    
    it("fails to get a resource with no read access") {
      xq("""src:get("NoAccess")""")
        .assertHttpNotFound
        .go
    }
  }  

  describe("src:list") {
    it("lists all resources") {
      xq("""src:list("", 1, 100)""")
        .user("xqtest1")
        .assertSearchResults
        .assertXPath("""count($output//html:li[@class="result"])>=1""", "returns at least 1 result")
        .go
    }

    it("does not list resources with no access when unauthenticated") {
      xq("""src:list("", 1, 100)""")
        .assertSearchResults
        .assertXPath("""count($output//html:li[@class="result"])>=1""", "returns at least 1 result")
        .assertXPath("""empty($output//html:li[@class="result"]/html:a[@class="document"]/@href[contains(., "NoAccess")])""", 
          "does not list resource with no read access")
        .go
    }
    
    it("lists some resources") {
      xq("""src:list("", 1, 2)""")
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"])=2""", "returns 2 results")
        .assertSearchResults
        .go
    }
    
    it("responds to a query") {
      xq("""src:list("Existing", 1, 100)""")
        .assertXPath("""count($output//html:ol[@class="results"]/html:li)=2""", "returns 2 results (Existing and NoWriteAccess)")
        .assertSearchResults
        .go
    }
  }
  
  describe("src:post") {
    val validDoc = readXmlFile("src/test/resources/api/data/sources/Valid.xml")
    it("posts a valid resource") {
      xq(s"""src:post(document { $validDoc })""")
        .user("xqtest1")
        .assertHttpCreated
        .go
    }
    
    it("fails to post a valid resource unauthenticated") {
      xq(s"""src:post(document { $validDoc })""")
        .assertHttpUnauthorized
        .go
    }
    
    it("fails to post an invalid resource") {
      xq(s"""src:post(document { <tei:biblStruct><tei:title>invalid</tei:title></tei:biblStruct> })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }
  
  describe("src:put") {
    val validDoc = readXmlFile("src/test/resources/api/data/sources/Existing-After-Put.xml")
    it("puts a valid resource to an existing resource") {
      xq(s"""src:put("Existing", document { $validDoc })""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath(
          """collection('/data/sources')[descendant::tei:title[.='Existing']]//tei:date/@when=1920""", "new document has been saved")
        .go
    }
    
    it("fails to put a resource when unauthenticated") {
        xq(s"""src:put("Existing", document { $validDoc })""")
          .assertHttpUnauthorized
          .go
    }
    
    it("fails to put a valid resource to a nonexisting resource") {
      val validDoc = readXmlFile("src/test/resources/api/data/styles/Valid.xml")
      xq(s"""src:put("DoesNotExist", document { $validDoc })""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
    
    it("fails to put an invalid resource") {
      xq(s"""src:put("Existing", document { <tei:biblStruct><tei:title>invalid</tei:title></tei:biblStruct> })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }

  describe("src:pages") {
    it("fails when the resource does not exist") {
      xq("""src:pages("DoesNotExist")""")
        .assertHttpNotFound
        .go
    }
    
    it("returns an empty list when there are no pages to return") {
      xq("""src:pages("Existing")""")
        .assertXPath("""exists($output/self::html:html)""", "html is returned")
        .assertXPath("""exists($output//html:ol[@class="results"]) and empty($output//html:ol[@class="results"]/*)""", "an empty list is returned")
        .go
    }
    
    it("lists pages when there are results") {
      xq("""src:pages("TestBibliography")""")
        .assertXPath("""count($output//html:ol[@class="results"]/html:li[@class="result"]) > 0""", "some results are returned")
        .assertXPath("""
          let $pages :=
            for $p in $output//html:ol[@class="results"]/html:li[@class="result"]/html:span[@class="page"] return xs:integer($p)
          return every $pg in (1 to 7) satisfies $pg=$pages
          """, "all pages are represented by a list element")
        .assertXPath("""count($output//html:ol[@class="results"]/html:li[@class="result"][not(html:span[@class="page"])])=1""", "results without pages are represented by a list element")
        .assertXPath(
          """every $li in $output//html:ol[@class="results"]/html:li[html:span[@class="page"]][position() >= 2]
            satisfies $li/html:span[@class="page"]/number() >= $li/preceding-sibling::html:li[1]/html:span[@class="page"]/number() """, "pages (where they exist) are ordered")
        .assertXPath("""exists($output//html:ol[@class="results"]/html:li[@class="result"][html:span[@class="page"]=1][ends-with(html:a/@href, "TestDocument1")])""", "TestDocument1 is represented as page 1")
        .assertXPath(""" 
          every $v in (for $pg at $n in $output//html:ol[@class="results"]/html:li[@class="result"][ends-with(html:a/@href, "TestDocument2")]/html:span/@page/number()
          return $pg=(2 to 6)[$n]) satisfies $v
          """, "TestDocument2 is represented as pages 2-6")
        .assertXPath(""" 
          every $v in (for $pg at $n in $output//html:ol[@class="results"]/html:li[@class="result"][ends-with(html:a/@href, "TestDocument3")]/html:span/@page/number()
          return $pg=(4 to 5)[$n]) satisfies $v
          """, "TestDocument3 is represented as pages 4-5 (overlap is allowed)")
        .assertXPath("""
          every $v in (for $pg at $n in $output//html:ol[@class="results"]/html:li[@class="result"][ends-with(html:a/@href, "TestDocument4")]/html:span/@page/number()
          return $pg=7) satisfies $v
          """, "TestDocument4 is represented as page 7")
        .assertXPath("""every $v in (for $status at $n in $output//html:ol[@class="results"]/html:li[@class="result"][ends-with(html:a/@href, "TestDocument4")]/html:ul[@class="statuses"]/html:li[@class="status"]/string() return $status=("proofread-once", "transcribed")[$n]) satisfies $v
          """, "TestDocument4 has its status represented")
        .assertXPath("""exists($output//html:ol[@class="results"]/html:li[@class="result"][ends-with(html:a/@href, "TestDocument5")][not(html:span[@class="page"])])""", "TestDocument5 (no page) is represented with no page span")
        .go
      
    }
  }

}

class TestSourcesDelete extends DbTest with CommonTestSources {

  override def beforeEach(): Unit = {
    super.beforeEach()

    setupUsers(2)
    setupResource("src/test/resources/api/data/sources/Existing.xml", "Existing", "sources", 1)
    setupResource("src/test/resources/api/data/sources/Existing.xml", "NoWriteAccess", "sources", 2,
      None, Some("everyone"), Some("rw-r--r--"))
  }

  override def afterEach(): Unit = {
    super.afterEach()

    teardownResource("Existing", "sources", 1)
    teardownResource("NoWriteAccess", "sources", 2)
    teardownUsers(2)
  }

  describe("src:delete") {
    it("removes an existing resource") {
      xq("""src:delete("Existing")""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }
    
    it("does not remove an existing resource when unauthenticated") {
      xq("""src:delete("Existing")""")
        .assertHttpUnauthorized
        .go
    }

    it("fails to remove a nonexisting resource") {
      xq("""src:delete("DoesNotExist")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("fails to remove a resource without write access") {
      xq("""src:delete("NoWriteAccess")""")
        .user("xqtest1")
        .assertHttpForbidden
        .go
    }
  }
}