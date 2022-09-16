package org.opensiddur.modules

import org.opensiddur.DbTest

class BaseTestMirror extends DbTest {
  /** imports, namespaces and variables */
  override val prolog: String =
    """xquery version '3.1';

  import module namespace magic="http://jewishliturgy.org/magic"
    at "xmldb:exist:/db/apps/opensiddur-server/magic/magic.xqm";
  import module namespace mirror="http://jewishliturgy.org/modules/mirror"
    at "xmldb:exist:///db/apps/opensiddur-server/modules/mirror.xqm";
  import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
    at "xmldb:exist:///db/apps/opensiddur-server/test/tcommon.xqm";


  declare namespace error="http://jewishliturgy.org/errors";

  declare variable $local:original-collection := '/db/data/tests';
  declare variable $local:mirror-collection := '/db/data/tests/mirror';

  declare function local:same-permissions(
      $a as xs:string,
      $b as xs:string
      ) as xs:boolean {
        (xmldb:collection-available($a) or doc-available($a)) and
        (xmldb:collection-available($b) or doc-available($b)) and
        xmldiff:compare(sm:get-permissions(xs:anyURI($a)),sm:get-permissions(xs:anyURI($b)))
      };

      declare function local:transform(
        $context as node()
      ) as node()* {
        typeswitch($context)
        case document-node() return document { local:transform($context/*)}
        case element(up-to-date) return element up-to-date { attribute n { $context/@n/number() + 1 }}
        default return $context
      };

    """
  val delayTimeMs = 500;  // for forced delays

  override def beforeAll: Unit = {
    super.beforeAll

    setupUsers(2)
    setupCollection("/db/data", "tests", Some("admin"), Some("dba"), Some("rwxrwxrwx"))
    setupCollection("/db/data/tests", "mirror", Some("admin"), Some("dba"), Some("rwxrwxrwx"))
    store("""<mirror:configuration xmlns:mirror="http://jewishliturgy.org/modules/mirror">
                <mirror:of>/db/data/tests</mirror:of>
                <mirror:universal-access>false</mirror:universal-access>
             </mirror:configuration>""",
      "/db/data/tests/mirror", "mirror-conf.xml", firstParamIsContent = true)
  }

  override def afterAll(): Unit = {
    teardownCollection("/db/data/tests")
    teardownUsers(2)

    super.afterAll()
  }
}

class TestMirrorCreate extends BaseTestMirror {
  override def afterEach(): Unit = {
    teardownCollection("/db/data/tests/new-mirror")
    super.afterEach()
  }

