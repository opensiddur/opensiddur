package org.opensiddur.api.data

import org.opensiddur.DbTest

trait CommonTestConditionals {
  val prolog =
    """xquery version '3.1';
      import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
       at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

      import module namespace cnd="http://jewishliturgy.org/api/data/conditionals"
        at "xmldb:exist:///db/apps/opensiddur-server/api/data/conditionals.xqm";
      import module namespace magic="http://jewishliturgy.org/magic"
        at "xmldb:exist:///db/apps/opensiddur-server/magic/magic.xqm";
                
      declare namespace html="http://www.w3.org/1999/xhtml";
      declare namespace tei="http://www.tei-c.org/ns/1.0";
      declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
      declare namespace http="http://expath.org/ns/http-client";
      declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
      declare namespace a="http://jewishliturgy.org/ns/access/1.0";
      declare namespace r="http://jewishliturgy.org/ns/results/1.0";
      """
}

class TestConditionals extends DbTest with CommonTestConditionals {
  override def beforeAll()  {
    super.beforeAll()

    setupUsers(2)
    setupResource("src/test/resources/api/data/conditionals/existing.xml", "existing", "conditionals", 1)
    setupResource("src/test/resources/api/data/conditionals/existing.xml", "no_access", "conditionals",  2,
      None, Some("everyone"), Some("rw-------"))
    setupResource("src/test/resources/api/data/conditionals/type1.xml", "type1", "conditionals", 1)
    setupResource("src/test/resources/api/data/conditionals/type2.xml", "type2", "conditionals", 1)
    setupResource("src/test/resources/api/data/conditionals/xtype1x.xml", "xtype1x", "conditionals", 1)
  }

  override def afterAll()  {
    teardownResource("type1", "conditionals", 1)
    teardownResource("type2", "conditionals", 1)
    teardownResource("xtype1x", "conditionals", 1)
    teardownResource("no_access", "conditionals", 2)
    teardownResource("existing", "conditionals", 1)
    teardownResource("valid", "conditionals", 1)
    teardownUsers(2)

    super.afterAll()
  }

  override def beforeEach(): Unit = {
    super.beforeEach()
  }

  override def afterEach(): Unit = {
    super.afterEach()
  }

  describe("cnd:get") {
    it("gets an existing resource") {
      xq("""cnd:get("existing")""")
        .assertXPath("""exists($output/tei:TEI)""", "Returns a TEI resource")
        .go
    }
    
    it("fails to get a nonexisting resource") {
      xq("""cnd:get("does_not_exist")""")
        .assertHttpNotFound
        .go
    }
    
    it("fails to get a resource with no read access") {
      xq("""cnd:get("no_access")""")
        .assertHttpNotFound
        .go
    }
  }  

  describe("cnd:list") {
    it("lists all resources") {
      xq("""cnd:list("", 1, 100)""")
        .user("xqtest1")
        .assertSearchResults
        .assertXPath("""count($output//html:li[@class="result"])>=1""", "returns at least 1 result")
        .assertXPath("""
          exists($output//html:li[@class="result"]) and (
          every $li in $output//html:li[@class="result"]
          satisfies empty($li/html:a[@class="alt"][@property="access"])
        )
        """, "results do not include a pointer to access API")
        .go
    }

    it("does not list resources with no access when unauthenticated") {
      xq("""cnd:list("", 1, 100)""")
        .assertSearchResults
        .assertXPath("""count($output//html:li[@class="result"])>=1""", "returns at least 1 result")
        .assertXPath("""empty($output//html:li[@class="result"]/html:a[@class="document"]/@href[contains(., "no_access")])""",
          "does not list resource with no read access")
        .go
    }
    
    it("lists some resources") {
      xq("""cnd:list("", 1, 2)""")
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"])=2""", "returns 2 results")
        .assertSearchResults
        .go
    }
    
    it("responds to a query") {
      xq("""cnd:list("query", 1, 100)""")
        .assertXPath("""count($output//html:ol[@class="results"]/html:li)=1""",
          "returns 1 result (existing)")
        .assertSearchResults
        .go
    }

