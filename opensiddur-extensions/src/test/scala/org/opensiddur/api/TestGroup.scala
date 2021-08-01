package org.opensiddur.api

import org.opensiddur.DbTest

class BaseTestGroup extends DbTest {
  /** imports, namespaces and variables */
  override val prolog: String =
    """xquery version '3.1';

import module namespace grp="http://jewishliturgy.org/api/group"
      at "xmldb:exist:///db/apps/opensiddur-server/api/group.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:///db/apps/opensiddur-server/magic/magic.xqm";
import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:///db/apps/opensiddur-server/test/tcommon.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace g="http://jewishliturgy.org/ns/group/1.0";
declare namespace http="http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare variable $local:valid := document {
                    <g:group>
                      <g:member manager="true">xqtest1</g:member>
                      <g:member>testuser3</g:member>
                      <g:member>testuser4</g:member>
                      <g:member>testuser5</g:member>
                      <g:member>testuser6</g:member>
                    </g:group>
                  };

declare variable $local:invalid := document {
                      <g:group>
                        <g:invalid/>
                      </g:group>
                    };

"""

  override def beforeAll: Unit = {
    super.beforeAll

    setupUsers(1)

    xq("""system:as-user("admin", $magic:password, (
                 let $new-group :=
                  if (sm:group-exists("grouptests")) then ()
                  else sm:create-group("grouptests", "xqtest1", "")
                 let $user := sm:add-group-member("grouptests", "xqtest1")
                 let $new-group2 :=
                  if (sm:group-exists("grouptests2")) then ()
                  else sm:create-group("grouptests2", "admin", "")
                 for $i in 3 to 7
                 let $user :=
                  if (sm:user-exists("testuser" || $i)) then ()
                  else sm:create-account(
                   "testuser" || $i, "testuser" || $i,
                   ("everyone", "grouptests"[$i <= 5])
                 )
                 return ()
               ))""")
      .go
  }

  override def afterAll(): Unit = {
    xq("""system:as-user("admin", $magic:password, (
                 for $i in 3 to 7
                 let $r := if (sm:group-exists("testuser" || $i)) then sm:remove-group-member("testuser" || $i, "admin") else ()
                 return (
                  if (sm:user-exists("testuser" || $i)) then sm:remove-account("testuser" || $i) else (),
                   if (sm:group-exists("testuser" || $i)) then sm:remove-group("testuser" || $i) else ()
                 ),
                 if (sm:group-exists("grouptests"))
                 then (
                   sm:remove-group-member("grouptests", "xqtest1"),
                   sm:remove-group-manager("grouptests", "xqtest1"),
                   sm:remove-group-member("grouptests", "admin"),
                   sm:remove-group("grouptests")
                 )
                 else (),
                 if (sm:group-exists("grouptests2"))
                 then (
                   sm:remove-group-member("grouptests2", "admin"),
                   sm:remove-group("grouptests2")
                 )
                 else ()
               ))""")
      .go

    teardownUsers(1)
    super.afterAll()
  }
}

class TestGroup extends BaseTestGroup {

  describe("grp:list") {
    it("lists all groups") {
      xq("""grp:list(1, 100)""")
        .assertXPath("""count($output//*[@class="results"]/html:li[@class="result"])>=7""", "returns at least 7 results")
        .go
    }

    it("lists only 2 groups when limited") {
      xq("""grp:list(1, 2)""")
        .assertXPath("""count($output//*[@class="results"]/html:li[@class="result"])=2""", "returns exactly 2 results")
        .go
    }
  }