  describe("mirror:create") {
    it("creates a new mirror collection") {
      xq("""mirror:create("/db/data/tests/new-mirror", $local:original-collection)""")
        .user("xqtest1")
        .assertXPath("""xmldb:collection-available("/db/data/tests/new-mirror")""", "mirror collection created")
        .assertXPath("""doc-available("/db/data/tests/new-mirror/" || $mirror:configuration)""", "mirror configuration exists")
        .assertXPath("""doc('/db/data/tests/new-mirror/' || $mirror:configuration)/mirror:configuration/mirror:of = "/db/data/tests" """, "mirror configuration points to the correct original")
        .assertXPath("""local:same-permissions("/db/data/tests/new-mirror", $local:original-collection)""", "mirror collection permissions are the same as the original collection")
        .go
    }

    it("creates a new mirror collection with universal access") {
      xq("""mirror:create("/db/data/tests/new-mirror", $local:original-collection, true())""")
        .user("xqtest1")
        .assertXPath("""xmldb:collection-available("/db/data/tests/new-mirror") """, "mirror collection created")
        .assertXPath("""doc-available("/db/data/tests/new-mirror/" || $mirror:configuration) """, "mirror configuration exists")
        .assertXPath("""doc('/db/data/tests/new-mirror/' || $mirror:configuration)/mirror:configuration/mirror:of = "/db/data/tests" """, "mirror configuration points to the correct original")
        .assertXPath("""doc('/db/data/tests/new-mirror/' || $mirror:configuration)/mirror:configuration/mirror:universal-access = "true" """, "mirror is configured for universal access")
        .assertXPath("""sm:get-permissions(xs:anyURI("/db/data/tests/new-mirror"))/*/@mode = "rwxrwxrwx" """, "mirror collection permissions are universally permissive")
        .go
    }

    it("creates a new mirror collection with an extension map") {
      xq("""mirror:create("/db/data/tests/new-mirror", $local:original-collection, false(),
                   map {
                   "xml" : "html"
                    , "txt" : "csv"}
                 )""")
        .user("xqtest1")
        .assertXPath("""xmldb:collection-available("/db/data/tests/new-mirror") """, "mirror collection created")
        .assertXPath("""doc-available("/db/data/tests/new-mirror/" || $mirror:configuration) """, "mirror configuration exists")
        .assertXPath("""doc('/db/data/tests/new-mirror/' || $mirror:configuration)/mirror:configuration/mirror:of = "/db/data/tests" """, "mirror configuration points to the correct original")
        .assertXPath("""count(doc("/db/data/tests/new-mirror/" || $mirror:configuration)/mirror:configuration/mirror:map) = 2 """, "mirror configuration includes 2 maps")
        .assertXPath("""doc("/db/data/tests/new-mirror/" || $mirror:configuration)/mirror:configuration/mirror:map[@from="xml"][@to="html"] """, "mirror configuration includes xml-&gt;html map")
        .assertXPath("""doc("/db/data/tests/new-mirror/" || $mirror:configuration)/mirror:configuration/mirror:map[@from="txt"][@to="csv"] """, "mirror configuration includes txt-&gt;csv map")
        .go
    }
  }
}

class TestMirrorPathExtended extends BaseTestMirror {
  override def beforeEach(): Unit = {
    super.beforeEach()

    xq("""update insert <mirror:map from="xml" to="html"/> into
         doc("/db/data/tests/mirror/mirror-conf.xml")/mirror:configuration""")
      .go
  }

  describe("mirror:path (with extension map)") {
    it("returns the path concatenated and mapped") {
      xq("""mirror:mirror-path("/db/data/tests/mirror", "/db/data/tests/original/path/test.xml")""")
        .user("xqtest1")
        .assertEquals("/db/data/tests/mirror/original/path/test.html")
        .go
    }

    it("returns the path concatenated with an unmapped extension") {
      xq("""mirror:mirror-path("/db/data/tests/mirror", "/db/data/tests/original/path/test.xsl")""")
        .user("xqtest1")
        .assertEquals("/db/data/tests/mirror/original/path/test.xsl")
        .go
    }
  }

  describe("mirror:unmirror-path (with extension map)") {
    it("returns the path with the mapped extension") {
      xq("""mirror:unmirror-path("/db/data/tests/mirror", "/db/data/tests/mirror/one/two/test.html") """)
        .user("xqtest1")
        .assertEquals("/db/data/tests/one/two/test.xml")
        .go
    }

    it("returns a path with an unmapped extension") {
      xq("""mirror:unmirror-path("/db/data/tests/mirror", "/db/data/tests/mirror/one/two/test.xsl") """)
        .user("xqtest1")
        .assertEquals("/db/data/tests/one/two/test.xsl")
        .go
    }
  }
}

class TestMirrorPath extends BaseTestMirror {
  describe("mirror:mirror-path") {
    it("returns the path concatenated") {
      xq("""mirror:mirror-path("/db/data/tests/mirror", "/db/data/tests/original/path")""")
        .user("xqtest1")
        .assertEquals("/db/data/tests/mirror/original/path")
        .go
    }

    it("handles relative paths in second parameter") {
      xq("""mirror:mirror-path("/db/data/tests/mirror", "original/path")""")
        .user("xqtest1")
        .assertEquals("/db/data/tests/mirror/original/path")
        .go
    }

    it("fails when no /db prefix in second parameter") {
      xq("""mirror:mirror-path("/db/data/tests/mirror", "/data/tests")""")
        .user("xqtest1")
        .assertThrows("error:NOT_MIRRORED")
        .go
    }

    it("fails when no /db in first parameter") {
      xq("""mirror:mirror-path("/data/tests/mirror", "/db/data/tests")""")
        .user("xqtest1")
        .assertThrows("error:INPUT")
        .go
    }

    it("fails if mirror collection is not a mirror") {
      xq("""mirror:mirror-path("/db", "/original/path")""")
        .user("xqtest1")
        .assertThrows("error:NOT_A_MIRROR")
        .go
    }

    it("fails if mirrored collection is not in the mirror") {
      xq("""mirror:mirror-path("/db/data/tests/mirror", "/db")""")
        .user("xqtest1")
        .assertThrows("error:NOT_MIRRORED")
        .go
    }
  }

