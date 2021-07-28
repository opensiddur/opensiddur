package org.opensiddur.api

import org.opensiddur.DbTest

import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

class TestChanges extends DbTest {
  /** imports, namespaces and variables */
  override val prolog: String =
    """xquery version '3.1';

import module namespace chg="http://jewishliturgy.org/api/changes"
  at "xmldb:exist:///db/apps/opensiddur-server/api/changes.xqm";

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:///db/apps/opensiddur-server/test/tcommon.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";
    """

  def dateRange(beginTime: String,
                endTime: String,
                intervalMonths: Long): List[String] = {
    val formatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME
    if (beginTime <= endTime) {
      val beginDate = LocalDateTime.parse(beginTime, formatter)
      List(beginDate.format(formatter)) ++
        dateRange(beginDate.plusMonths(intervalMonths).format(formatter), endTime, intervalMonths)
    }
    else {
      List()
    }
  }

  def changesFile(
                 title: String,
                 whos: List[String],
                 beginTime: String,
                 endTime: String
                 ): String = {
    val revisionDescContent = dateRange(beginTime, endTime, 1).zipWithIndex.map {
      case (when: String, n: Int) => {
        val changeType = if (n == 0) "created" else "edited"
        val who = whos((n % whos.length))
          f"""<tei:change type="$changeType" who="/user/$who" when="$when">message ${n + 1}</tei:change>"""
      }}.mkString("\n")

    f"""<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
      |                <tei:teiHeader>
      |                    <tei:fileDesc>
      |                        <tei:titleStmt>
      |                            <tei:title>{$title}</tei:title>
      |                        </tei:titleStmt>
      |                    </tei:fileDesc>
      |                    <tei:revisionDesc>{$revisionDescContent}</tei:revisionDesc>
      |                </tei:teiHeader>
      |                <tei:text/>
      |            </tei:TEI>""".stripMargin
  }

  override def beforeAll: Unit = {
    super.beforeAll

    setupUsers(2)

    (1980 to 2000).map { year =>
      val title = s"file_$year"
      val owner = if ((year % 2) == 0) 1 else 2
      val fileContent = changesFile(title, List(s"xqtest$owner"), s"${year}-01-01T00:00:00", s"${year}-12-31T23:59:00")
      setupResource(fileContent, title, "original", owner, Some("en"), firstParamIsContent = true)
    }
  }

  override protected def afterAll(): Unit = {
    (1980 to 2000).map { year =>
      val title = s"file_$year"
      val owner = if ((year % 2) == 0) 1 else 2
      teardownResource(title, "original", owner)
    }
    teardownUsers(2)

    super.afterAll()
  }

  describe("chg:list") {
    it("returns all recent changes") {
      xq("""chg:list((), (), (), (), 1, 100)[2]""")
        .user("xqtest1")
        .assertXPath("exists($output/self::html:html[descendant::html:ul[@class=\"results\"]])", "an HTML API results document is returned")
        .assertXPath("""count($output//html:li[@class="result"]) >= 1""", "at least one result is returned")
        .assertXPath("""count($output//html:li[@class="result"]) <= 100""", "at most max-results are returned")
        .go
    }

    it("returns all recent changes by a given user in type notes, where none were made") {
      xq("""chg:list("notes", "xqtest1", (), (), 1, 100)[2]""")
        .user("xqtest1")
        .assertXPath("""exists($output/self::html:html[descendant::html:ul[@class="results"]])""", "an HTML API results document is returned")
        .assertXPath("""count($output//html:li[@class="result"]) = 0""", "no results is returned")
        .go
    }
    
    it("returns all recent changes made by a particular user") {
      xq("""chg:list((), "xqtest1", (), (), 1, 1000)[2]""")
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"])=11""", "returns results for 11 files")
        .assertXPath("""count($output//html:li[@class="result"][html:ol[@class="changes"]/html:li[@class="change"][html:span[@class="who"][.="xqtest1"]][html:span[@class="type"][.="created"]]])=11""", "returns created entry for 11 files")
        .assertXPath("""count($output//html:li[@class="result"][html:ol[@class="changes"]/html:li[@class="change"][html:span[@class="who"][.="xqtest1"]][html:span[@class="type"][.="edited"]]])=11""", "returns edited entries for 11 files")
        .assertXPath("""$output//html:li[1]/html:ol/html:li[1]/html:span[@class="when"]/string() > $output//html:li[2]/html:ol/html:li[1]/html:span[@class="when"]/string() """, "files are sorted in descending order")
        .assertXPath("""$output//html:li[1]/html:ol/html:li[1]/html:span[@class="when"]/string() > $output//html:li[1]/html:ol/html:li[2]/html:span[@class="when"]/string() """, "change records per file are sorted in descending order")
        .go
    }
      
