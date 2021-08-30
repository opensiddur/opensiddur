package org.opensiddur.modules

import org.opensiddur.DbTest

class TestAccess extends DbTest {
  /** imports, namespaces and variables */
  override val prolog: String =
    """xquery version '3.1';
  import module namespace magic="http://jewishliturgy.org/magic"
    at "xmldb:exist:///db/apps/opensiddur-server/magic/magic.xqm";
  import module namespace acc="http://jewishliturgy.org/modules/access"
    at "xmldb:exist:///db/apps/opensiddur-server/modules/access.xqm";
  import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";
  import module namespace data="http://jewishliturgy.org/modules/data"
    at "xmldb:exist:///db/apps/opensiddur-server/modules/data.xqm";

  declare namespace a="http://jewishliturgy.org/ns/access/1.0";
  declare namespace html="http://www.w3.org/1999/xhtml";
  declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
  declare namespace error="http://jewishliturgy.org/errors";
"""

  override def beforeAll() = {
    setupUsers(2)

    super.beforeAll()
  }

  override def beforeEach() = {
    setupResource("""<a/>""", "test_one", "original", 1,
      Some("en"), Some("dba"), Some("rw-r--r--"), firstParamIsContent = true)

    super.beforeEach()
  }

  override def afterEach() = {
    teardownResource("test_one", "original", 1)

    super.afterEach()
  }

  override def afterAll() = {
    teardownUsers(2)

    super.afterAll()
  }