  describe("mirror:unmirror-path") {
    it("returns a path when /db is in both parameters, self") {
      xq("""mirror:unmirror-path("/db/data/tests/mirror", "/db/data/tests/mirror") """)
        .user("xqtest1")
        .assertEquals("/db/data/tests")
        .go
    }

    it("fails when /db missing in second parameter") {
      xq("""mirror:unmirror-path("/db/data/tests/mirror", "/data/tests/mirror") """)
        .user("xqtest1")
        .assertThrows("error:INPUT")
        .go
    }

    it("it fails when /db missing in first parameter") {
      xq("""mirror:unmirror-path("/data/tests/mirror", "/db/data/tests/mirror") """)
        .user("xqtest1")
        .assertThrows("error:INPUT")
        .go
    }

    it("returns a path when given the mirror collection + subcollections") {
      xq("""mirror:unmirror-path("/db/data/tests/mirror", "/db/data/tests/mirror/one/two") """)
        .user("xqtest1")
        .assertEquals("/db/data/tests/one/two")
        .go
    }
  }
}

class TestMirrorCollection extends BaseTestMirror {
  override def beforeAll: Unit = {
    super.beforeAll
  
    setupCollection("/db/data/tests", "one", Some("xqtest1"), Some("everyone"), Some("rwxrwxr-x"))
    setupCollection("/db/data/tests/one", "two", Some("xqtest1"), Some("xqtest1"), Some("rwxrwxr-x"))
    setupCollection("/db/data/tests/one/two", "three", Some("xqtest1"), Some("xqtest1"), Some("rwxrwxr-x"))
    setupCollection("/db/data/tests/one/two/three", "four", Some("xqtest1"), Some("xqtest1"), Some("rwxrwxr-x"))
    
    xq("""
         let $one := xs:anyURI("/db/data/tests/one")
         let $two := xs:anyURI("/db/data/tests/one/two")
         let $three := xs:anyURI("/db/data/tests/one/two/three")
         let $four := xs:anyURI("/db/data/tests/one/two/three/four")
         let $two-ace := sm:add-user-ace($two, "xqtest2", true(), "w")
         let $three-ace := sm:add-group-ace($three, "everyone", true(), "r")
         let $four-ace-1 := sm:add-user-ace($four, "xqtest2", true(), "r")
         let $four-ace-2 := sm:add-group-ace($four, "everyone", false(), "w")
         return ()""")
      .user("admin")
      .go
  }

  override def afterAll(): Unit = {
    teardownCollection("/db/data/tests/one")
    super.afterAll()
  }

