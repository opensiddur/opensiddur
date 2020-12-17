package org.opensiddur.api

import org.opensiddur.DbTest

trait CommonTestUser {
  val prolog =
    """xquery version '3.1';
      import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
       at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

      import module namespace ridx="http://jewishliturgy.org/modules/refindex"
        at "xmldb:exist:///db/apps/opensiddur-server/modules/refindex.xqm";
      import module namespace user="http://jewishliturgy.org/api/user"
        at "xmldb:exist:///db/apps/opensiddur-server/api/user.xqm";
      import module namespace magic="http://jewishliturgy.org/magic"
        at "xmldb:exist:///db/apps/opensiddur-server/magic/magic.xqm";

      declare namespace html="http://www.w3.org/1999/xhtml";
      declare namespace tei="http://www.tei-c.org/ns/1.0";
      declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
      declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";
      declare namespace http="http://expath.org/ns/http-client";
      declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

      """
}

class TestUser extends DbTest with CommonTestUser {
  override def beforeAll()  {
    super.beforeAll()

    setupUsers(4)
    setupResource("src/test/resources/api/user/xqtest2.xml", "xqtest2", "user", 2,
      None, Some("xqtest2"), Some("rw-r--r--"))
    setupResource("src/test/resources/api/user/xqtest3.xml", "xqtest3", "user", 3,
      None, Some("everyone"), Some("rw-rw-r--"))
    setupResource("src/test/resources/api/user/xqtest4.xml", "xqtest4", "user", 4,
      None, Some("everyone"), Some("rw-r--r--"))
    setupResource("src/test/resources/api/user/xqtest5.xml", "xqtest5", "user", 1,
      None, Some("everyone"), Some("rw-r--r--"))
  }

  override def afterAll()  {
    // tear down users that were created by tests
    teardownResource("xqtest1", "user", 1)
    teardownResource("xqtest2", "user", 2)
    teardownResource("xqtest3", "user", -1) // password gets changed
    teardownResource("xqtest4", "user", 4)
    teardownResource("xqtest5", "user", 1)
    teardownResource("not_a_real_contributors_profile", "user", 1)
    
    teardownUsers(6)

    super.afterAll()
  }

  override def beforeEach(): Unit = {
    super.beforeEach()
  }

  override def afterEach(): Unit = {
    super.afterEach()
  }

  describe("user:list") {
    it("lists users") {
      xq("""user:list("", 1, 100)""")
        .assertSearchResults
        .assertXPath("""count($output//html:*[@class="result"])>=4""", "returns at least 4 results")
        .assertXPath(
          """
          exists($output//html:li[@class="result"]/html:a[@class="document"]) and (
          every $d in $output//html:li[@class="result"]/html:a[@class="document"]
          satisfies exists($d/following-sibling::html:a[@class="alt"][@property="groups"])
          )""", "groups view is presented as an alternate")
        .assertXPath(
          """
          exists($output//html:li[@class="result"]/html:a[@class="document"]) and (
          every $d in $output//html:li[@class="result"]/html:a[@class="document"]
          satisfies exists($d/following-sibling::html:a[@class="alt"][@property="access"])
          )""", "access view is presented as an alternate")
        .go
    }

    it("queries users") {
      xq("""user:list("spike", 1, 100)""")
        .assertSearchResults
        .assertXPath("""count($output//html:*[@class="result"])>=2""", "returns at least 2 results")
        .go
    }
  }
  