    it("searches for a feature type") {
      xq("""cnd:list("type1", 1, 100, "true")""")
        .assertXPathEquals("$output/self::r:conditional-results",
          "two records are returned",
        """<r:conditional-results start="1" end="2" n-results="2">
          <r:conditional-result resource="/api/data/conditionals/type1" match="type">
            <tei:fsDecl type="type1">
              <tei:fsDescr>first type</tei:fsDescr>
              <tei:fDecl name="name1">
                <tei:fDescr>First</tei:fDescr>
                <j:vSwitch type="yes-no-maybe"/>
              </tei:fDecl>
              <tei:fDecl name="name2">
                <tei:fDescr>Second</tei:fDescr>
                <j:vSwitch type="yes-no-maybe"/>
              </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
          <r:conditional-result resource="/api/data/conditionals/xtype1x" match="type">
            <tei:fsDecl type="xtype1x">
               <tei:fsDescr>first type</tei:fsDescr>
               <tei:fDecl name="xname1x">
                  <tei:fDescr>First X</tei:fDescr>
                  <j:vSwitch type="yes-no-maybe"/>
               </tei:fDecl>
               <tei:fDecl name="xname2x">
                  <tei:fDescr>Second X</tei:fDescr>
                  <j:vSwitch type="yes-no-maybe"/>
              </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
        </r:conditional-results>""")
        .go
    }

    it("fails to return results when searching for something that does not exist") {
      xq("""cnd:list("doesnotexist", 1, 100, "true")""")
        .assertXPath("""$output/self::r:conditional-results[@start='1'][@end='0'][@n-results='0']""",
          "an empty list is returned")
        .go
    }

    it("returns a list of matched names when the name exists") {
      xq("""cnd:list("name1", 1, 100, "true")""")
        .assertXPathEquals("$output/self::r:conditional-results",
        "two records are returned",
        """<r:conditional-results start="1" end="3" n-results="3" >
          <r:conditional-result resource="/api/data/conditionals/type1" match="feature">
            <tei:fsDecl type="type1">
              <tei:fsDescr>first type</tei:fsDescr>
              <tei:fDecl name="name1">
                <tei:fDescr>First</tei:fDescr>
                <j:vSwitch xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" type="yes-no-maybe"/>
              </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
          <r:conditional-result resource="/api/data/conditionals/type2" match="feature">
            <tei:fsDecl type="type2">
              <tei:fsDescr>second type</tei:fsDescr>
              <tei:fDecl name="name1">
                <tei:fDescr>First of second</tei:fDescr>
                <j:vSwitch xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" type="yes-no-maybe"/>
              </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
          <r:conditional-result resource="/api/data/conditionals/xtype1x" match="feature">
            <tei:fsDecl type="xtype1x">
               <tei:fsDescr>first type</tei:fsDescr>
               <tei:fDecl name="xname1x">
                  <tei:fDescr>First X</tei:fDescr>
                  <j:vSwitch type="yes-no-maybe"/>
               </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
        </r:conditional-results>""")
        .go
    }

    it("returns a list by match to feature name where the name exists, limit to 1 result") {
      xq("""cnd:list("name1", 1, 1, "true")""")
        .assertXPathEquals("$output/self::r:conditional-results",
        "one record is returned",
        """<r:conditional-results start="1" end="1" n-results="3">
          <r:conditional-result resource="/api/data/conditionals/type1" match="feature">
            <tei:fsDecl type="type1">
              <tei:fsDescr>first type</tei:fsDescr>
              <tei:fDecl name="name1">
                <tei:fDescr>First</tei:fDescr>
                <j:vSwitch type="yes-no-maybe"/>
              </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
        </r:conditional-results>""")
        .go
    }

    it("returns a list by inexact match to feature type where the type exists") {
      xq("""cnd:list("type", 1, 100, "true")""")
        .assertXPathEquals("$output/self::r:conditional-results",
        "two records are returned",
        """<r:conditional-results start="1" end="3" n-results="3">
          <r:conditional-result resource="/api/data/conditionals/type1" match="type">
            <tei:fsDecl type="type1">
              <tei:fsDescr>first type</tei:fsDescr>
              <tei:fDecl name="name1">
                <tei:fDescr>First</tei:fDescr>
                <j:vSwitch type="yes-no-maybe"/>
              </tei:fDecl>
              <tei:fDecl name="name2">
                <tei:fDescr>Second</tei:fDescr>
                <j:vSwitch type="yes-no-maybe"/>
              </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
          <r:conditional-result resource="/api/data/conditionals/type2" match="type">
            <tei:fsDecl type="type2">
               <tei:fsDescr>second type</tei:fsDescr>
               <tei:fDecl name="name1">
                  <tei:fDescr>First of second</tei:fDescr>
                  <j:vSwitch xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" type="yes-no-maybe"/>
               </tei:fDecl>
               <tei:fDecl name="name2">
                  <tei:fDescr>Second of second</tei:fDescr>
                  <j:vSwitch xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" type="yes-no-maybe"/>
              </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
          <r:conditional-result resource="/api/data/conditionals/xtype1x" match="type">
            <tei:fsDecl type="xtype1x">
               <tei:fsDescr>first type</tei:fsDescr>
               <tei:fDecl name="xname1x">
                  <tei:fDescr>First X</tei:fDescr>
                  <j:vSwitch type="yes-no-maybe"/>
               </tei:fDecl>
               <tei:fDecl name="xname2x">
                  <tei:fDescr>Second X</tei:fDescr>
                  <j:vSwitch type="yes-no-maybe"/>
              </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
        </r:conditional-results>""")
        .go
    }