  describe("mirror:make-collection-path") {
    it("makes a collection hierarchy mirror") {
      xq("""mirror:make-collection-path("/db/data/tests/mirror", "/db/data/tests/one/two/three/four") """)
        .user("xqtest1")
        .assertXPath("""xmldb:collection-available("/db/data/tests/mirror/one") """, "mirror collection 'one' created")
        .assertXPath("""xmldb:collection-available("/db/data/tests/mirror/one/two") """, "mirror collection 'two' created")
        .assertXPath("""xmldb:collection-available("/db/data/tests/mirror/one/two/three") """, "mirror collection 'three' created")
        .assertXPath("""xmldb:collection-available("/db/data/tests/mirror/one/two/three/four") """, "mirror collection 'four' created")
        .assertXPath("""local:same-permissions("/db/data/tests/mirror/one","/db/data/tests/one") """, "mirror collection 'one' has same permissions as /db/data/tests/one (changed owner/group/mode)")
        .assertXPath("""local:same-permissions("/db/data/tests/mirror/one/two","/db/data/tests/one/two") """, "mirror collection 'two' has same permissions as /db/data/tests/one/two (allowed user ACE)")
        .assertXPath("""local:same-permissions("/db/data/tests/mirror/one/two/three","/db/data/tests/one/two/three") """, "mirror collection 'three' has same permissions as /db/data/tests/one/two/three (allowed group ACE)")
        .assertXPath("""local:same-permissions("/db/data/tests/mirror/one/two/three/four","/db/data/tests/one/two/three/four") """, "mirror collection 'four' has same permissions as /db/data/tests/one/two/three/four (allowed user ACE, disallowed group ACE)")
        .go
    }
  }
}

class TestMirrorCollectionUniversal extends BaseTestMirror {
  override def beforeAll: Unit = {
    super.beforeAll

    setupCollection("/db/data/tests", "one", Some("xqtest1"), Some("everyone"), Some("rwxrwxr-x"))
    setupCollection("/db/data/tests/one", "two", Some("admin"), Some("dba"), Some("rwxrwxr-x"))
    setupCollection("/db/data/tests/one/two", "three", Some("admin"), Some("dba"), Some("rwxrwxr-x"))

    xq("""
         let $update := update value doc("/db/data/tests/mirror/" || $mirror:configuration)/*/mirror:universal-access with "true"
         let $one := xs:anyURI("/db/data/tests/one")
         let $two := xs:anyURI("/db/data/tests/one/two")
         let $three := xs:anyURI("/db/data/tests/one/two/three")
         let $two-ace := sm:add-user-ace($two, "xqtest2", true(), "w")
         let $three-ace := sm:add-group-ace($three, "everyone", true(), "r")
         return ()""")
      .user("admin")
      .go
  }

  override def afterAll(): Unit = {
    teardownCollection("/db/data/tests/one")
    super.afterAll()
  }

  describe("mirror:make-collection-path") {
    it("makes a collection hierarchy mirror") {
      xq("""mirror:make-collection-path("/db/data/tests/mirror","/db/data/tests/one/two/three") """)
        .user("xqtest1")
        .assertXPath("""xmldb:collection-available("/db/data/tests/mirror/one") """, "mirror collection 'one' created")
        .assertXPath("""xmldb:collection-available("/db/data/tests/mirror/one/two") """, "mirror collection 'two' created")
        .assertXPath("""xmldb:collection-available("/db/data/tests/mirror/one/two/three") """, "mirror collection 'three' created")
        .assertXPath("""sm:get-permissions(xs:anyURI("/db/data/tests/mirror/one"))/*/@mode="rwxrwxrwx" """, "mirror collection 'one' has universal access permissions")
        .assertXPath("""sm:get-permissions(xs:anyURI("/db/data/tests/mirror/one/two"))/*/@mode="rwxrwxrwx" """, "mirror collection 'two' has universal access permissions")
        .assertXPath("""sm:get-permissions(xs:anyURI("/db/data/tests/mirror/one/two/three"))/*/@mode="rwxrwxrwx" """, "mirror collection 'three' universal access permissions")
        .go
    }
  }
}

class TestMirrorIsUpToDateMirrorNewer extends BaseTestMirror {
  override def beforeAll: Unit = {
    super.beforeAll
    store("""<test/>""", "/db/data/tests", "test.xml", firstParamIsContent = true)
    // add an artificial delay to make the mirror newer
    Thread.sleep(delayTimeMs)

    store("""<mirror/>""", "/db/data/tests/mirror", "test.xml", firstParamIsContent = true)
  }

  override def afterAll(): Unit = {
    remove("/db/data/tests", "test.xml")

    super.afterAll()
  }

