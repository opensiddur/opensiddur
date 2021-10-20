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
}