package org.opensiddur.transforms

import org.opensiddur.DbTest

class TestTranslit extends DbTest {
  val testTable = readXmlFile("src/test/resources/transforms/Translit/testtable.xml")

  /** imports, namespaces and variables */
  override val prolog: String =
    s"""xquery version '3.1';
    
    declare namespace tei="http://www.tei-c.org/ns/1.0";
    declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
    declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";
    declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";

    import module namespace translit="http://jewishliturgy.org/transform/transliterator"
      at "xmldb:exist:/db/apps/opensiddur-server/transforms/translit/translit.xqm";
    import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
      at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

    declare variable $$local:table := $testTable;
    """

  override def beforeAll: Unit = {
    super.beforeAll

    setupUsers(1)
  }

  override def afterAll(): Unit = {
    teardownUsers(1)

    super.afterAll()
  }

  describe("translit:transliterate-document") {
    ignore("acts as an identity transform with no transliteration table") {
      val noTranslitContext = readXmlFile("src/test/resources/transforms/Translit/no-translit-context.xml")

      xq(
        s"""let $$doc := document { $noTranslitContext }
          return translit:transliterate-document($$doc, map {})/* """)
        .user("xqtest1")
        .assertXmlEquals(noTranslitContext)
        .go
    }
  }

  describe("translit:transliterate") {
    it("provides a translation of a word") {
      xq("""translit:transliterate(element tei:w { attribute { "n" }{ "2" }, text { "אֶפְרָיִם" }} , map { "translit:table" : $local:table//tr:table })""")
        .assertXmlEquals("""<tei:w xmlns:tei="http://www.tei-c.org/ns/1.0" n="2">ʾefrayim</tei:w>""")
        .go
    }

    it("transliterates a maleh vowel") {
      xq("""translit:transliterate(element tei:w { text { "רִית" }}, map { "translit:table" : $local:table//tr:table })""")
        .assertXmlEquals("""<tei:w xmlns:tei="http://www.tei-c.org/ns/1.0">riyt</tei:w>""")
        .go
    }

    it("transliterates a holam male") {
      xq("""translit:transliterate(element tei:w { text{ "&#x05d6;&#x05d5;&#x05b9;" }}, map { "translit:table" : $local:table//tr:table })""")
        .assertXmlEquals("""<tei:w xmlns:tei="http://www.tei-c.org/ns/1.0">zo</tei:w>""")
        .go
    }

    it("transliterates a shuruq") {
      xq("""translit:transliterate(element tei:w { text { "&#x05d6;&#x05d5;&#x05bc;" }}, map { "translit:table" : $local:table//tr:table })""")
        .assertXmlEquals("""<tei:w xmlns:tei="http://www.tei-c.org/ns/1.0">zu</tei:w>""")
        .go
    }

    it("transliterates a dagesh hazak") {
      xq("""translit:transliterate(element tei:w { text { "לַבַּל" }}, map { "translit:table" : $local:table//tr:table })""")
        .assertXmlEquals("""<tei:w xmlns:tei="http://www.tei-c.org/ns/1.0">labbal</tei:w>""")
        .go
    }

    it("transliterates a dagesh kal") {
      xq("""translit:transliterate(element tei:w { text { "בַּז" }}, map { "translit:table" : $local:table//tr:table })""")
        .assertXmlEquals("""<tei:w xmlns:tei="http://www.tei-c.org/ns/1.0">baz</tei:w>""")
        .go
    }

    it("transliterates a Tetragrammation (form 1)") {
      xq("""translit:transliterate(element tei:w { text { "יְהוָה" }}, map { "translit:table" : $local:table//tr:table })""")
        .assertXmlEquals("""<tei:w xmlns:tei="http://www.tei-c.org/ns/1.0">ʾadonay</tei:w>""")
        .go
    }

    it("transliterates a Tetragrammation (form 2)") {
      xq("""translit:transliterate(element tei:w { text { "יֱהוִה" }}, map { "translit:table" : $local:table//tr:table })""")
        .assertXmlEquals("""<tei:w xmlns:tei="http://www.tei-c.org/ns/1.0">ʾelohim</tei:w>""")
        .go
    }

    it("transliterates a Tetragrammation (form 3)") {
      xq("""translit:transliterate(element tei:w { text { "יְיָ" }}, map { "translit:table" : $local:table//tr:table })""")
        .assertXmlEquals("""<tei:w>ʾadonay</tei:w>""")
        .go
    }

    it("transliterates a shin-dot+vowel") {
      xq("""translit:transliterate(element tei:w { text { "&#x05e9;&#x05c1;&#x05b8;" }}, map { "translit:table" : $local:table//tr:table })""")
        .assertXmlEquals("""<tei:w>sha</tei:w>""")
        .go
    }

    it("transliterates a shin+dot+dagesh+vowel+consonant") {
      xq("""translit:transliterate(element tei:w { text { "&#x05e9;&#x05c1;&#x05bc;&#x05b8;&#x05d1;" }}, map { "translit:table" : $local:table//tr:table })""")
        .assertXmlEquals("""<tei:w>shav</tei:w>""")
        .go
    }

    it("transliterates a shin+dot+dagesh+vowel (no doubling)") {
      xq("""translit:transliterate(element tei:w { text { "&#x05e9;&#x05c1;&#x05bc;&#x05b8;" }}, map { "translit:table" : $local:table//tr:table })""")
        .assertXmlEquals("""<tei:w>sha</tei:w>""")
        .go
    }

    it("transliterates a vav-holam haser for vav") {
      xq("""translit:transliterate(element tei:w { text { "&#x05de;&#x05b4;&#x05e6;&#x05b0;&#x05d5;&#x05ba;&#x05ea;" }}, map { "translit:table" : $local:table//tr:table })""")
        .assertXmlEquals("""<tei:w>mitzvot</tei:w>""")
        .go
    }

    it("transliterates Unicode combined forms like the decomposed form") {
      xq("""translit:transliterate(element tei:w { text { "&#xfb2f;&#xfb31;&#xfb4b;" }}, map { "translit:table" : $local:table//tr:table })""")
        .assertXmlEquals("""<tei:w>ʾabbo</tei:w>""")
        .go
    }
  }