  describe("mirror:is-up-to-date") {
    it ("returns true with no function") {
      xq("""mirror:is-up-to-date($local:mirror-collection, "/db/data/tests/test.xml") """)
        .assertTrue
        .go
    }

    it("returns true with an additional function that returns true") {
      xq(
        """mirror:is-up-to-date($local:mirror-collection, "/db/data/tests/test.xml",
          function($m, $t) as xs:boolean { true() }) """)
        .assertTrue
        .go
    }

    it("returns false with an additional function that returns false") {
      xq(
        """mirror:is-up-to-date($local:mirror-collection, "/db/data/tests/test.xml",
          function($m, $t) as xs:boolean { false() }) """)
        .assertFalse
        .go
    }
  }
}

class TestMirrorIsUpToDateExtensionMapMirrorNewer extends BaseTestMirror {
  override def beforeAll: Unit = {
    super.beforeAll
    store("""<test/>""", "/db/data/tests", "test.xml", firstParamIsContent = true)
    // add an artificial delay to make the mirror newer
    Thread.sleep(delayTimeMs)

    store("""<mirror/>""", "/db/data/tests/mirror", "test.html", firstParamIsContent = true)

    xq("""update insert <mirror:map from="xml" to="html"/> into
         doc("/db/data/tests/mirror/mirror-conf.xml")/mirror:configuration""").go
  }

  override def afterAll(): Unit = {
    remove("/db/data/tests", "test.xml")

    super.afterAll()
  }

  describe("mirror:is-up-to-date()") {
    it("returns true when a mapping is present and the mirror is up to date") {
      xq("""mirror:is-up-to-date($local:mirror-collection, "/db/data/tests/test.xml") """)
        .assertTrue
        .go
    }
  }
}

class TestMirrorIsUpToDateMirrorOlder extends BaseTestMirror {

  override def beforeAll: Unit = {
    super.beforeAll

    store("""<mirror/>""", "/db/data/tests/mirror", "test.xml", firstParamIsContent = true)
    // add an artificial delay to make the mirror newer
    Thread.sleep(delayTimeMs)
    store("""<test/>""", "/db/data/tests", "test.xml", firstParamIsContent = true)
  }

  override def afterAll(): Unit = {
    remove("/db/data/tests", "test.xml")

    super.afterAll()
  }

  describe("mirror:is-up-to-date()") {
    it("returns false without an additional function") {
      xq("""mirror:is-up-to-date($local:mirror-collection, "/db/data/tests/test.xml") """)
        .assertFalse
        .go
    }

    it("returns false with an additional function that returns true()") {
      xq("""
          mirror:is-up-to-date($local:mirror-collection, "/db/data/tests/test.xml",
          function($m, $t) as xs:boolean
          {true()}
          )
      """)
        .assertFalse
        .go
    }
  }
}

class TestMirrorIsUpToDateExtensionMapMirrorOlder extends BaseTestMirror {
  override def beforeAll: Unit = {
    super.beforeAll

    store("""<mirror/>""", "/db/data/tests/mirror", "test.html", firstParamIsContent = true)
    // add an artificial delay to make the mirror newer
    Thread.sleep(delayTimeMs)
    store("""<test/>""", "/db/data/tests", "test.xml", firstParamIsContent = true)

    xq("""update insert <mirror:map from="xml" to="html"/> into
         doc("/db/data/tests/mirror/mirror-conf.xml")/mirror:configuration""").go
  }

  override def afterAll(): Unit = {
    remove("/db/data/tests", "test.xml")

    super.afterAll()
  }

  describe("mirror:is-up-to-date()") {
    it("returns false when a mapping is present and the mirror is up to date") {
      xq("""mirror:is-up-to-date($local:mirror-collection, "/db/data/tests/test.xml") """)
        .assertFalse
        .go
    }
  }
}

class TestMirrorStore extends BaseTestMirror {
  override def beforeAll: Unit = {
    super.beforeAll()
    setupCollection("/db/data/tests", "one", Some("xqtest1"), Some("everyone"), Some("rwxrwxr-x"))
    
    store("<test/>", "/db/data/tests/one", "test.xml", firstParamIsContent = true, as = "xqtest1")
  }