      it("returns all recent changes made by a particular user with a date begin range") {
        xq("""chg:list((), "xqtest1", "1986-06-01T00:00:00", (), 1, 1000)[2]""")
          .user("xqtest1")
          .assertXPath("""count($output//html:li[@class="result"])=8""", "returns results for 8 files")
          .assertXPath("""count($output//html:li[@class="result"][html:ol[@class="changes"]/html:li[@class="change"][html:span[@class="who"][.="xqtest1"]][html:span[@class="type"][.="created"]]])=7""", "returns created entry for 7 files")
          .assertXPath("""every $entry in $output//html:ul[@class="results"][html:a[.="file_1986"]]/html:li[@class="result"][html:ol[@class="changes"]/html:li[@class="change"][html:span[@class="who"][.="xqtest1"]][html:span[@class="type"][.="edited"]]] satisfies $entry/html:span[@class="when"] >= "1986-06-01T00:00:00" """, "returns only entries after the breakpoint")
          .go
      }
      
      it("returns all recent changes made by a particular user with a date end range") {
        xq("""chg:list((), "xqtest1", (), "1986-06-01T00:00:00", 1, 1000)[2]""")
          .user("xqtest1")
          .assertXPath("""count($output//html:li[@class="result"])=4""", "returns results for 4 files")
          .assertXPath("""count($output//html:li[@class="result"][html:ol[@class="changes"]/html:li[@class="change"][html:span[@class="who"][.="xqtest1"]][html:span[@class="type"][.="created"]]])=4""", "returns created entry for 4 files")
          .assertXPath("""every $entry in $output//html:ul[@class="results"][html:a[.="file_1986"]]/html:li[@class="result"][html:ol[@class="changes"]/html:li[@class="change"][html:span[@class="who"][.="xqtest1"]][html:span[@class="type"][.="edited"]]] satisfies $entry/html:span[@class="when"] <= "1986-06-01T00:00:00"""", "returns only entries before the breakpoint")
          .go
      }
      
      it("returns all recent changes made by a particular user with date begin and end ranges") {
        xq("""chg:list((), "xqtest1", "1982-06-01T00:00:00", "1990-06-01T00:00:00", 1, 1000)[2]""")
          .user("xqtest1")
          .assertXPath("""count($output//html:li[@class="result"])=5""", "returns results for 5 files")
          .assertXPath("""count($output//html:li[@class="result"][html:ol[@class="changes"]/html:li[@class="change"][html:span[@class="who"][.="xqtest1"]][html:span[@class="type"][.="created"]]])=4""", "returns created entry for 4 files")
          .assertXPath("""every $entry in $output//html:ul[@class="results"][html:a[.="File_1982"]]/html:li[@class="result"][html:ol[@class="changes"]/html:li[@class="change"][html:span[@class="who"][.="xqtest1"]][html:span[@class="type"][.="edited"]]] satisfies $entry/html:span[@class="when"] >= "1982-06-01T00:00:00"""", "returns only entries after the breakpoint for the start date")
          .assertXPath("""every $entry in $output//html:ul[@class="results"][html:a[.="File_1990"]]/html:li[@class="result"][html:ol[@class="changes"]/html:li[@class="change"][html:span[@class="who"][.="xqtest1"]][html:span[@class="type"][.="edited"]]] satisfies $entry/html:span[@class="when"] <= "1990-06-01T00:00:00"""", "returns only entries before the breakpoint for the end date")
          .go
      }

  }
}