  describe("acc:get-access()") {
    it("returns basic permissions") {
      xq("""acc:get-access(data:doc("/data/original/test_one"))/*""")
        .user("xqtest1")
        .assertXmlEquals(
          """<a:access xmlns:a="http://jewishliturgy.org/ns/access/1.0">
                                          <a:you read="true" write="true" chmod="true" relicense="false"/>
                                          <a:owner>xqtest1</a:owner>
                                          <a:group write="false">dba</a:group>
                                          <a:world read="true" write="false"/>
                                       </a:access>""")
        .go
    }

    it("returns a grant structure for a group r/w grant") {
      xq(
        """
         let $uri := document-uri(data:doc("/data/original/test_one"))
         let $grant := system:as-user("admin", $magic:password,
          sm:add-group-ace($uri, "everyone", true(), "rw-")
        )
        return acc:get-access(data:doc("/data/original/test_one"))/*""")
        .user("xqtest1")
        .assertXPathEquals("$output/a:grant/a:grant-group[@write='true']='everyone'", "read-write grant is recorded")
        .go
    }

    it("returns a grant structure for a group r/o grant") {
      xq(
        """
         let $uri := document-uri(data:doc("/data/original/test_one"))
         let $grant := system:as-user("admin", $magic:password,
        sm:add-group-ace($uri, "everyone", true(), "r--")
        )
        return acc:get-access(data:doc("/data/original/test_one"))/*""")
        .user("xqtest1")
        .assertXPathEquals("$output/a:grant/a:grant-group[@write='false']='everyone'", "read-only grant is recorded")
        .go
    }

    it("returns a grant structure for a user r/w grant") {
      xq(
        """
         let $uri := document-uri(data:doc("/data/original/test_one"))
         let $grant := system:as-user("admin", $magic:password,
        sm:add-user-ace($uri, "xqtest2", true(), "rw-")
        )
        return acc:get-access(data:doc("/data/original/test_one"))/*""")
        .user("xqtest1")
        .assertXPathEquals("$output/a:grant/a:grant-user[@write='true']='xqtest2'", "read-write grant is recorded")
        .go
    }

    it("returns a grant structure for a user r/o grant") {
      xq(
        """
         let $uri := document-uri(data:doc("/data/original/test_one"))
         let $grant := system:as-user("admin", $magic:password,
        sm:add-user-ace($uri, "xqtest2", true(), "r--")
        )
        return acc:get-access(data:doc("/data/original/test_one"))/*""")
        .user("xqtest1")
        .assertXPathEquals("$output/a:grant/a:grant-user[@write='false']='xqtest2'", "read-only grant is recorded")
        .go
    }

    it("returns a grant structure for a group r/w deny") {
      xq(
        """
         let $uri := document-uri(data:doc("/data/original/test_one"))
         let $grant := system:as-user("admin", $magic:password, (
        sm:chgrp($uri, "everyone"),
        sm:chmod($uri, "rw-rw-r--"),
        sm:add-group-ace($uri, "guest", false(), "rw-")
      ))
        return acc:get-access(data:doc("/data/original/test_one"))/*""")
        .user("xqtest1")
        .assertXPathEquals("$output/a:deny/a:deny-group[@read='false']='guest'", "read-write deny is recorded")
        .go
    }

    it("returns a grant structure for a group w/o deny") {
      xq(
        """
         let $uri := document-uri(data:doc("/data/original/test_one"))
         let $grant := system:as-user("admin", $magic:password, (
        sm:chgrp($uri, "everyone"),
        sm:chmod($uri, "rw-rw-r--"),
        sm:add-group-ace($uri, "guest", false(), "-w-")
      ))
        return acc:get-access(data:doc("/data/original/test_one"))/*""")
        .user("xqtest1")
        .assertXPathEquals("$output/a:deny/a:deny-group[@read='true']='guest'", "write-only deny is recorded")
        .go
    }

    it("returns a grant structure for a user r/w deny") {
      xq(
        """
           let $uri := document-uri(data:doc("/data/original/test_one"))
           let $grant := system:as-user("admin", $magic:password, (
          sm:chgrp($uri, "everyone"),
          sm:chmod($uri, "rw-rw-r--"),
          sm:add-user-ace($uri, "xqtest2", false(), "rw-")
        ))
          return acc:get-access(data:doc("/data/original/test_one"))/*""")
        .user("xqtest1")
        .assertXPathEquals("$output/a:deny/a:deny-user[@read='false']='xqtest2'", "read-write deny is recorded")
        .go
    }

    it("returns a grant structure for a user w/o deny") {
      xq(
        """
           let $uri := document-uri(data:doc("/data/original/test_one"))
           let $grant := system:as-user("admin", $magic:password, (
          sm:chgrp($uri, "everyone"),
          sm:chmod($uri, "rw-rw-r--"),
          sm:add-user-ace($uri, "xqtest2", false(), "-w-")
        ))
          return acc:get-access(data:doc("/data/original/test_one"))/*""")
        .user("xqtest1")
        .assertXPathEquals("$output/a:deny/a:deny-user[@read='true']='xqtest2'", "write-only deny is recorded")
        .go
    }
  }