  override def afterAll(): Unit = {
    teardownCollection("/db/data/tests/one")
    
    super.afterAll()
  }
  
  describe("mirror:store()") {
    it("stores a resource and returns its path") {
      xq("""mirror:store($local:mirror-collection, "/db/data/tests/one", "test.xml", <mirror/>) """)
        .user("xqtest1")
        .assertEquals("/db/data/tests/mirror/one/test.xml")
        .assertXPath("""xmldb:collection-available("/db/data/tests/mirror/one") """, "mirror collection created")
        .assertXPath("""doc-available("/db/data/tests/mirror/one/test.xml") """, "mirror resource created")
        .assertXPath("""local:same-permissions("/db/data/tests/one/test.xml", "/db/data/tests/mirror/one/test.xml") """, "mirror resource has same permissions as original")
        .go
    }
  }
}

class TestMirrorStoreWithExtensionMap extends BaseTestMirror {  
  override def beforeAll: Unit = {
    super.beforeAll()
    setupCollection("/db/data/tests", "one", Some("xqtest1"), Some("everyone"), Some("rwxrwxr-x"))
  
    store("<test/>", "/db/data/tests/one", "test.xml", firstParamIsContent = true, as = "xqtest1")
    
    xq("""update insert <mirror:map from="xml" to="html"/> into 
                 doc("/db/data/tests/mirror/mirror-conf.xml")/mirror:configuration """).go
  }

  override def afterAll(): Unit = {
    teardownCollection("/db/data/tests/one")

    super.afterAll()
  }
  
  describe("mirror:store()") {
    it("returns the path of a mirror document with an extension map") {
      xq("""mirror:store($local:mirror-collection, "/db/data/tests/one", "test.xml", <html xmlns="http://www.w3.org/1999/xhtml" />)""")
        .user("xqtest1")
        .assertEquals("/db/data/tests/mirror/one/test.html")
        .assertXPath("""xmldb:collection-available("/db/data/tests/mirror/one") """, "mirror collection created")
        .assertXPath("""doc-available("/db/data/tests/mirror/one/test.html") """, "mirror resource created with mapped extension")
        .assertXPath("""local:same-permissions("/db/data/tests/one/test.xml", "/db/data/tests/mirror/one/test.html") """, "mirror resource has same permissions as original")
        .go
    }
  }
}

class TestMirrorRemove extends BaseTestMirror {
  override def beforeEach: Unit = {
    super.beforeEach()
    setupCollection("/db/data/tests/mirror", "one", Some("xqtest1"), Some("everyone"), Some("rwxrwxr-x"))

    store("<test/>", "/db/data/tests/mirror/one", "test.xml", firstParamIsContent = true, as = "xqtest1")
  }

  override protected def afterEach(): Unit = {
    teardownCollection("/db/data/tests/mirror/one")
    
    super.afterEach()
  }
  
  describe("mirror:remove()") {
      it("removes a mirror resource") {

        xq("""mirror:remove($local:mirror-collection, "/db/data/tests/one", "test.xml") """)
          .user("xqtest1")
          .assertXPath("""not(doc-available("/db/data/tests/mirror/one/test.xml")) """, "resource removed")
          .assertXPath("""not(xmldb:collection-available("/db/data/tests/mirror/one")) """, "empty parent collection removed")
          .go
      }
    
    it("removes a collection") {
      xq("""mirror:remove($local:mirror-collection, "/db/data/tests/one") """)
        .user("xqtest1")
        .assertXPath("""not(xmldb:collection-available("/db/data/tests/mirror/one")) """, "collection removed")
        .go
    }
  }
}

class TestMirrorRemoveWithExtensionMap extends BaseTestMirror {
  override def beforeAll: Unit = {
    super.beforeAll()
    setupCollection("/db/data/tests", "one", Some("xqtest1"), Some("everyone"), Some("rwxrwxr-x"))

    store("""<html xmlns="http://www.w3.org/1999/xhtml"/>""", "/db/data/tests/one", "test.html", firstParamIsContent = true, as = "xqtest1")

    xq("""update insert <mirror:map from="xml" to="html"/> into 
                 doc("/db/data/tests/mirror/mirror-conf.xml")/mirror:configuration """).go
  }

