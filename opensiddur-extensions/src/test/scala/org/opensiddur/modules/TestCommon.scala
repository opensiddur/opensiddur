package org.opensiddur.modules

import org.opensiddur.DbTest

class TestCommon extends DbTest {
  /** imports, namespaces and variables */
  override val prolog: String =
    """xquery version '3.1';

  import module namespace common="http://jewishliturgy.org/transform/common"
    at "xmldb:exist:///db/apps/opensiddur-server/modules/common.xqm";
  import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
    at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

  declare namespace tei="http://www.tei-c.org/ns/1.0";
  declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
  declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";
    """

  override def beforeAll: Unit = {
    super.beforeAll
    setupUsers(1)
    setupResource("src/test/resources/modules/common/test_common.xml", "test_common", "original", 1, Some("en"))
  }

  override def afterAll(): Unit = {
    teardownResource("test_common", "original", 1)
    teardownUsers(1)
    super.afterAll()
  }
  
  describe("common:apply-at") {
    it("acts as an identity transform if it can't find the node to apply at") {
      xq("""let $e :=
                     <a>
                       <b>text</b>
                       <c>
                         <d/>
                       </c>
                     </a>
                   return
                     common:apply-at(
                       $e, <e/>, 
                       function($n as node()*, $p as map(*)) as node()* {()},
                       map {}
                    )  """)
        .assertXmlEquals("""<a>
                                    <b>text</b>
                                    <c>
                                       <d/>
                                    </c>
                                 </a>""")
        .go
    }
    
    it("applies a transform if a matching node is found") {
      xq("""let $e :=
          <a>
            <b>text</b>
            <c>
              <d/>
            </c>
          </a>
        return
          common:apply-at(
            $e, $e/c, 
            function($n as node()*, $p as map(*)) as node()* {
              <x/>
            }, 
            map {}
          )   """)
        .assertXmlEquals("""<a>
               <b>text</b>
               <x/>
            </a>""")
        .go
    }
  }

  describe("common:generate-id") {
    it("generates an id") {
      xq("""common:generate-id(doc("/db/data/original/en/test_common.xml"))""")
        .user("xqtest1")
        .assertXPath("""not(empty($output))""")
        .go
    }

    it("generates a different id for 2 different nodes") {
      val firstCall = xq("""common:generate-id(doc("/db/data/original/en/test_common.xml")/*/*/node[1])""")
        .user("xqtest1")
        .assertXPath("""not(empty($output))""")
        .go

      val secondCall = xq("""common:generate-id(doc("/db/data/original/en/test_common.xml")/*/*/node[2])""")
        .user("xqtest1")
        .assertXPath("""not(empty($output))""")
        .go

      assert(firstCall(1) != secondCall(1))
    }

    it("generates the same id twice") {
      val firstCall = xq("""common:generate-id(doc("/db/data/original/en/test_common.xml"))""")
        .user("xqtest1")
        .go

      val secondCall = xq("""common:generate-id(doc("/db/data/original/en/test_common.xml"))""")
        .user("xqtest1")
        .go

      assert(firstCall.head == secondCall.head)
    }
  }
}