package org.opensiddur.api.utility

import org.opensiddur.DbTest

class TestTranslit extends DbTest {
  override val prolog =
    """xquery version '3.1';

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

import module namespace translit="http://jewishliturgy.org/api/utility/translit"
    at "xmldb:exist:///db/apps/opensiddur-server/api/utility/translit.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";
declare namespace http="http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
"""
  override def beforeAll = {
    super.beforeAll()

    setupUsers(1)
    setupResource("src/test/resources/api/utility/translit/Test.xml",
      "Test", "transliteration", 1)
  }

  override def afterAll = {
    teardownResource("Test", "transliteration", 1)
    teardownUsers(1)

    super.afterAll()
  }

  describe("translit:transliteration-list") {
    it("returns an HTML list") {
      xq("""translit:transliteration-list("", 1, 100)""")
        .assertXPath("""$output/self::html:html/html:body/html:ul[@class="results"]/html:li[@class="result"]/html:a[contains(@href, "/utility/translit/")]""")
        .go
    }
  }
  
  describe("translit:transliterate-xml") {
    it("returns a transliteration XML on posting XML and a valid transliteration schema") {
      xq("""translit:transliterate-xml(
        document{
          <transliterate xml:lang="he">אבגדה וזח</transliterate>
        },
        "Test")
      """)
        .assertXmlEquals("""<transliterate xml:lang="he-Latn">abcde fgh</transliterate>""")
        .go
    }
    
    it("returns 404 on posting XML and a nonexistent transliteration schema") {
      xq("""translit:transliterate-xml(
        document{
          <transliterate xml:lang="he">אבגדה וזח</transliterate>
        },
        "NotExistent")""")
        .assertHttpNotFound
        .go
    }
    
    it("returns 400 on post XML and a nonexistent transliteration table") {
      xq("""translit:transliterate-xml(
              document{
              <transliterate xml:lang="xx">אבגדה וזח</transliterate>
              },
              "Test")""")
        .assertHttpBadRequest
        .go
    }
  }
  
  describe("translit:transliterate-text") {
    it("returns a transliterated text record on posting text and valid transliteration schema") {
      xq("""translit:transliterate-text(
        util:string-to-binary("אבגדה וזח"),
        "Test")""")
        .assertXPath("""$output[1]/self::rest:response/output:serialization-parameters/output:method="text"""", "output is text/plain")
        .assertXPath("""$output[2]="abcde fgh"""", "transliterated text")
        .go
    }

    it("returns 404 on post text and a nonexistent transliteration schema") {
      xq("""translit:transliterate-text(
        util:string-to-binary("אבגדה וזח"),
        "NotExistent")""")
        .assertHttpNotFound
        .go
    }
  }
}