  override def afterAll(): Unit = {
    teardownCollection("/db/data/tests/one")

    super.afterAll()
  }

  describe("mirror:remove()") {
    it("removes the resource") {
      xq("""mirror:remove($local:mirror-collection, "/db/data/tests/one", "test.xml")""")
        .user("xqtest1")
        .assertXPath("""not(doc-available("/db/data/tests/mirror/one/test.html")) """, "mapped resource removed")
        .go
    }
  }
}

class TestMirrorApplyIfOutdated extends BaseTestMirror {
  override def beforeEach: Unit = {
    super.beforeEach()
    
    store("""<up-to-date n="100"/>""", "/db/data/tests", "test-up-to-date.xml", firstParamIsContent = true, as = "xqtest1")
    store("""<up-to-date n="1"/>""", "/db/data/tests", "test-out-of-date.xml", firstParamIsContent = true, as = "xqtest1")
    store("""<up-to-date n="1"/>""", "/db/data/tests/mirror", "test-up-to-date.xml", firstParamIsContent = true, as = "xqtest1")
  }

  override def afterEach(): Unit = {
    remove("/db/data/tests", "test-up-to-date.xml", as = "xqtest1")
    remove("/db/data/tests", "test-out-of-date.xml", as = "xqtest1")
    super.afterEach()
  }

  describe("mirror:apply-if-outdated()") {
    it("""does not apply the transform when the file is up to date""") {
      xq("""mirror:apply-if-outdated(
        $local:mirror-collection,
        "/db/data/tests/test-up-to-date.xml",
        local:transform#1)
      """)
        .user("xqtest1")
        .assertXPath("""doc("/db/data/tests/mirror/test-up-to-date.xml")/up-to-date/@n = 1 """, "transform did not run")
        .assertXPath("""$output/up-to-date/@n = 1 """, "return value is correct document")
        .go
    }
    
    it("""does apply the transform when the file is out of date""") {
      xq("""mirror:apply-if-outdated(
          $local:mirror-collection,
          "/db/data/tests/test-out-of-date.xml",
          local:transform#1)
        """)
        .user("xqtest1")
        .assertXPath("""doc("/db/data/tests/mirror/test-out-of-date.xml")/up-to-date/@n = 2 """, "transform did run")
        .assertXPath("""$output/up-to-date/@n = 2 """, "return value is transformed document")
        .go
    }
    
    it("does apply the transform when the file is out of date and given a document-node as parameter #2") {
      xq("""mirror:apply-if-outdated(
          $local:mirror-collection,
          doc("/db/data/tests/test-out-of-date.xml"),
          local:transform#1)
      """)
        .user("xqtest1")
        .assertXPath("""doc("/db/data/tests/mirror/test-out-of-date.xml")/up-to-date/@n = 2 """, "transform did run")
        .assertXPath("""$output/up-to-date/@n = 2 """, "return value is transformed document")
        .go
    }
    
    it("does not apply the transform when in-date and there is a different original node than the transformed node") {
      xq("""mirror:apply-if-outdated(
          $local:mirror-collection,
          doc("/db/data/tests/test-out-of-date.xml"),
          local:transform#1,
          doc("/db/data/tests/test-up-to-date.xml")
          )
        """)
        .user("xqtest1")
        .assertXPath("""doc("/db/data/tests/mirror/test-up-to-date.xml")/up-to-date/@n = 1 """, "transform did not run")
        .assertXPath("""$output/up-to-date/@n = 1 """, "return value is untransformed document")
        .go
    }
    
    it("does apply the transform when out of date with a different original node than the transformed node") {
      xq("""mirror:apply-if-outdated(
          $local:mirror-collection,
          doc("/db/data/tests/test-up-to-date.xml"),
          local:transform#1,
          doc("/db/data/tests/test-out-of-date.xml")
          )
        """)
        .user("xqtest1")
        .assertXPath("""doc("/db/data/tests/mirror/test-out-of-date.xml")/up-to-date/@n = 101 """, "transform did run")
        .assertXPath("""$output/up-to-date/@n = 101 """, "return value is transformed document")
        .go
    }
  }
}