  describe("translit:make-word-text") {
    it("forms a structure when given consonants only") {
      xq("""element ccs {
                       translit:make-word-text(text { "&#x5d0;&#x5d1;" }, map {})
                     }""")
        .assertXmlEquals("""<ccs>
                                  <tr:cc>
                                    <tr:cons>&#x05d0;</tr:cons>
                                  </tr:cc>
                                  <tr:cc>
                                    <tr:cons>&#x05d1;</tr:cons>
                                  </tr:cc>
                                </ccs>""")
        .go
    }

    it("forms a complex consonant from consonants and vowels") {
      xq("""element ccs {
                       translit:make-word-text(text { "&#x5d0;&#x05b0;&#x5d1;&#x05b1;&#x05d2;&#x05b7;&#x05d3;&#x05b8;" }, map {})
                     }""")
        .assertXmlEquals("""<ccs>
                           |            <tr:cc>
                           |              <tr:cons>&#x05d0;</tr:cons>
                           |              <tr:s>&#x05b0;</tr:s>
                           |            </tr:cc>
                           |            <tr:cc>
                           |              <tr:cons>&#x05d1;</tr:cons>
                           |              <tr:vu>&#x05b1;</tr:vu>
                           |            </tr:cc>
                           |            <tr:cc>
                           |              <tr:cons>&#x05d2;</tr:cons>
                           |              <tr:vs>&#x05b7;</tr:vs>
                           |            </tr:cc>
                           |            <tr:cc>
                           |              <tr:cons>&#x05d3;</tr:cons>
                           |              <tr:vl>&#x05b8;</tr:vl>
                           |            </tr:cc>
                           |          </ccs>""".stripMargin)
        .go
    }

    it("makes a complex consonant structure from consonant+dagesh+vowel") {
      xq("""element ccs {
           |            translit:make-word-text(text { "&#x5d1;&#x05bc;&#x5b8;" }, map {})
           |          }""".stripMargin)
        .assertXmlEquals("""<ccs>
                           |            <tr:cc>
                           |              <tr:cons>&#x05d1;</tr:cons>
                           |              <tr:d>&#x05bc;</tr:d>
                           |              <tr:vl>&#x05b8;</tr:vl>
                           |            </tr:cc>
                           |          </ccs>""".stripMargin)
        .go
    }

    it("forms a complex consonant structure from shin+dot+dagesh+vowel") {
      xq("""element ccs {
           |            translit:make-word-text(text { "&#x5e9;&#x05c1;&#x05bc;&#x5b8;" }, map {})
           |          }""".stripMargin)
        .assertXmlEquals(""" <ccs>
                           |            <tr:cc>
                           |              <tr:cons>&#x05e9;</tr:cons>
                           |              <tr:dot>&#x05c1;</tr:dot>
                           |              <tr:d>&#x05bc;</tr:d>
                           |              <tr:vl>&#x05b8;</tr:vl>
                           |            </tr:cc>
                           |          </ccs>""".stripMargin)
        .go
    }

    it("forms a complex consonant strucure from shin+dot+rafe+vowel") {
      xq("""element ccs {
           |            translit:make-word-text(text { "&#x5e9;&#x05c1;&#x05bf;&#x5b8;" }, map {})
           |          }""".stripMargin)
        .assertXmlEquals("""<ccs>
                           |            <tr:cc>
                           |              <tr:cons>&#x05e9;</tr:cons>
                           |              <tr:dot>&#x05c1;</tr:dot>
                           |              <tr:d>&#x05bf;</tr:d>
                           |              <tr:vl>&#x05b8;</tr:vl>
                           |            </tr:cc>
                           |          </ccs>""".stripMargin)
        .go
    }

    it("forms a complex character structure if thrown the kitchen sink shin+dot+dagesh+vowel+meteg+lower accent") {
      xq("""element ccs {
           |            translit:make-word-text(text { "&#x5e9;&#x05c1;&#x05bc;&#x5b8;&#x05bd;&#x05a5;" }, map {})
           |          }""".stripMargin)
        .assertXmlEquals("""<ccs>
                           |            <tr:cc>
                           |              <tr:cons>&#x05e9;</tr:cons>
                           |              <tr:dot>&#x05c1;</tr:dot>
                           |              <tr:d>&#x05bc;</tr:d>
                           |              <tr:vl>&#x05b8;</tr:vl>
                           |              <tr:m>&#x05bd;</tr:m>
                           |              <tr:al>&#x05a5;</tr:al>
                           |            </tr:cc>
                           |          </ccs>""".stripMargin)
        .go
    }

    it("""forms a complex character if thrown the kitchen sink 2 (shin+dot+dagesh+vowel+meteg+mid accent)""") {
      xq("""element ccs {
           |            translit:make-word-text(text { "&#x5e9;&#x05c1;&#x05bc;&#x5b8;&#x05bd;&#x05ad;" }, map {})
           |          }""".stripMargin)
        .assertXmlEquals("""<ccs>
                           |            <tr:cc>
                           |              <tr:cons>&#x05e9;</tr:cons>
                           |              <tr:dot>&#x05c1;</tr:dot>
                           |              <tr:d>&#x05bc;</tr:d>
                           |              <tr:vl>&#x05b8;</tr:vl>
                           |              <tr:m>&#x05bd;</tr:m>
                           |              <tr:am>&#x05ad;</tr:am>
                           |            </tr:cc>
                           |          </ccs>""".stripMargin)
        .go
    }

    it("forms a complex character when thrown the kitchen sink 3 (shin+dot+dagesh+vowel+meteg+upper accent)") {
      xq("""element ccs {
           |            translit:make-word-text(text { "&#x5e9;&#x05c1;&#x05bc;&#x5b8;&#x05bd;&#x05a8;" }, map {})
           |          }""".stripMargin)
        .assertXmlEquals("""<ccs>
                           |            <tr:cc>
                           |              <tr:cons>&#x05e9;</tr:cons>
                           |              <tr:dot>&#x05c1;</tr:dot>
                           |              <tr:d>&#x05bc;</tr:d>
                           |              <tr:vl>&#x05b8;</tr:vl>
                           |              <tr:m>&#x05bd;</tr:m>
                           |              <tr:ah>&#x05a8;</tr:ah>
                           |            </tr:cc>
                           |          </ccs>""".stripMargin)
        .go
    }
  }
}
