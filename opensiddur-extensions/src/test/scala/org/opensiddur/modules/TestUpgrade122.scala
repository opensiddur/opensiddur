package org.opensiddur.modules

import org.opensiddur.DbTest

class TestUpgrade122 extends DbTest {
  override val prolog: String =
    """xquery version '3.1';

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";
import module namespace deepequality="http://jewishliturgy.org/modules/deepequality"
  at "xmldb:exist:/db/apps/opensiddur-server/modules/deepequality.xqm";

import module namespace upg122="http://jewishliturgy.org/modules/upgrade122"
  at "xmldb:exist:/db/apps/opensiddur-server/modules/upgrade122.xqm";

import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "xmldb:exist:/db/apps/opensiddur-server/modules/refindex.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:/db/apps/opensiddur-server/magic/magic.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
    """

  override def beforeAll: Unit = {
    super.beforeAll()
    setupUsers(1)
    setupResource("src/test/resources/modules/upgrade122/test_file.xml", "test_file", "original", 1)
  }

  override def afterAll(): Unit = {
    teardownResource("test_file", "original", 1)
    teardownUsers(1)
    super.afterAll()
  }

  describe("upg122:upgrade122") {
    it("transforms a file") {
      val expected = readXmlFile("src/test/resources/modules/upgrade122/transformed.xml")

      xq("""upg122:upgrade122(doc("/db/data/original/test_file.xml"))/*""")
        .assertXmlEquals(expected)
        .go
    }
  }
}
