package org.opensiddur.api

import org.opensiddur.DbTest

class BaseTestLogin extends DbTest {
  /** imports, namespaces and variables */
  override val prolog: String =
    """xquery version '3.1';

import module namespace login="http://jewishliturgy.org/api/login"
      at "xmldb:exist:///db/apps/opensiddur-server/api/login.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "xmldb:exist:///db/apps/opensiddur-server/modules/app.xqm";
import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:///db/apps/opensiddur-server/test/tcommon.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace http = 'http://expath.org/ns/http-client';

"""

  override def beforeAll: Unit = {
    super.beforeAll

    setupUsers(1)
  }

  override def afterAll(): Unit = {
    teardownUsers(1)

    super.afterAll()
  }
}
  
class TestLogin extends BaseTestLogin {

  describe("login:get-xml()") {
    it("returns an empty login element when not logged in") {
      xq("""login:get-xml()""")
        .assertXmlEquals("""<login/>""")
        .go
    }

    it("returns the name of the logged in user when logged in") {
      xq("""login:get-xml()""")
        .user("xqtest1")
        .assertXmlEquals("""<login>xqtest1</login>""")
        .go
    }
  }

  describe("login:get-html()") {
    it("returns an empty login name when not logged in") {
      xq("""login:get-html((), (), ())""")
        .assertSerializesAs("xhtml")
        .assertXPath("""$output//html:div[@class='result'][count(*) = 0]""", "empty login name")
        .go
    }

    it("returns a record for the logged in user when logged in") {
      xq("""login:get-html((), (), ())""")
        .user("xqtest1")
        .assertSerializesAs("xhtml")
        .assertXPath("""$output//html:div[@class='result'] = 'xqtest1' """, "empty login name")
        .go
    }
  }
}

class TestLoginPost extends BaseTestLogin {
  override def beforeEach: Unit = {
    super.beforeEach()
    
    xq("""if (session:exists()) then (
       session:create(), 
       session:clear(),
       let $null := xmldb:login("/db", "guest", "guest")
       return ()) else ()""")
      .go
  }
  
  override def afterEach: Unit = {
    xq("""session:invalidate()""")
      .go
    
    super.afterEach()
  }
  
  describe("login:post-xml()") {
    it("starts a session when given a user and password") {
      xq("""login:post-xml(document{
           <login>
            <user>xqtest1</user>
            <password>xqtest1</password>
           </login>
           }, ())""")
        .assertHttpNoData
        .assertXPath("""if (session:exists()) then app:auth-user()="xqtest1" else true() """, "user is set")
        .assertXPath("""if (session:exists()) then app:auth-password()="xqtest1" else true()""", "password is set")
        .go
    }

    it("fails with valid user and invalid password") {
      xq("""login:post-xml(document{
           <login>
            <user>xqtest1</user>
            <password>badpassword</password>
           </login>
           }, ())""")
        .assertHttpBadRequest
        .assertXPath("""empty(app:auth-user())""", "user is not set")
        .assertXPath("""empty(app:auth-password())""", "password is not set")
        .go
    }

    it("fails with an invalid user") {
      xq("""login:post-xml(document{
           <login>
            <user>baduser</user>
            <password>badpassword</password>
           </login>
           }, ())""")
        .assertHttpBadRequest
        .assertXPath("""empty(app:auth-user())""", "user is not set")
        .assertXPath("""empty(app:auth-password())""", "password is not set")
        .go
    }

    it("fails when no user is given") {
      xq("""login:post-xml(document{
           <login>
            <password>badpassword</password>
           </login>
           }, ())""")
        .assertHttpBadRequest
        .assertXPath("""empty(app:auth-user())""", "user is not set")
        .assertXPath("""empty(app:auth-password())""", "password is not set")
        .go
    }

    it("fails when no password is given") {
      xq("""login:post-xml(document{
           <login>
            <user>xqtest1</user>
           </login>
           }, ())""")
        .assertHttpBadRequest
        .assertXPath("""empty(app:auth-user())""", "user is not set")
        .assertXPath("""empty(app:auth-password())""", "password is not set")
        .go
    }
  }

  describe("login:post-form()") {
    it("logs in with valid user and password") {
      xq("""login:post-form("xqtest1", "xqtest1", ())""")
        .assertHttpNoData
        .assertXPath("""if (session:exists()) then app:auth-user()="xqtest1" else true() """, "user is set")
        .assertXPath("""if (session:exists()) then app:auth-password()="xqtest1" else true()""", "password is set")
        .go
    }

    it("fails with valid user and invalid password") {
      xq("""login:post-form("xqtest1", "badpassword", ())""")
        .assertHttpBadRequest
        .assertXPath("""empty(app:auth-user())""", "user is not set")
        .assertXPath("""empty(app:auth-password())""", "password is not set")
        .go
    }

    it("fails with invalid user") {
      xq("""login:post-form("baduser", "xqtest1", ())""")
        .assertHttpBadRequest
        .assertXPath("""empty(app:auth-user())""", "user is not set")
        .assertXPath("""empty(app:auth-password())""", "password is not set")
        .go
    }

    it("fails with missing user") {
      xq("""login:post-form((), "xqtest1", ())""")
        .assertHttpBadRequest
        .assertXPath("""empty(app:auth-user())""", "user is not set")
        .assertXPath("""empty(app:auth-password())""", "password is not set")
        .go
    }

    it("fails with missing password") {
      xq("""login:post-form("xqtest1", (), ())""")
        .assertHttpBadRequest
        .assertXPath("""empty(app:auth-user())""", "user is not set")
        .assertXPath("""empty(app:auth-password())""", "password is not set")
        .go
    }
  }
}

class TestLogout extends BaseTestLogin {
  override def beforeEach(): Unit = {
    super.beforeEach()

    xq("""if (session:exists()) then (
         session:create(),
         session:clear(),
         let $null := xmldb:login("/db","xqtest1","xqtest1")
         return app:login-credentials("xqtest1", "xqtest1")
         ) else ()""")
      .go
  }

  override def afterEach(): Unit = {
    xq("""if (session:exists())
         then session:invalidate()
         else ()""")
      .go

    super.afterEach()
  }

  describe("login:delete()") {
    it("logs out a user") {
      xq("""login:delete()""")
        .assertHttpNoData
        .assertXPath("""empty(app:auth-user())""", "user is not set")
        .assertXPath("""empty(app:auth-password())""", "password is not set")
        .go
    }
  }

  describe("login:get-logout()") {
    it("logs out a user") {
      xq("""login:get-logout()""")
        .assertHttpNoData
        .assertXPath("""empty(app:auth-user())""", "user is not set")
        .assertXPath("""empty(app:auth-password())""", "password is not set")
        .go
    }
  }

  describe("login:post-logout()") {
    it("logs out a user") {
      xq("""login:post-logout()""")
        .assertHttpNoData
        .assertXPath("""empty(app:auth-user())""", "user is not set")
        .assertXPath("""empty(app:auth-password())""", "password is not set")
        .go
    }
  }
}
