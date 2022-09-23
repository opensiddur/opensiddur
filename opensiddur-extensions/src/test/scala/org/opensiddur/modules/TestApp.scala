package org.opensiddur.modules

import org.opensiddur.DbTest
import scala.xml.XML

class TestApp extends DbTest {
  override val prolog: String =
    """xquery version '3.1';
  import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:///db/apps/opensiddur-server/magic/magic.xqm";
  import module namespace app="http://jewishliturgy.org/modules/app"
  at "xmldb:exist:///db/apps/opensiddur-server/modules/app.xqm";
  import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

  declare namespace html="http://www.w3.org/1999/xhtml";
  declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
  declare namespace error="http://jewishliturgy.org/errors";
  """

  override def beforeAll: Unit = {
    super.beforeAll()
    setupUsers(1)
  }

  override def afterAll(): Unit = {
    teardownUsers(1)
    super.afterAll()
  }

  describe("app:get-version") {
    it("returns the same version as the package") {
      val version = XML.loadFile("../opensiddur-server/src/expath-pkg.xml").attributes("version").toString()
      val returnedVersion = xq("""app:get-version()""")
        .go
      assert(returnedVersion.head == version)
    }
  }

  describe("app:auth-user") {
    it("returns an empty sequence when not logged in") {
      xq("app:auth-user()")
        .assertEmpty
        .go
    }

    it("returns the authenticated user when as-user-ed") {
      xq("""app:auth-user()""")
        .user("xqtest1")
        .assertXPath("$output='xqtest1'")
        .go
    }

    it("returns the authenticated user when logged in with HTTP Basic") {
      xqRest("""app:auth-user()""")
        .user("xqtest1")
        .assertXPath("$output='xqtest1'")
        .go
    }

    it("returns the authenticated user from the session") {
      xqRest(
        """
           let $create := session:create()
           let $session := app:login-credentials('xqtest1', 'xqtest1')
           return app:auth-user()""")
        .assertXPath("session:exists()", "There must be a session for this test to be meaningful")
        .assertXPath("$output='xqtest1'")
        .go
    }
  }
}