  describe("user:get") {
    it("gets an existing user profile while authenticated") {
      xq("""user:get("xqtest4")/*""")
        .user("xqtest1")
        .assertXmlEquals("""<j:contributor xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
            <tei:idno xmlns:tei="http://www.tei-c.org/ns/1.0">xqtest4</tei:idno>
        </j:contributor>""")
        .go
    }
    
    it("returns 404 for a non-existing user profile (authenticated)") {
      xq("""user:get("doesnotexist")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("gets an existing user profile while unauthenticated") {
      xq("""user:get("xqtest4")/*""")
        .assertXmlEquals("""<j:contributor xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
            <tei:idno xmlns:tei="http://www.tei-c.org/ns/1.0">xqtest4</tei:idno>
        </j:contributor>""")
        .go
    }
    
    it("returns 404 for a non-existing user profile (unauthenticated)") {
      xq("""user:get("doesnotexist")""")
        .assertHttpNotFound
        .go
    }
  }
  
  describe("user:post-xml (unauthenticated)") {
    it("creates a new user") {
      xq(
        """user:post-xml(document {
        <new>
          <user>xqtest6</user>
          <password>xqtest6</password>
        </new>
      })""")
        .assertHttpCreated
        .assertXPath("""system:as-user("admin", $magic:password, sm:user-exists("xqtest6"))""", "user has been created")
        .assertXPath("""system:as-user("admin", $magic:password, sm:group-exists("xqtest6"))""", "group has been created")
        .assertXPath("""system:as-user("admin", $magic:password, sm:get-group-managers("xqtest6")="xqtest6")""", "user is a manager of its own group")
        .assertXPath("""doc-available("/db/data/user/xqtest6.xml")""", "profile has been created")
        .assertXPath("""doc("/db/data/user/xqtest6.xml")/j:contributor/tei:idno="xqtest6"""", "profile contains an idno equal to the user name")
        .assertXPath(
          """
          doc-available("/db/data/user/xqtest6.xml") and
          sm:get-permissions(xs:anyURI("/db/data/user/xqtest6.xml"))/*/(
          @owner = "xqtest6" and @group="xqtest6" and @mode="rw-r--r--"
          )""", "user profile permissions are correct")
        .go
    }

    it("fails to create a new user with a blank username") {
      xq("""user:post-xml(document {
        <new>
          <password>testuser3</password>
        </new>
      })""")
        .assertHttpBadRequest
        .go
    }

    it("fails to create a new user with a blank password") {
      xq("""user:post-xml(document {
        <new>
          <user>testuser4</user>
          <password/>
        </new>
      })""")
        .assertHttpBadRequest
        .go
    }

    it("fails to create a new user with a username containing an illegal character") {
      xq("""user:post-xml(document {
        <new>
          <user>test,user3</user>
          <password>testuser3</password>
        </new>
      })""")
        .assertHttpBadRequest
        .go
    }

    it("fails to create a new user that already exists") {
      xq("""user:post-xml(document {
        <new>
          <user>xqtest1</user>
          <password>xxxxxx</password>
        </new>
      })""")
        .assertHttpUnauthorized
        .go
    }
    
    it("fails to create a new user when the profile exists, even when the user does not") {
      xq("""user:post-xml(document {
        <new>
          <user>xqtest5</user>
          <password>xxxxxx</password>
        </new>
      })""")
        .assertHttpForbidden
        .go
    }
  }
  
  describe("user:post-xml (authenticated)") {
    it("changes a password") {
      xq(""" 
        user:post-xml(document {
          <change>
            <user>xqtest3</user>
            <password>xqtest3newpassword</password>
          </change>
        })
        """)
        .user("xqtest3")
        .assertHttpNoData
        .assertXPath("""xmldb:authenticate("/db", "xqtest3", "xqtest3newpassword")""", "password is changed")
        .go
    }

    it("fails to change the password for another user") {
      xq("""user:post-xml(document {
        <change>
          <user>xqtest3</user>
          <password>xqtest3password</password>
        </change>
      })""")
        .user("xqtest4")
        .assertHttpForbidden
        .go
    }

    it("fails to change the password for a missing username") {
      xq("""user:post-xml(document {
        <change>
          <password>xqtest4new</password>
        </change>
      })""")
        .user("xqtest4")
        .assertHttpBadRequest
        .go
    }

    it("fails to change the password for a missing password") {
      xq("""user:post-xml(document {
        <change>
          <user>xqtest4</user>
        </change>
      })""")
        .user("xqtest4")
        .assertHttpBadRequest
        .go
    }

    it("fails to change a username") {
      xq("""user:post-xml(document {
        <change>
          <user>xqtest400</user>
          <password>xqtest4</password>
        </change>
      })""")
        .user("xqtest4")
        .assertHttpForbidden
        .go
    }
  }
  
  describe("user:put (authenticated)") {
    it("allows editing a user's own profile") {
      xq(
        """user:put("xqtest2", document {
        <j:contributor>
          <tei:idno>xqtest2</tei:idno>
          <tei:name>Test User</tei:name>
        </j:contributor>
      })""")
        .user("xqtest2")
        .assertHttpNoData
        .assertXPath("""doc("/db/data/user/xqtest2.xml")/j:contributor/tei:name="Test User"""", "profile is edited")
        .go
    }
    
    it("refuses to change idno in a user's own profile") {
      xq(
        """user:put("xqtest2", document {
        <j:contributor>
          <tei:idno>notxqtest2</tei:idno>
          <tei:name>Test User</tei:name>
        </j:contributor>
      })""")
        .user("xqtest2")
        .assertHttpBadRequest
        .go
    }
    
    it("fails on invalid contributor data") {
      xq(
        """user:put("xqtest2", document {
        <j:contributor>
          <tei:idno>xqtest2</tei:idno>
          <tei:notallowed/>
        </j:contributor>
      })""")
        .user("xqtest2")
        .assertHttpBadRequest
        .go
    }
    
    it("fails to edit another user's profile") {
      xq(
        """user:put("xqtest1", document {
        <j:contributor>
          <tei:idno>xqtest1</tei:idno>
          <tei:name>Not Xq Test 1</tei:name>
        </j:contributor>
      })""")
        .user("xqtest2")
        .assertHttpForbidden
        .go
    }
    
    it("creates a non-user profile") {
      xq(
        """user:put("not_a_real_contributors_profile", document {
        <j:contributor>
            <tei:idno>not_a_real_contributors_profile</tei:idno>
            <tei:name>Not Real</tei:name>
        </j:contributor>
      })""")
        .user("xqtest1")
        .assertHttpCreated
        .assertXPath("""doc-available("/db/data/user/not_a_real_contributors_profile.xml")""", "profile created")
        .assertXPath("""sm:get-permissions(xs:anyURI("/db/data/user/not_a_real_contributors_profile.xml"))/*/(
          @owner="xqtest1" and @group="everyone" and @mode="rw-rw-r--"
          )""", "profile mode is correct")
        .go
    }
    
    it("edits a non-user profile") {
      xq("""user:put("xqtest5", document {
        <j:contributor>
          <tei:idno>xqtest5</tei:idno>
          <tei:name>Not A User</tei:name>
        </j:contributor>
      })""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath("""doc("/db/data/user/xqtest5.xml")/j:contributor/tei:name="Not A User"""", "profile edited")
        .assertXPath("""sm:get-permissions(xs:anyURI("/db/data/user/xqtest5.xml"))/*/(
          @owner="xqtest1" and @group="everyone" and @mode="rw-rw-r--"
          )""", "profile mode is correct")
        .go
    }
  }

  describe("user:put (unauthenticated)") {
    it("fails to edit a user profile") {
      xq(
        """user:put("xqtest2", document {
        <j:contributor>
          <tei:idno>xqtest2</tei:idno>
          <tei:name>Test User</tei:name>
        </j:contributor>
      })""")
        .assertHttpUnauthorized
        .go
    }

    it("fails to edit a non-user profile") {
      xq(
        """user:put("xqtest5", document {
        <j:contributor>
          <tei:idno>xqtest5</tei:idno>
          <tei:name>Is not a user</tei:name>
        </j:contributor>
      })""")
        .assertHttpUnauthorized
        .go
    }

    it("fails to create a non-user profile") {
      xq(
        """user:put("there_is_no_user_with_that_name", document {
        <j:contributor>
            <tei:idno>there_is_no_user_with_that_name</tei:idno>
            <tei:name>Not Real</tei:name>
        </j:contributor>
      })""")
        .assertHttpUnauthorized
        .go
    }
  }

  describe("user:delete (not authenticated)") {
    it("fails to delete a user") {
      xq("""user:delete("xqtest1")""")
        .assertHttpUnauthorized
        .go
    }

    it("fails to delete a non-user profile") {
      xq("""user:delete("xqtest5")""")
        .assertHttpUnauthorized
        .go
    }

    it("fails to delete a non-existent profile") {
      xq("""user:delete("doesnotexist")""")
        .assertHttpNotFound
        .go
    }
  }
}

class TestUserDelete extends DbTest with CommonTestUser {

  override def beforeEach(): Unit = {
    super.beforeEach()

    setupUsers(3)
    setupResource("src/test/resources/api/user/xqtest7.xml", "xqtest7", "user", 1,
      None, Some("everyone"), Some("rw-rw-r--"))
    setupResource("src/test/resources/api/user/Reference.xml", "Reference", "original", 1,
      Some("en"), Some("everyone"), Some("rw-rw-r--"))
  }

  override def afterEach(): Unit = {
    super.afterEach()

    teardownResource("Reference", "original", 1)
    teardownResource("xqtest7", "user", 1)
    teardownUsers(3)
  }

  describe("user:delete (authenticated)") {
    it("can delete a user's own profile") {
      xq("""user:delete("xqtest2")""")
        .user("xqtest2")
        .assertHttpNoData
        .assertXPath("""system:as-user("admin", $magic:password, not(sm:user-exists("xqtest2")))""", "user removed")
        .assertXPath("""system:as-user("admin", $magic:password, not(sm:get-groups()="xqtest2"))""", "group removed")
        .assertXPath("""not(doc-available("/db/data/user/xqtest2.xml"))""", "profile removed")
        .go
    }
    
    it("fails to delete another user") {
      xq("""user:delete("xqtest2")""")
        .user("xqtest1")
        .assertHttpForbidden
        .go
    }
    
    it("fails to delete a non-existent profile") {
      xq("""user:delete("doesnotexist")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
    
    it("successfully deletes a non-user profile") {
      xq("""user:delete("xqtest7")""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath("""not(doc-available("/db/data/user/xqtest7.xml"))""", "profile removed")
        .go
    }
    
    it("deletes a user, deprecates a profile, and returns references when the user has references") {
      xq("""user:delete("xqtest3")""")
        .user("xqtest3")
        .assertXPath("""$output/self::rest:response/http:response/@status = 200""", "status code is 200")
        .assertXPath("""ends-with($output/self::info//documents/document, "/api/data/original/Reference")""", "returns an info element with the referenced document")
        .assertXPath("""system:as-user("admin", $magic:password, not(sm:user-exists("xqtest3")))""", "user account removed")
        .assertXPath("""system:as-user("admin", $magic:password, not(sm:get-groups()="xqtest3"))""", "group removed")
        .assertXPath("""exists(doc("/db/data/user/xqtest3.xml")/j:contributor[tei:idno="xqtest3"][tei:name="Deleted user"])""", "profile changed to anonymous profile")
        .assertXPath("""system:as-user("admin", $magic:password, sm:get-permissions(xs:anyURI("/db/data/user/xqtest3.xml")))/*/@owner="admin"""", "profile owned by admin")
        .assertXPath("""system:as-user("admin", $magic:password, sm:get-permissions(xs:anyURI("/db/data/user/xqtest3.xml")))/*/@group="everyone"""", "profile owned by group everyone")
        .assertXPath("""system:as-user("admin", $magic:password, sm:get-permissions(xs:anyURI("/db/data/user/xqtest3.xml")))/*/@mode="rw-rw-r--"""", "profile permissions are 664")
        .go
    }
  }
}