class TestMirrorApplyIfOutdatedWithExtensionMap extends BaseTestMirror {
  override def beforeEach: Unit = {
    super.beforeEach()
    
    xq("""update insert <mirror:map from="xml" to="html"/> into 
                 doc("/db/data/tests/mirror/mirror-conf.xml")/mirror:configuration""").go

    store("""<up-to-date n="100"/>""", "/db/data/tests", "test-up-to-date.xml", firstParamIsContent = true, as = "xqtest1")
    store("""<up-to-date n="1"/>""", "/db/data/tests", "test-out-of-date.xml", firstParamIsContent = true, as = "xqtest1")
    store("""<up-to-date n="1"/>""", "/db/data/tests/mirror", "test-up-to-date.html", firstParamIsContent = true, as = "xqtest1")

  }

  override def afterEach(): Unit = {
    remove("/db/data/tests", "test-up-to-date.xml", as = "xqtest1")
    remove("/db/data/tests", "test-out-of-date.xml", as = "xqtest1")
    super.afterEach()
  }

  describe("mirror:apply-if-outdated()") {
    it("does not run the transform when the file is in date") {
      xq(
        """mirror:apply-if-outdated(
        $local:mirror-collection,
        "/db/data/tests/test-up-to-date.xml",
        local:transform#1)
      """)
        .user("xqtest1")
        .assertXPath("""doc("/db/data/tests/mirror/test-up-to-date.html")/up-to-date/@n = 1 """, "transform did not run")
        .assertXPath("""$output/up-to-date/@n = 1 """, "return value is correct document")
        .go
    }
    it("does run the transform when the file is out of date") {
      xq("""mirror:apply-if-outdated(
          $local:mirror-collection,
          "/db/data/tests/test-out-of-date.xml",
          local:transform#1)
        """)
        .user("xqtest1")
        .assertXPath("""doc("/db/data/tests/mirror/test-out-of-date.html")/up-to-date/@n = 2 """, "transform did run")
        .assertXPath("""$output/up-to-date/@n = 2 """, "return value is transformed document")
        .go
    }
    it("does run the transform when the file is out of date with a document-node as parameter #2") {
      xq("""mirror:apply-if-outdated(
        $local:mirror-collection,
        doc("/db/data/tests/test-out-of-date.xml"),
        local:transform#1)
      """)
        .user("xqtest1")
        .assertXPath("""doc("/db/data/tests/mirror/test-out-of-date.html")/up-to-date/@n = 2 """, "transform did run")
        .assertXPath("""$output/up-to-date/@n = 2 """, "return value is transformed document")
        .go
    }
    it("does not run the transform when the file is up to date with a different original node than the transformed node") {
      xq("""mirror:apply-if-outdated(
        $local:mirror-collection,
        doc("/db/data/tests/test-out-of-date.xml"),
        local:transform#1,
        doc("/db/data/tests/test-up-to-date.xml")
        )
      """)
        .user("xqtest1")
        .assertXPath("""doc("/db/data/tests/mirror/test-up-to-date.html")/up-to-date/@n = 1 """, "transform did not run")
        .assertXPath("""$output/up-to-date/@n = 1 """, "return value is untransformed document")
        .go
    }
    it("runs the transform when the file is out of date with a different original node than the transformed node") {
      xq("""mirror:apply-if-outdated(
        $local:mirror-collection,
        doc("/db/data/tests/test-up-to-date.xml"),
        local:transform#1,
        doc("/db/data/tests/test-out-of-date.xml")
        )
      """)
        .user("xqtest1")
        .assertXPath("""doc("/db/data/tests/mirror/test-out-of-date.html")/up-to-date/@n = 101 """, "transform did run")
        .assertXPath("""$output/up-to-date/@n = 101 """, "return value is transformed document")
        .go
    }
  }
}