  describe("acc:set-access()") {
    it("sets general parameters") {
      xq(
        """
         let $uri := document-uri(data:doc("/data/original/test_one"))
         let $grant := system:as-user("admin", $magic:password, (
          sm:chown($uri, "xqtest1"),
          sm:chgrp($uri, "dba"),
          sm:chmod($uri, "rw-r--rw-")
        ))
        return acc:set-access(doc($resource),
          <a:access>
            <a:owner>xqtest1</a:owner>
            <a:group write="true">everyone</a:group>
            <a:world read="true" write="false"/>
          </a:access>)""")
        .user("xqtest1")
        .assertXPathEquals("""sm:get-permissions(document-uri(data:doc("/data/original/test_one")))/*/@owner="xqtest1" """, "owner is set")
        .assertXPathEquals("""sm:get-permissions(document-uri(data:doc("/data/original/test_one")))/*/@group="everyone" """, "group is set")
        .assertXPathEquals("""sm:get-permissions(document-uri(data:doc("/data/original/test_one")))/*/@mode="rw-rw-r--" """, "permissions are set")
        .go
    }

    it("sets access to share with a group") {
      xq(
        """
         let $resource := data:doc("/data/original/test_one")
        return acc:set-access(doc($resource),
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world read="true" write="false"/>
          <a:grant>
            <a:grant-group write="true">guest</a:grant-group>
          </a:grant>
        </a:access>)
        """)
        .user("xqtest1")
        .assertXPathEquals("""sm:get-permissions(xs:anyURI($resource))//sm:ace
                                     [@target="GROUP"][@who="guest"][@access_type="ALLOWED"]/@mode="rw-" """, "group share is present and has r/w access")
        .go
    }

    it("sets access to share with a group r/o") {
      xq(
        """
         let $resource := data:doc("/data/original/test_one")
        return acc:set-access(doc($resource),
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world read="true" write="false"/>
          <a:grant>
            <a:grant-group write="false">guest</a:grant-group>
          </a:grant>
        </a:access>)
        """)
        .user("xqtest1")
        .assertXPathEquals("""sm:get-permissions(xs:anyURI($resource))//sm:ace
        [@target="GROUP"][@who="guest"][@access_type="ALLOWED"]/@mode="r--" """, "group share is present and has r/o access")
        .go
    }

    it("sets access to share with a user r/w") {
      xq(
        """
         let $resource := data:doc("/data/original/test_one")
        return acc:set-access(doc($resource),
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world read="true" write="false"/>
          <a:grant>
            <a:grant-user write="true">guest</a:grant-user>
          </a:grant>
        </a:access>)
        """)
        .user("xqtest1")
        .assertXPathEquals("""sm:get-permissions(xs:anyURI($resource))//sm:ace
        [@target="USER"][@who="guest"][@access_type="ALLOWED"]/@mode="rw-" """, "user share is present and has r/w access")
        .go
    }

    it("sets access to share with a user r/o") {
      xq(
        """
         let $resource := data:doc("/data/original/test_one")
        return acc:set-access(doc($resource),
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world read="true" write="false"/>
          <a:grant>
            <a:grant-user write="false">guest</a:grant-user>
          </a:grant>
        </a:access>)
        """)
        .user("xqtest1")
        .assertXPathEquals("""sm:get-permissions(xs:anyURI($resource))//sm:ace
        [@target="USER"][@who="guest"][@access_type="ALLOWED"]/@mode="r--" """, "user share is present and has r/o access")
        .go
    }

    it("sets access to deny a group r/w") {
      xq(
        """
         let $resource := data:doc("/data/original/test_one")
        return acc:set-access(doc($resource),
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world read="true" write="false"/>
          <a:deny>
            <a:deny-group read="false">guest</a:deny-group>
          </a:deny>
        </a:access>)
        """)
        .user("xqtest1")
        .assertXPathEquals("""sm:get-permissions(xs:anyURI($resource))//sm:ace
        [@target="GROUP"][@who="guest"][@access_type="DENIED"]/@mode="rw-" """, "group deny is present and covers r/w access")
        .go
    }

    it("sets access to deny a group w/o") {
      xq(
        """
         let $resource := data:doc("/data/original/test_one")
        return acc:set-access(doc($resource),
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world read="true" write="false"/>
          <a:deny>
            <a:deny-group read="true">guest</a:deny-group>
          </a:deny>
        </a:access>)
        """)
        .user("xqtest1")
        .assertXPathEquals("""sm:get-permissions(xs:anyURI($resource))//sm:ace
        [@target="GROUP"][@who="guest"][@access_type="DENIED"]/@mode="-w-" """, "group deny is present and covers w/o access")
        .go
    }

    it("sets access to deny a user r/w") {
      xq(
        """
         let $resource := data:doc("/data/original/test_one")
        return acc:set-access(doc($resource),
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world read="true" write="false"/>
          <a:deny>
            <a:deny-user read="false">guest</a:deny-user>
          </a:deny>
        </a:access>)
        """)
        .user("xqtest1")
        .assertXPathEquals("""sm:get-permissions(xs:anyURI($resource))//sm:ace
        [@target="USER"][@who="guest"][@access_type="DENIED"]/@mode="rw-" """, "user deny is present and covers r/w access")
        .go
    }

    it("sets access to deny a user w/o") {
      xq(
        """
         let $resource := data:doc("/data/original/test_one")
        return acc:set-access(doc($resource),
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world read="true" write="false"/>
          <a:deny>
            <a:deny-user read="true">guest</a:deny-user>
          </a:deny>
        </a:access>)
        """)
        .user("xqtest1")
        .assertXPathEquals("""sm:get-permissions(xs:anyURI($resource))//sm:ace
        [@target="USER"][@who="guest"][@access_type="DENIED"]/@mode="-w-" """, "user deny is present and covers w/o access")
        .go
    }

    it("fails to set access unauthenticated") {
      xq(
        """
         let $resource := data:doc("/data/original/test_one")
        return acc:set-access(doc($resource),
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world read="true" write="false"/>
        </a:access>)
        """)
        .assertThrows("error:UNAUTHORIZED")
        .go
    }

    it("fails to set access with incorrect authentication") {
      xq(
        """
         let $resource := data:doc("/data/original/test_one")
        return acc:set-access(doc($resource),
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world read="true" write="false"/>
        </a:access>)
        """)
        .user("xqtest2")
        .assertThrows("error:FORBIDDEN")
        .go
    }

    it("fails to set access with an invalid access structure") {
      xq(
        """
         let $resource := data:doc("/data/original/test_one")
        return acc:set-access(doc($resource),
        <a:access>
          <a:invalid/>
        </a:access>)
        """)
        .user("xqtest1")
        .assertThrows("error:VALIDATION")
        .go
    }
  }

