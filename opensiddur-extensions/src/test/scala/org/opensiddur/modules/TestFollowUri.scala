package org.opensiddur.modules

import org.opensiddur.DbTest

class TestFollowUri extends DbTest {
  override val prolog =
    """xquery version '3.1';
import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "xmldb:exist:///db/apps/opensiddur-server/modules/follow-uri.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

    """

  override def beforeAll: Unit = {
    super.beforeAll
    xq(
      """let $user := tcommon:setup-test-users(1)
         return ()
        """)
      .go
    setupResource("src/test/resources/modules/follow-uri-context-1.xml",
      "follow-uri-context-1", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/modules/follow-uri-context-2.xml",
      "follow-uri-context-2", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/modules/no-dependencies.xml",
      "no-dependencies", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/modules/no-dependencies.xml",
      "external-dependencies", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/modules/dep-root.xml",
      "dep-root", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/modules/dep-tree1.xml",
      "dep-tree1", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/modules/dep-tree2.xml",
      "dep-tree2", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
    setupResource("src/test/resources/modules/dep-tree3.xml",
      "dep-tree3", "original", 1, Some("en"),
      group=Some("everyone"),permissions=Some("rw-rw-r--"))
  }

  override def afterAll(): Unit = {
    teardownResource("dep-tree3", "original", 1)
    teardownResource("dep-tree2", "original", 1)
    teardownResource("dep-tree1", "original", 1)
    teardownResource("dep-root", "original", 1)
    teardownResource("external-dependencies", "original", 1)
    teardownResource("no-dependencies", "original", 1)
    teardownResource("follow-uri-context-2", "original", 1)
    teardownResource("follow-uri-context-1", "original", 1)
    xq(
      """let $user := tcommon:teardown-test-users(2)
         return ()
        """)
    super.afterAll()
  }

  describe("uri:uri-base-path") {
    it("returns a path without a fragment") {
      xq("""uri:uri-base-path("abc.xml")""")
        .assertEquals("abc.xml")
        .go
    }

    it("removes the fragment from a path with one") {
      xq("""uri:uri-base-path("abc.xml#def")""")
        .assertEquals("abc.xml")
        .go
    }
  }

  describe("uri:uri-fragment") {
    it("returns empty for a path with no fragment") {
      xq("""uri:uri-fragment("abc.xml")""")
        .assertEquals("")
        .go
    }

    it("returns the fragment for a path that has one") {
      xq("""uri:uri-fragment("abc.xml#def")""")
        .assertEquals("def")
        .go
    }
  }

  describe("uri:follow (fast=true)") {
    it("returns the destination itself when the destination is not a pointer") {
      xq("""uri:follow(doc("/db/data/original/en/follow-uri-context-1.xml")/id("destination"), -1, (), true())""")
        .assertXPath("""$output/self::tei:seg/@xml:id='destination' and count($output) = 1""")
        .go
    }

    it("returns the final destination when the immediate destination points directly somewhere else") {
      xq("""uri:follow(doc("/db/data/original/en/follow-uri-context-1.xml")/id("one"), -1, (), true())""")
        .assertXPath("""$output/self::tei:seg/@xml:id='destination' and count($output) = 1""")
        .go
    }

    it("returns the final destination when there are 2 chained pointers") {
      xq("""uri:follow(doc("/db/data/original/en/follow-uri-context-1.xml")/id("two"), -1, (), true())""")
        .assertXPath("""$output/self::tei:seg/@xml:id='destination' and count($output) = 1""")
        .go
    }

    it("returns the final destination when there are 3 chained pointers") {
      xq("""uri:follow(doc("/db/data/original/en/follow-uri-context-1.xml")/id("three"), -1, (), true())""")
        .assertXPath("""$output/self::tei:seg/@xml:id='destination' and count($output) = 1""")
        .go
    }

    it("returns the next pointer when evaluate=none") {
      xq("""uri:follow(doc("/db/data/original/en/follow-uri-context-1.xml")/id("noeval"), -1, (), true())""")
        .assertXPath("""$output/self::tei:ptr/@xml:id='three' and count($output) = 1""")
        .go
    }

    it("returns two pointers ahead when evaluate=one") {
      xq("""uri:follow(doc("/db/data/original/en/follow-uri-context-1.xml")/id("evalone"), -1, (), true())""")
        .assertXPath("""$output/self::tei:ptr/@xml:id='two' and count($output) = 1""")
        .go
    }

    it("returns both results when the pointer is a join") {
      xq("""uri:follow(doc("/db/data/original/en/follow-uri-context-1.xml")/id("eval_join"), -1, (), true())""")
        .assertXPath("count($output) = 2", "count is 2")
        .assertXPath("$output/self::tei:seg/@xml:id='destination'", "segment 1 is present")
        .assertXPath("$output/self::tei:seg/@xml:id='destination2'", "segment 2 is present")
        .go
    }

    it("returns a p when the result is a join into a paragraph") {
      xq("""uri:follow(doc("/db/data/original/en/follow-uri-context-1.xml")/id("eval_join_as_p"), -1, (), true())""")
        .assertXPath("count($output) = 1 and exists($output/self::tei:p)", "result is 1 paragraph")
        .assertXPath("$output/tei:seg/@xml:id='destination'", "segment 1 is present")
        .assertXPath("$output/tei:seg/@xml:id='destination2'", "segment 2 is present")
        .go
    }

    it("returns the destination when the pointer points to a different file") {
      xq("""uri:follow(doc("/db/data/original/en/follow-uri-context-1.xml")/id("in_file_2"), -1, (), true())""")
        .assertXPath("$output/self::tei:seg/@xml:id='f2_destination' and count($output) = 1")
        .go
    }

    it("returns the destination when the other file has indirection") {
      xq("""uri:follow(doc("/db/data/original/en/follow-uri-context-1.xml")/id("in_file_2_indirect"), -1, (), true())""")
        .assertXPath("$output/self::tei:seg/@xml:id='f2_destination' and count($output) = 1")
        .go
    }

    it("returns the full range when the destination is a range") {
      xq("""uri:follow(doc("/db/data/original/en/follow-uri-context-1.xml")/id("range"), -1, (), true())""")
        .assertXmlEquals("""<tei:seg xmlns:tei="http://www.tei-c.org/ns/1.0"
                                               xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                                               jf:id="part1">1</tei:seg>""",
                              """<tei:seg xmlns:tei="http://www.tei-c.org/ns/1.0"
                                               xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                                               jf:id="part2">2</tei:seg>""",
                              """<tei:seg xmlns:tei="http://www.tei-c.org/ns/1.0"
                                               xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                                               jf:id="part3">3</tei:seg>""")
        .go
    }

    it("does not follow pointers of type=url") {
      xq("""uri:follow(doc("/db/data/original/en/follow-uri-context-1.xml")/id("url_ptr"), -1, (), true())""")
        .assertXPath("$output/self::tei:ptr/@xml:id='url_ptr' and count($output)=1")
        .go
    }

    it("stops following a pointer at a url pointer") {
      xq("""uri:follow(doc("/db/data/original/en/follow-uri-context-1.xml")/id("to_url_ptr"), -1, (), true())""")
        .assertXPath("$output/self::tei:ptr/@xml:id='url_ptr' and count($output)=1")
        .go
    }
  }

  describe("uri:fast-follow") {
    it("handles a pointer to a range that crosses a hierarchy, $allow-copies=false()") {
      xq("""let $ptr := doc("/db/data/original/en/follow-uri-context-1.xml")/id("range_bdy")
           return
            uri:fast-follow($ptr/@target/string(), $ptr, -1, (), false(), ())[. instance of element()]""")
        .assertXmlEquals("""<tei:milestone xmlns:tei="http://www.tei-c.org/ns/1.0"
                          |                           xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                          |                           jf:id="bdy1"/>
                          |            <tei:seg xmlns:tei="http://www.tei-c.org/ns/1.0"
                          |                     xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                          |                     jf:id="inbdy1">YES 1</tei:seg>
                          |            <tei:seg xmlns:tei="http://www.tei-c.org/ns/1.0"
                          |                     xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                          |                     jf:id="inbdy2">YES 2</tei:seg>
                          |            <tei:seg xmlns:tei="http://www.tei-c.org/ns/1.0"
                          |                     xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                          |                     jf:id="inbdy3"
                          |                     xml:lang="he">כן 3</tei:seg>
                          |            <tei:milestone xmlns:tei="http://www.tei-c.org/ns/1.0"
                          |                           xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                          |                           jf:id="bdy2"/>""".stripMargin)
    }

    it("returns a range that crosses a hierarchy, $allow-copies=true() (including uri attributes for copied elements)") {
      xq("""let $ptr := doc("/db/data/original/en/follow-uri-context-1.xml")/id("range_bdy")
            return
              uri:fast-follow($ptr/@target/string(), $ptr, -1, (), true(), ())""")
        .assertXmlEquals("""            <tei:milestone xmlns:tei="http://www.tei-c.org/ns/1.0"
                          |                           xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                          |                           xmlns:uri="http://jewishliturgy.org/transform/uri"
                          |                           jf:id="bdy1"
                          |                           uri:lang="en"
                          |                           uri:base="/db/apps/opensiddur-tests/tests/modules/follow-uri-context-1.xml"
                          |                           uri:document-uri="/db/apps/opensiddur-tests/tests/modules/follow-uri-context-1.xml"/>
                          |            <tei:seg xmlns:tei="http://www.tei-c.org/ns/1.0"
                          |                     xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                          |                     xmlns:uri="http://jewishliturgy.org/transform/uri"
                          |                     jf:id="inbdy1"
                          |                     uri:lang="en"
                          |                     uri:base="/db/apps/opensiddur-tests/tests/modules/follow-uri-context-1.xml"
                          |                     uri:document-uri="/db/apps/opensiddur-tests/tests/modules/follow-uri-context-1.xml">YES 1</tei:seg>
                          |            <tei:seg xmlns:tei="http://www.tei-c.org/ns/1.0"
                          |                     xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                          |                     xmlns:uri="http://jewishliturgy.org/transform/uri"
                          |                     jf:id="inbdy2"
                          |                     uri:lang="en"
                          |                     uri:base="/db/apps/opensiddur-tests/tests/modules/follow-uri-context-1.xml"
                          |                     uri:document-uri="/db/apps/opensiddur-tests/tests/modules/follow-uri-context-1.xml">YES 2</tei:seg>
                          |            <tei:ab xmlns:tei="http://www.tei-c.org/ns/1.0"
                          |                    xmlns:jf="http://jewishliturgy.org/ns/jlptei/flat/1.0"
                          |                    xmlns:uri="http://jewishliturgy.org/transform/uri"
                          |                    jf:id="inside"
                          |                    uri:lang="en"
                          |                    uri:base="/db/apps/opensiddur-tests/tests/modules/follow-uri-context-1.xml"
                          |                    uri:document-uri="/db/apps/opensiddur-tests/tests/modules/follow-uri-context-1.xml">
                          |               <tei:seg jf:id="inbdy3" xml:lang="he"
                          |                        uri:base="/db/apps/opensiddur-tests/tests/modules/follow-uri-context-1.xml"
                          |                        uri:document-uri="/db/apps/opensiddur-tests/tests/modules/follow-uri-context-1.xml">כן 3</tei:seg>
                          |               <tei:milestone jf:id="bdy2" uri:lang="en"
                          |                              uri:base="/db/apps/opensiddur-tests/tests/modules/follow-uri-context-1.xml"
                          |                              uri:document-uri="/db/apps/opensiddur-tests/tests/modules/follow-uri-context-1.xml"/>
                          |            </tei:ab>
                          |""".stripMargin)
    }
  }

  describe("uri:dependency") {
    it("returns a self dependency for a document with no dependencies") {
      xq("""uri:dependency(doc("/db/data/original/en/no-dependencies.xml"), ())""")
        .assertEquals("/db/data/original/en/no-dependencies.xml")
        .go
    }
    
    it("returns only self dependency of a resource with internal and external dependencies") {
      xq("""uri:dependency(doc("/db/data/original/en/external-dependencies.xml"), ())""")
        .assertEquals("/db/data/original/en/external-dependencies.xml")
        .go
    }

    it("returns all dependencies in a tree with one circular dependency") {
      xq("""uri:dependency(doc("/db/data/original/en/dep-root.xml"), ())""")
        .assertXPath("count($output)=4", "4 listed")
        .assertXPath("""every $d in (
                               "/db/data/original/en/dep-root.xml",
                               "/db/data/original/en/dep-tree1.xml",
                               "/db/data/original/en/dep-tree2.xml",
                               "/db/data/original/en/dep-tree3.xml") satisfies $d=$output""", "all deps listed")
        .go
    }
  }
}
