package org.opensiddur.transforms

import org.opensiddur.DbTest

class TestConditionals extends DbTest {
  /** imports, namespaces and variables */
  override val prolog: String =
    """xquery version '3.1';
    
  declare namespace tei="http://www.tei-c.org/ns/1.0";
  declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
  declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

  import module namespace cond="http://jewishliturgy.org/transform/conditionals"
    at "xmldb:exist:///db/apps/opensiddur-server/transforms/conditionals.xqm";
  import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
    at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";
  
    """

  override def beforeAll: Unit = {
    super.beforeAll()
    
    setupUsers(1)
    
    setupResource("src/test/resources/transforms/Conditionals/conditional1.xml", "conditional1", "conditionals", 1)
  }

  override def afterAll(): Unit = {
    teardownResource("conditional1", "conditionals", 1)
    
    teardownUsers(1)
    
    super.afterAll()
  }
  
  describe("cond:evaluate") {
    it("returns true for a condition checking 1 true value") {
      xq("""let $settings := map {
                               "combine:settings" : map {
                                   "FS->ONE" : <tei:string>YES</tei:string>
                               }
                           }
                           return
                               cond:evaluate(
                                   <tei:fs type="FS">
                                       <tei:f name="ONE"><j:yes/></tei:f>
                                   </tei:fs>,
                                   $settings
                               ) """)
        .assertEquals("YES")
        .go
    }
    
    it("returns false for a condition checking one false value") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>YES</tei:string>
                    }
                }
                return
                      cond:evaluate(
                          <tei:fs type="FS">
                              <tei:f name="ONE"><j:no/></tei:f>
                          </tei:fs>, 
                          $settings
                      )""")
        .assertEquals("NO")
        .go
    }
    
    it("returns maybe for a condition checking 1 maybe value") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>MAYBE</tei:string>
                    }
                }
                return
                      cond:evaluate(
                          <tei:fs type="FS">
                              <tei:f name="ONE"><j:yes/></tei:f>
                          </tei:fs>, 
                          $settings
                      ) """)
        .assertEquals("MAYBE")
        .go
    }

    it("returns two results for a condition checking one true and one false value") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>YES</tei:string>,
                        "FS->TWO" : <tei:string>NO</tei:string>
                    }
                }
                return
                      cond:evaluate(
                          <tei:fs type="FS">
                              <tei:f name="ONE"><j:yes/></tei:f>
                              <tei:f name="TWO"><j:yes/></tei:f>
                          </tei:fs>, 
                          $settings
                      ) """)
        .assertEquals("YES", "NO")
        .go
    }

    it("returns YES when j:all conditions are all YES") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>YES</tei:string>,
                        "FS->TWO" : <tei:string>YES</tei:string>,
                        "FS->THREE" : <tei:string>YES</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <j:all>
                                <tei:fs type="FS">
                                    <tei:f name="ONE"><j:yes/></tei:f>
                                    <tei:f name="TWO"><j:yes/></tei:f>
                                    <tei:f name="THREE"><j:yes/></tei:f>
                                </tei:fs>
                            </j:all>,
                            $settings
                        )""")
        .assertEquals("YES")
        .go
    }
    
    it("returns NO with all and one NO") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>YES</tei:string>,
                        "FS->TWO" : <tei:string>YES</tei:string>,
                        "FS->THREE" : <tei:string>NO</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <j:all>
                                <tei:fs type="FS">
                                    <tei:f name="ONE"><j:yes/></tei:f>
                                    <tei:f name="TWO"><j:yes/></tei:f>
                                    <tei:f name="THREE"><j:yes/></tei:f>
                                </tei:fs>
                            </j:all>,
                            $settings
                        )""")
        .assertEquals("NO")
        .go
    }
    
    it("returns MAYBE for all and one MAYBE") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>YES</tei:string>,
                        "FS->TWO" : <tei:string>YES</tei:string>,
                        "FS->THREE" : <tei:string>MAYBE</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <j:all>
                                <tei:fs type="FS">
                                    <tei:f name="ONE"><j:yes/></tei:f>
                                    <tei:f name="TWO"><j:yes/></tei:f>
                                    <tei:f name="THREE"><j:yes/></tei:f>
                                </tei:fs>
                            </j:all>,
                            $settings
                        )""")
        .assertEquals("MAYBE")
        .go
    }
    
    it("returns YES for any when all are YES") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>YES</tei:string>,
                        "FS->TWO" : <tei:string>YES</tei:string>,
                        "FS->THREE" : <tei:string>YES</tei:string>
                    }
                }
                return
                    cond:evaluate(
                            <j:any>
                                <tei:fs type="FS">
                                    <tei:f name="ONE"><j:yes/></tei:f>
                                    <tei:f name="TWO"><j:yes/></tei:f>
                                    <tei:f name="THREE"><j:yes/></tei:f>
                                </tei:fs>
                            </j:any>,
                            $settings
                        )""")
        .assertEquals("YES")
        .go
    }
    
    it("returns YES for any when there is one YES") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>YES</tei:string>,
                        "FS->TWO" : <tei:string>NO</tei:string>,
                        "FS->THREE" : <tei:string>NO</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <j:any>
                                <tei:fs type="FS">
                                    <tei:f name="ONE"><j:yes/></tei:f>
                                    <tei:f name="TWO"><j:yes/></tei:f>
                                    <tei:f name="THREE"><j:yes/></tei:f>
                                </tei:fs>
                            </j:any>,
                            $settings
                        )""")
        .assertEquals("YES")
        .go
    }
    
    it("returns MAYBE for any when there is one MAYBE") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>MAYBE</tei:string>,
                        "FS->TWO" : <tei:string>YES</tei:string>,
                        "FS->THREE" : <tei:string>NO</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <j:any>
                                <tei:fs type="FS">
                                    <tei:f name="ONE"><j:yes/></tei:f>
                                    <tei:f name="TWO"><j:yes/></tei:f>
                                    <tei:f name="THREE"><j:yes/></tei:f>
                                </tei:fs>
                            </j:any>,
                            $settings
                        )""")
        .assertEquals("MAYBE")
        .go
    }
    
    it("returns NO for oneOf when all are YES") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>YES</tei:string>,
                        "FS->TWO" : <tei:string>YES</tei:string>,
                        "FS->THREE" : <tei:string>YES</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <j:oneOf>
                                <tei:fs type="FS">
                                    <tei:f name="ONE"><j:yes/></tei:f>
                                    <tei:f name="TWO"><j:yes/></tei:f>
                                    <tei:f name="THREE"><j:yes/></tei:f>
                                </tei:fs>
                            </j:oneOf>,
                            $settings
                        )""")
        .assertEquals("NO")
        .go
    }
    
    it("returns NO for oneOf when all are NO") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>NO</tei:string>,
                        "FS->TWO" : <tei:string>NO</tei:string>,
                        "FS->THREE" : <tei:string>NO</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <j:oneOf>
                                <tei:fs type="FS">
                                    <tei:f name="ONE"><j:yes/></tei:f>
                                    <tei:f name="TWO"><j:yes/></tei:f>
                                    <tei:f name="THREE"><j:yes/></tei:f>
                                </tei:fs>
                            </j:oneOf>,
                            $settings
                        )""")
        .assertEquals("NO")
        .go
    }
    
    it("returns YES for oneOf when there is one YES") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>YES</tei:string>,
                        "FS->TWO" : <tei:string>NO</tei:string>,
                        "FS->THREE" : <tei:string>NO</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <j:oneOf>
                                <tei:fs type="FS">
                                    <tei:f name="ONE"><j:yes/></tei:f>
                                    <tei:f name="TWO"><j:yes/></tei:f>
                                    <tei:f name="THREE"><j:yes/></tei:f>
                                </tei:fs>
                            </j:oneOf>,
                            $settings
                        )""")
        .assertEquals("YES")
        .go
    }
    
    it("returns MAYBE for oneOf when there is one MAYBE") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>MAYBE</tei:string>,
                        "FS->TWO" : <tei:string>NO</tei:string>,
                        "FS->THREE" : <tei:string>NO</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <j:oneOf>
                                <tei:fs type="FS">
                                    <tei:f name="ONE"><j:yes/></tei:f>
                                    <tei:f name="TWO"><j:yes/></tei:f>
                                    <tei:f name="THREE"><j:yes/></tei:f>
                                </tei:fs>
                            </j:oneOf>,
                            $settings
                        )""")
        .assertEquals("MAYBE")
        .go
    }
    
    it("returns NO for oneOf when there is one YES and one MAYBE") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>MAYBE</tei:string>,
                        "FS->TWO" : <tei:string>YES</tei:string>,
                        "FS->THREE" : <tei:string>NO</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <j:oneOf>
                                <tei:fs type="FS">
                                    <tei:f name="ONE"><j:yes/></tei:f>
                                    <tei:f name="TWO"><j:yes/></tei:f>
                                    <tei:f name="THREE"><j:yes/></tei:f>
                                </tei:fs>
                            </j:oneOf>,
                            $settings
                        )""")
        .assertEquals("NO")
        .go
    }
    
    it("returns that not YES is NO") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>YES</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <j:not>
                                <tei:fs type="FS">
                                    <tei:f name="ONE"><j:yes/></tei:f>
                                </tei:fs>
                            </j:not>,
                            $settings
                        )""")
        .assertEquals("NO")
        .go
    }
    
    it("returns that not NO is YES") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>NO</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <j:not>
                                <tei:fs type="FS">
                                    <tei:f name="ONE"><j:yes/></tei:f>
                                </tei:fs>
                            </j:not>,
                            $settings
                        )""")
        .assertEquals("YES")
        .go
    }
    
    it("returns that not MAYBE is MAYBE") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "FS->ONE" : <tei:string>MAYBE</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <j:not>
                                <tei:fs type="FS">
                                    <tei:f name="ONE"><j:yes/></tei:f>
                                </tei:fs>
                            </j:not>,
                            $settings
                        )""")
        .assertEquals("MAYBE")
        .go
    }
    
    it("returns a literal default value") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                    }
                }
                return
                        cond:evaluate(
                            <tei:fs type="test:FS">
                                <tei:f name="DEFAULT_YES"><tei:default/></tei:f>
                            </tei:fs>,
                            $settings
                        )""")
        .assertEquals("YES")
        .go
    }
    
    it("returns a conditional default value when the condition evaluates to true") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "test:FS->CONTROL" : <tei:string>NO</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <tei:fs type="test:FS">
                                <tei:f name="DEFAULT_IF"><j:yes/></tei:f>
                            </tei:fs>,
                            $settings
                        )""")
        .assertEquals("YES")
        .go
    }
    
    it("returns default NO for a conditional default value where the condition evaluates false") {
      xq("""let $settings := map {
                    "combine:settings" : map {
                        "test:FS->CONTROL" : <tei:string>YES</tei:string>
                    }
                }
                return
                        cond:evaluate(
                            <tei:fs type="test:FS">
                                <tei:f name="DEFAULT_IF"><j:yes/></tei:f>
                            </tei:fs>,
                            $settings
                        )""")
        .assertEquals("NO")
        .go
    }
  }
}