    it("returns a list by inexact match to feature name where the name exists") {
      xq("""cnd:list("name1", 1, 100, "true")""")
        .assertXPathEquals("$output/self::r:conditional-results",
        "three records are returned",
        """<r:conditional-results start="1" end="3" n-results="3">
          <r:conditional-result resource="/api/data/conditionals/type1" match="feature">
            <tei:fsDecl type="type1">
              <tei:fsDescr>first type</tei:fsDescr>
              <tei:fDecl name="name1">
                <tei:fDescr>First</tei:fDescr>
                <j:vSwitch xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" type="yes-no-maybe"/>
              </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
          <r:conditional-result resource="/api/data/conditionals/type2" match="feature">
            <tei:fsDecl type="type2">
              <tei:fsDescr>second type</tei:fsDescr>
              <tei:fDecl name="name1">
                <tei:fDescr>First of second</tei:fDescr>
                <j:vSwitch xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" type="yes-no-maybe"/>
              </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
          <r:conditional-result resource="/api/data/conditionals/xtype1x" match="feature">
            <tei:fsDecl type="xtype1x">
               <tei:fsDescr>first type</tei:fsDescr>
               <tei:fDecl name="xname1x">
                  <tei:fDescr>First X</tei:fDescr>
                  <j:vSwitch type="yes-no-maybe"/>
               </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
        </r:conditional-results>""")
        .go
    }

    it("returns a list by exact match feature type and name, where both exist") {
      xq("""cnd:list("type1 name1", 1, 100, "true")""")
        .assertXPathEquals("$output/self::r:conditional-results",
        "records that match any of the terms are returned",
        """<r:conditional-results start="1" end="5" n-results="5">
          <r:conditional-result resource="/api/data/conditionals/type1" match="type">
            <tei:fsDecl type="type1">
              <tei:fsDescr>first type</tei:fsDescr>
              <tei:fDecl name="name1">
                <tei:fDescr>First</tei:fDescr>
                <j:vSwitch type="yes-no-maybe"/>
              </tei:fDecl>
              <tei:fDecl name="name2">
                <tei:fDescr>Second</tei:fDescr>
                <j:vSwitch type="yes-no-maybe"/>
              </tei:fDecl>
            </tei:fsDecl>
         </r:conditional-result>
          <r:conditional-result resource="/api/data/conditionals/type1" match="feature">
            <tei:fsDecl type="type1">
              <tei:fsDescr>first type</tei:fsDescr>
              <tei:fDecl name="name1">
                <tei:fDescr>First</tei:fDescr>
                <j:vSwitch xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" type="yes-no-maybe"/>
              </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
          <r:conditional-result resource="/api/data/conditionals/type2" match="feature">
            <tei:fsDecl type="type2">
               <tei:fsDescr>second type</tei:fsDescr>
               <tei:fDecl name="name1">
                  <tei:fDescr>First of second</tei:fDescr>
                  <j:vSwitch xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" type="yes-no-maybe"/>
               </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
          <r:conditional-result resource="/api/data/conditionals/xtype1x" match="type">
            <tei:fsDecl type="xtype1x">
               <tei:fsDescr>first type</tei:fsDescr>
               <tei:fDecl name="xname1x">
                  <tei:fDescr>First X</tei:fDescr>
                  <j:vSwitch type="yes-no-maybe"/>
               </tei:fDecl>
               <tei:fDecl name="xname2x">
                  <tei:fDescr>Second X</tei:fDescr>
                  <j:vSwitch type="yes-no-maybe"/>
              </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
          <r:conditional-result resource="/api/data/conditionals/xtype1x" match="feature">
            <tei:fsDecl type="xtype1x">
               <tei:fsDescr>first type</tei:fsDescr>
               <tei:fDecl name="xname1x">
                  <tei:fDescr>First X</tei:fDescr>
                  <j:vSwitch type="yes-no-maybe"/>
               </tei:fDecl>
            </tei:fsDecl>
          </r:conditional-result>
        </r:conditional-results>""")
        .go
    }