  describe("acc:get-access-as-user()") {
    it("returns an access structure when called as the same user") {
      xq("""acc:get-access-as-user(data:doc("/data/original/test_one"), "xqtest1")/*""")
        .user("xqtest1")
        .assertXmlEquals("""<a:user-access xmlns:a="http://jewishliturgy.org/ns/access/1.0"
                    user="xqtest1" read="true"
                                                      write="true"
                                                      chmod="true"
                                                      relicense="false"/>""")
        .go
    }

    it("returns an access structure when called as a different user") {
      xq(
        """
           let $resource := data:doc("/data/original/test_one")
           let $grant := system:as-user("admin", $magic:password,
          sm:chmod(document-uri($resource), "rw-r--r--")
        )
        return acc:get-access-as-user(doc($resource), "xqtest2")/*
          """)
        .user("xqtest1")
        .assertXmlEquals("""<a:user-access xmlns:a="http://jewishliturgy.org/ns/access/1.0"
                    user="xqtest2" read="true"
                                                      write="false"
                                                      chmod="false"
                                                      relicense="false"/>""")
        .go
    }

    it("returns an error when the requested user is nonexistent") {
      xq("""acc:get-access-as-user(doc($resource), "doesnotexist")""")
        .user("xqtest1")
        .assertThrows("error:BAD_REQUEST")
        .go
    }

    it("returns that the user has r/o access when the calling user is different from the second argument and an ACE is present") {
      xq("""
        let $resource := data:doc("/data/original/test_one")
        let $grant := system:as-user("admin", $magic:password,(
                       sm:chmod(xs:anyURI($resource), "rw-------"),
                       sm:add-user-ace(xs:anyURI($resource), "xqtest2", true(), "r--")
                       )
                     )
        return acc:get-access-as-user(doc($resource), "xqtest2")/* """)
        .user("xqtest1")
        .assertXmlEquals("""<a:user-access xmlns:a="http://jewishliturgy.org/ns/access/1.0" user="xqtest2" read="true"
                                                     write="false"
                                                     chmod="false"
                                                     relicense="false"/>""")
        .go
    }

    it("returns that the user has r/w access when the calling user is different from the second argument and an ACE is present") {
      xq("""
        let $resource := data:doc("/data/original/test_one")
        let $grant := system:as-user("admin", $magic:password, (
          sm:chmod(xs:anyURI($resource), "rw-------"),
          sm:add-user-ace(xs:anyURI($resource), "xqtest2", true(), "rw-")
        ))
        return acc:get-access-as-user(doc($resource), "xqtest2")/* """)
        .user("xqtest1")
        .assertXmlEquals("""<a:user-access xmlns:a="http://jewishliturgy.org/ns/access/1.0" user="xqtest2" read="true"
                           write="true"
                           chmod="false"
                           relicense="false"/>""")
        .go
    }

    it("returns that the user has r/o access when the calling user is different from the second argument and an ACE is present with w/o override") {
      xq("""
        let $resource := data:doc("/data/original/test_one")
        let $grant := system:as-user("admin", $magic:password, (
          sm:chmod(xs:anyURI($resource), "rw-rw-rw-"),
          sm:add-user-ace(xs:anyURI($resource), "xqtest2", false(), "-w-")
        ))
        return acc:get-access-as-user(doc($resource), "xqtest2")/* """)
        .user("xqtest1")
        .assertXmlEquals("""<a:user-access xmlns:a="http://jewishliturgy.org/ns/access/1.0" user="xqtest2" read="true"
                           write="false"
                           chmod="false"
                           relicense="false"/>""")
        .go
    }

    it("returns that the user has no access when the calling user is different from the second argument and an ACE is present with r/w denial override") {
      xq("""
        let $resource := data:doc("/data/original/test_one")
        let $grant := system:as-user("admin", $magic:password, (
          sm:chmod(xs:anyURI($resource), "rw-rw-rw-"),
          sm:add-user-ace(xs:anyURI($resource), "xqtest2", false(), "rw-")
        ))
        return acc:get-access-as-user(doc($resource), "xqtest2")/* """)
        .user("xqtest1")
        .assertXmlEquals("""<a:user-access xmlns:a="http://jewishliturgy.org/ns/access/1.0" user="xqtest2" read="false"
                           write="false"
                           chmod="false"
                           relicense="false"/>""")
        .go
    }
  }