  describe("grp:get-xml()") {
    it("Gets members of an existing group") {
      xq("""grp:get-xml("grouptests")""")
        .user("xqtest1")
        .assertXmlEquals("""<g:group xmlns:g="http://jewishliturgy.org/ns/group/1.0">
                                       <g:member>testuser3</g:member>
                                       <g:member>testuser4</g:member>
                                       <g:member>testuser5</g:member>
                                       <g:member manager="true">xqtest1</g:member>
                                     </g:group>""")
        .go
    }

    it("Fails to get members of a non-existing group") {
      xq("""grp:get-xml("doesnotexist")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("fails when unauthenticated for an existing group") {
      xq("""grp:get-xml("grouptests")""")
        .assertHttpUnauthorized
        .go
    }

    it("fails when unauthenticated for an nonexisting group") {
      xq("""grp:get-xml("doesnotexist")""")
        .assertHttpUnauthorized
        .go
    }

  }

  describe("grp:get-html()") {
    it("gets members of an existing group when authenticated") {
      xq("""grp:get-html("grouptests")""")
        .user("xqtest1")
        .assertXPath("""$output/self::html:html/html:body/*[@class="results"]/html:li[@class="result"]/html:a[@class="document"]""", "returns an HTML list of members")
        .assertXPath("""count($output//html:a[@property="manager"]) = 1""", "managers are marked with @property")
        .go
    }

    it("fails to get members of a non-existing group") {
      xq("""grp:get-html("doesnotexist")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("fails when unauthenticated for an existing group") {
      xq("""grp:get-html("grouptests")""")
        .assertHttpUnauthorized
        .go
    }

    it("fails when unauthenticated for an nonexisting group") {
      xq("""grp:get-html("doesnotexist")""")
        .assertHttpUnauthorized
        .go
    }
  }

  describe("grp:get-user-groups()") {
    it("gets groups for an existing user") {
      xq("""grp:get-user-groups("xqtest1")""")
        .user("xqtest1")
        .assertXPath("""$output/self::html:html/html:body/*[@class="results"]/html:li[@class="result"]/html:a[@class="document"]""", "return an HTML list of groups")
        .assertXPath("""exists($output//html:a[@property="manager"])""", "return the manager property on managed groups")
        .assertXPath("""count($output//html:li[@class="result"]) = 3""", "returns exactly 3 groups (xqtest1, everyone and grouptests)")
        .go
    }

    it("fails for a nonexisting user") {
      xq("""grp:get-user-groups("doesnotexist")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("fails when unauthenticated for an existing user") {
      xq("""grp:get-user-groups("xqtest1")""")
        .assertHttpUnauthorized
        .go
    }

    it("fails when unauthenticated for an nonexisting user") {
      xq("""grp:get-user-groups("doesnotexist")""")
        .assertHttpUnauthorized
        .go
    }
  }
}

class TestGroupPut extends BaseTestGroup {

  override def beforeEach(): Unit = {
    super.beforeAll()
    super.beforeEach()
  }

  override def afterEach(): Unit = {
    super.afterEach()
    super.afterAll()
  }

  override def afterAll: Unit = {
    xq(
      """system:as-user("admin", $magic:password, (
        if (sm:get-groups()="grouptestsnew")
        then (
          for $user in sm:get-group-members("grouptestsnew")
          let $removed := sm:remove-group-member("grouptestsnew", $user)
          return (),
          sm:remove-group("grouptestsnew")
        )
        else ()
        ))""").go

    super.afterAll()
  }

  describe("grp:put()") {
    it("creates a new group") {
      xq("""grp:put("grouptestsnew", $local:valid)""")
        .user("xqtest1")
        .assertHttpCreated
        .assertXPath("""grp:get-groups()="grouptestsnew" """, "group has been created")
        .assertXPath(
          """every $m in $local:valid//g:member[xs:boolean(@manager)] satisfies grp:get-group-managers("grouptestsnew")=$m""", "group managers are as specified")
        .assertXPath("""every $m in $local:valid//g:member[not(xs:boolean(@manager))] satisfies grp:get-group-members("grouptestsnew")=$m""", "group members are as specified")
        .assertXPath("""grp:get-group-managers("grouptestsnew")="admin" """, "admin is a group manager")
        .go
    }

    it("adds a member to an existing group") {
      xq(
        """grp:put("grouptests", document {
          <g:group>
            {$local:valid//g:member}
            <g:member>testuser6</g:member>
            </g:group>
            })""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath("""grp:get-group-members("grouptests")="testuser6" """, "the new user has been added to the group")
        .go
    }

    it("removes a member of an existing group") {
      xq(
        """ grp:put("grouptests", document {
            <g:group>
            {$local:valid//g:member[not(.="testuser5")]}
            </g:group>
            })""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath("""not(grp:get-group-members("grouptests")="testuser5")""")
        .go

    }

    it("adds a manager to an existing group") {
      xq(
        """grp:put("grouptests", document {
            <g:group>
            {$local:valid//g:member[not(.="testuser5")]}
            <g:member manager="true">testuser5</g:member>
            </g:group>
            })""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath("""grp:get-group-managers("grouptests")="testuser5" """, "the member is now a manager")
        .go
    }

    it("removes a manager for an existing group") {
      xq(
        """grp:put("grouptests", document {
          |  <g:group>
          |  {$local:valid//g:member[not(.="xqtest1")]}
          |  <g:member>xqtest1</g:member>
          |  </g:group>
          |  })""".stripMargin)
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath("""not(grp:get-group-managers("grouptests")="xqtest1")""", "the member is no longer a manager")
        .assertXPath("""grp:get-group-members("grouptests")="xqtest1" """, "the member is still a member")
        .go
    }

    it("does not remove admin from group manager privileges") {
      xq("""grp:put("grouptests", $local:valid)""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath("""grp:get-group-managers("grouptests")="admin" """, "admin is still a group manager")
        .go
    }

    it("fails with invalid group XML") {
      xq("""grp:put("grouptests", $local:invalid)""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

    it("fails for an existing group of which the user is not a manager") {
      xq("""grp:put("grouptests2", $local:valid) """)
        .user("xqtest1")
        .assertHttpForbidden
        .go
    }

    it("fails when unauthenticated for an existing group") {
      xq("""grp:put("grouptests", $local:valid)""")
        .assertHttpUnauthorized
        .go
    }

    it("fails when unauthenticated for a non existing group") {
      xq("""grp:put("doesnotexist", $local:valid)""")
        .assertHttpUnauthorized
        .go
    }
  }
}

class TestGroupDelete extends BaseTestGroup {
  override def beforeEach(): Unit = {
    super.beforeAll()
    super.beforeEach()
  }

  override def afterEach(): Unit = {
    super.afterEach()
    super.afterAll()
  }

  describe("grp:delete()") {
    it("deletes an existing group") {
      xq("""grp:delete("grouptests")""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPath("""not(grp:get-groups()="grouptests")""", "group is deleted")
        .assertXPath("""not(system:as-user("xqtest1", "xqtest1", sm:get-user-groups("xqtest1"))="grouptests")""", "user is not a member of the group")
        .go
    }

    it("fails when unauthenticated for an existing group") {
      xq("""grp:delete("grouptests")""")
        .assertHttpUnauthorized
        .go
    }

    it("fails when unauthenticated for a non existing group") {
      xq("""grp:delete("doesnotexist")""")
        .assertHttpUnauthorized
        .go
    }

    it("fails when the user requesting the deletion is not a manager") {
      xq("""grp:delete("grouptests")""")
        .user("testuser6")
        .assertHttpForbidden
        .go
    }

    it("fails for a nonexistent group") {
      xq("""grp:delete("doesnotexist")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
  }

}