    it("returns a list by exact match to feature type where the type exists") {
      xq("""cnd:list("type1", 1, 100, "false", "true")""")
        .assertXPathEquals("$output/self::r:conditional-results",
        "one record is returned",
        """<r:conditional-results start="1" end="1" n-results="1">
                  <r:conditional-result resource="/api/data/conditionals/type1" match="type">
                      <tei:fsDecl type="type1">
                          <tei:fsDescr>first type</tei:fsDescr>
                          <tei:fDecl name="name1">
                              <tei:fDescr>First</tei:fDescr>
                              <j:vSwitch type="yes-no-maybe"/>
                          </tei:fDecl>
                          <tei:fDecl name="name2">
                              <tei:fDescr>Second</tei:fDescr>
                              <j:vSwitch type="yes-no-maybe"/>
                          </tei:fDecl>
                      </tei:fsDecl>
                  </r:conditional-result>
              </r:conditional-results>""")
        .go
    }

    it("returns an empty list by exact match to feature type, where the type does not exist") {
      xq("""cnd:list("typenotexists", 1, 100, "false", "true")""")
        .assertXPathEquals("$output/self::r:conditional-results", "no records are returned",
        """<r:conditional-results start="1" end="0" n-results="0"/>""")
        .go
    }
  }
  
  describe("cnd:post") {
    val validDoc = readXmlFile("src/test/resources/api/data/conditionals/valid.xml")
    val invalidDoc = readXmlFile("src/test/resources/api/data/conditionals/invalid.xml")
    it("posts a valid resource") {
      xq(s"""cnd:post(document { $validDoc })""")
        .user("xqtest1")
        .assertHttpCreated
        .assertXPathEquals("collection('/db/data/conditionals')[util:document-name(.)=tokenize($output//http:header[@name='Location']/@value,'/')[last()] || '.xml']//tei:revisionDesc/tei:change[1]",
          "a change record has been added",
          """<tei:change xmlns:tei="http://www.tei-c.org/ns/1.0" type="created" who="/user/xqtest1"
                        when="..."/>"""
        )
        .go
    }
    
    it("fails to post a valid resource unauthenticated") {
      xq(s"""cnd:post(document { $validDoc })""")
        .assertHttpUnauthorized
        .go
    }
    
    it("fails to post an invalid resource") {
      xq(s"""cnd:post(document { $invalidDoc })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }

  describe("cnd:put") {
    
    it("puts a valid resource to an existing resource") {
      val validDoc = readXmlFile("src/test/resources/api/data/conditionals/existing_after_put.xml")
      xq(s"""cnd:put("existing", document { $validDoc })""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPathEquals("""doc('/db/data/conditionals/existing.xml')//tei:revisionDesc/tei:change[1]""",
          "a change record has been added",
          """<tei:change xmlns:tei="http://www.tei-c.org/ns/1.0" type="edited" who="/user/xqtest1"
                        when="..."/>"""
        )
        .go
    }
    
    it("fails to put a resource when unauthenticated") {
        val validDoc = readXmlFile("src/test/resources/api/data/conditionals/existing_after_put.xml")
        xq(s"""cnd:put("existing", document { $validDoc })""")
          .assertHttpUnauthorized
          .go
    }
    
    it("fails to put a valid resource to a nonexisting resource") {
      val validDoc = readXmlFile("src/test/resources/api/data/conditionals/valid.xml")
      xq(s"""cnd:put("does_not_exist", document { $validDoc })""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
    
    it("fails to put an invalid resource") {
      val invalidDoc = readXmlFile("src/test/resources/api/data/conditionals/invalid.xml")
      xq(s"""cnd:put("existing", document { $invalidDoc })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

  }

}

class TestConditionalsDelete extends DbTest with CommonTestConditionals {

  override def beforeEach(): Unit = {
    super.beforeEach()

    setupUsers(2)
    setupResource("src/test/resources/api/data/conditionals/existing.xml", "existing", "conditionals", 1, None)
    setupResource("src/test/resources/api/data/conditionals/existing.xml", "no_write_access", "conditionals", 2,
      None, Some("everyone"), Some("rw-r--r--"))
  }

  override def afterEach(): Unit = {
    super.afterEach()

    teardownResource("existing", "conditionals", 1)
    teardownResource("no_write_access", "conditionals", 2)
    teardownUsers(2)
  }

  describe("cnd:delete") {
    it("removes an existing resource") {
      xq("""cnd:delete("existing")""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }
    
    it("does not remove an existing resource when unauthenticated") {
      xq("""cnd:delete("existing")""")
        .assertHttpUnauthorized
        .go
    }

    it("fails to remove a nonexisting resource") {
      xq("""cnd:delete("does_not_exist")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("fails to remove a resource without write access") {
      xq("""cnd:delete("no_write_access")""")
        .user("xqtest1")
        .assertHttpForbidden
        .go
    }

    ignore("fails to remove a resource that has external references") {
      xq("""cnd:delete("external_reference")""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }
}