  describe("functional test: get just after set") {
    it("returns the values that were set") {
      xq("""let $resource := "/data/original/test_one"
                  let $set := acc:set-access(data:doc($resource),
                   <a:access>
                     <a:owner>xqtest1</a:owner>
                     <a:group write="true">dba</a:group>
                     <a:world read="true" write="false"/>
                     <a:grant>
                       <a:grant-group write="false">everyone</a:grant-group>
                       <a:grant-user write="true">xqtest2</a:grant-user>
                     </a:grant>
                     <a:deny>
                       <a:deny-user read="true">guest</a:deny-user>
                       <a:deny-group read="true">guest</a:deny-group>
                     </a:deny>
                   </a:access>)
                 return acc:get-access(data:doc($resource))/*""")
        .user("xqtest1")
        .assertXPath("""count(*)=6 and count(a:grant/*)=2 and count(a:deny/*)=2""", "correct number of conditions")
        .assertXPathEquals("$output/a:owner", "owner", """<a:owner xmlns:a="http://jewishliturgy.org/ns/access/1.0">xqtest1</a:owner>""")
        .assertXPathEquals("$output/a:group", "group", """<a:group xmlns:a="http://jewishliturgy.org/ns/access/1.0" write="true">dba</a:group>""")
        .assertXPathEquals("$output/a:world", "world", """<a:world xmlns:a="http://jewishliturgy.org/ns/access/1.0" read="true" write="false"/>""")
        .assertXPathEquals("$output/a:grant/a:grant-group", "grant-group", """<a:grant-group xmlns:a="http://jewishliturgy.org/ns/access/1.0" write="false">everyone</a:grant-group>""")
        .assertXPathEquals("$output/a:grant/a:grant-user", "grant-user", """<a:grant-user xmlns:a="http://jewishliturgy.org/ns/access/1.0" write="true">xqtest2</a:grant-user>""")
        .assertXPathEquals("$output/a:deny/a:deny-user", "deny-user", """<a:deny-user xmlns:a="http://jewishliturgy.org/ns/access/1.0" read="true">guest</a:deny-user>""")
        .assertXPathEquals("$output/a:deny/a:deny-group", "deny-group", """<a:deny-group xmlns:a="http://jewishliturgy.org/ns/access/1.0" read="true">guest</a:deny-group>""")
        .go
    }
  }
}
