package org.opensiddur.api.data

import org.opensiddur.DbTest

trait CommonTestOutlines {
  val prolog =
    """xquery version '3.1';
      import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
       at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

      import module namespace outl="http://jewishliturgy.org/api/data/outlines"
      at "xmldb:exist:///db/apps/opensiddur-server/api/data/outlines.xqm";
    import module namespace magic="http://jewishliturgy.org/magic"
      at "xmldb:exist:///db/apps/opensiddur-server/magic/magic.xqm";
    import module namespace data="http://jewishliturgy.org/modules/data"
      at "xmldb:exist:///db/apps/opensiddur-server/modules/data.xqm";
        
      declare namespace html="http://www.w3.org/1999/xhtml";
      declare namespace tei="http://www.tei-c.org/ns/1.0";
      declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
      declare namespace http="http://expath.org/ns/http-client";
      declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
      declare namespace ol="http://jewishliturgy.org/ns/outline/1.0";
      declare namespace olx="http://jewishliturgy.org/ns/outline/responses/1.0";
      """
}

class TestOutlines extends DbTest with CommonTestOutlines {
  override def beforeAll()  {
    super.beforeAll()

    setupUsers(2)
    setupResource("src/test/resources/api/data/outlines/existing.xml", "existing", "outlines", 1)
    setupResource("src/test/resources/api/data/outlines/test_everything_ok.xml", "test_everything_ok", "outlines", 1)
    setupResource("src/test/resources/api/data/outlines/test_outline.xml", "test_outline", "outlines", 1)
    setupResource("src/test/resources/api/data/outlines/title_exists_once.xml", "title_exists_once", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/title_contains_source_one_time.xml", "title_contains_source_one_time", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/title_has_source_and_pages_one_time.xml", "title_has_source_and_pages_one_time", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/title_exists_twice.xml", "title_exists_twice", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/title_exists_twice-1.xml", "title_exists_twice-1", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/title_has_been_confirmed.xml", "title_has_been_confirmed", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/title_already_confirmed_and_duplicated.xml", "title_already_confirmed_and_duplicated", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/title_already_confirmed_and_duplicated-1.xml", "title_already_confirmed_and_duplicated-1", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/title_duplicated_and_subordinates_exist_with_same_pointers.xml", "title_duplicated_and_subordinates_exist_with_same_pointers", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/title_duplicated_and_subordinates_exist_with_different_pointers.xml", "title_duplicated_and_subordinates_exist_with_different_pointers", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/sub_one.xml", "sub_one", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/sub_two.xml", "sub_two", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/has_a_status.xml", "has_a_status", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/test_outline_with_error.xml", "test_outline_with_error", "outlines", 1)
    setupResource("src/test/resources/api/data/outlines/test_outline_with_unconfirmed.xml", "test_outline_with_unconfirmed", "outlines", 1)
    setupResource("src/test/resources/api/data/outlines/has_unconfirmed.xml", "has_unconfirmed", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/test_outline_source.xml", "test_outline_source", "sources", 1)
    setupResource("src/test/resources/api/data/outlines/test_outline_executable.xml", "test_outline_executable", "outlines", 1)
    setupResource("src/test/resources/api/data/outlines/test_outline_executable_with_duplicates.xml", "test_outline_executable_with_duplicates", "outlines", 1)
    setupResource("src/test/resources/api/data/outlines/test_outline_executable_with_external_duplicates.xml", "test_outline_executable_with_external_duplicates", "outlines", 1)
  }

  override def afterAll()  {
    teardownResource("test_outline_executable_with_external_duplicates", "original", 1)
    teardownResource("test_outline_executable_with_external_duplicates", "outlines", 1)
    teardownResource("test_outline_executable_with_duplicates", "original", 1)
    teardownResource("test_outline_executable_with_duplicates", "outlines", 1)
    teardownResource("test_outline_executable_duplicate", "original", 1)
    teardownResource("test_outline_executable_duplicate_with_items", "original", 1)
    teardownResource("test_sub_one", "original", 1)
    teardownResource("test_sub_two", "original", 1)
    teardownResource("test_outline_executable", "original", 1)
    teardownResource("test_outline_executable_new_title", "original", 1)
    teardownResource("test_outline_executable", "outlines", 1)
    teardownResource("test_outline_source", "sources", 1)
    teardownResource("has_unconfirmed", "original", 1)
    teardownResource("test_outline_with_unconfirmed", "outlines", 1)
    teardownResource("test_outline_with_error", "outlines", 1)
    teardownResource("has_a_status", "original", 1)
    teardownResource("sub_two", "original", 1)
    teardownResource("sub_one", "original", 1)
    teardownResource("title_duplicated_and_subordinates_exist_with_different_pointers", "original", 1)
    teardownResource("title_duplicated_and_subordinates_exist_with_same_pointers", "original", 1)
    teardownResource("title_already_confirmed_and_duplicated-1", "original", 1)
    teardownResource("title_already_confirmed_and_duplicated", "original", 1)
    teardownResource("title_has_been_confirmed", "original", 1)
    teardownResource("title_exists_twice-1", "original", 1)
    teardownResource("title_exists_twice", "original", 1)
    teardownResource("title_contains_source_one_time-1", "original", 1)
    teardownResource("title_contains_source_one_time", "original", 1)
    teardownResource("title_has_source_and_pages_one_time-1", "original", 1)
    teardownResource("title_has_source_and_pages_one_time", "original", 1)
    teardownResource("title_exists_once-1", "original", 1)
    teardownResource("title_exists_once", "original", 1)
    teardownResource("test_outline", "outlines", 1)
    teardownResource("test_everything_ok", "outlines", 1)
    teardownResource("existing", "outlines", 1)
    teardownUsers(2)

    super.afterAll()
  }

  override def beforeEach(): Unit = {
    super.beforeEach()
  }

  override def afterEach(): Unit = {
    super.afterEach()
  }

  describe("outl:get") {
    it("gets an existing resource, no check") {
      xq("""outl:get("existing", ())""")
        .assertXPath("""exists($output/ol:outline)""", "Returns a TEI resource")
        .go
    }
    
    it("fails to get a nonexisting resource, no check") {
      xq("""outl:get("does_not_exist", ())""")
        .assertHttpNotFound
        .go
    }

    it("gets an existing resource, with identity check") {
      val identity = readXmlFile("src/test/resources/api/data/outlines/test_everything_ok.xml")
      xq("""outl:get("test_everything_ok", "1")/*""")
        .assertXmlEquals(identity)
        .go
    }

    it("gets an existing resource, with logic check") {
      xq("""outl:get("test_outline", "1")""")
        .assertXPathEquals("$output/ol:outline/ol:item[1]",
          "for each item without a duplicate title, return the item as-is",
        """<ol:item>
          <ol:title>TitleDoesNotExist</ol:title>
          <ol:from>1</ol:from>
          <ol:to>2</ol:to>
        </ol:item>""")
        .assertXPathEquals("$output/ol:outline/ol:item[2]", 
          "for each item with a duplicate title external to the outline without a duplication confirmation, " +
            "return an olx:sameAs with an olx:uri for each duplicate entry (title exists once)",
        """<ol:item>
              <ol:title>Title Exists Once</ol:title>
              <ol:from>3</ol:from>
              <ol:to>4</ol:to>
              <olx:sameAs>
                <olx:uri>/data/original/title_exists_once</olx:uri>
              </olx:sameAs>
          </ol:item>""")
        .assertXPathEquals("$output/ol:outline/ol:item[3]",
        "for each item with a duplicate title external to the outline without a duplication confirmation, " +
          "return an olx:sameAs with an olx:uri for each duplicate entry (title exists more than once)",
        """<ol:item>
              <ol:title>Title Exists Twice</ol:title>
              <ol:from>5</ol:from>
              <ol:to>6</ol:to>
              <olx:sameAs>
                <olx:uri>/data/original/title_exists_twice</olx:uri>
              </olx:sameAs>
              <olx:sameAs>
                <olx:uri>/data/original/title_exists_twice-1</olx:uri>
              </olx:sameAs>
          </ol:item>""")
        .assertXPathEquals("$output/ol:outline/ol:item[4]",
        "for an item with a duplicate title that is already confirmed, the confirmation is maintained exactly",
        """<ol:item>
              <ol:title>Title Has Been Confirmed</ol:title>
              <ol:from>7</ol:from>
              <ol:to>8</ol:to>
              <olx:sameAs>
                  <olx:uri>/data/original/title_has_been_confirmed</olx:uri>
                  <olx:yes/>
              </olx:sameAs>
          </ol:item>""")
        .assertXPathEquals("$output/ol:outline/ol:item[5]",
          "for an item with a duplicate title that is already confirmed and duplicated again, " +
            "the confirmation is maintained exactly and the additional duplicate is recorded with a negative confirmation",
        """<ol:item>
              <ol:title>Title Already Confirmed And Duplicated</ol:title>
              <ol:from>9</ol:from>
              <ol:to>10</ol:to>
              <olx:sameAs>
                  <olx:uri>/data/original/title_already_confirmed_and_duplicated</olx:uri>
                  <olx:yes/>
              </olx:sameAs>
              <olx:sameAs>
                  <olx:uri>/data/original/title_already_confirmed_and_duplicated-1</olx:uri>
                  <olx:no/>
              </olx:sameAs>
          </ol:item>""")
        .assertXPathEquals("$output/ol:outline/ol:item[6]",
          "Title already exists and has subordinates that are referenced and have the same pointers in the same order",
          """<ol:item>
            <ol:title>Title Duplicated And Subordinates Exist With Same Pointers</ol:title>
            <ol:from>11</ol:from>
            <ol:to>12</ol:to>
            <olx:sameAs>
              <olx:uri>/data/original/title_duplicated_and_subordinates_exist_with_same_pointers</olx:uri>
            </olx:sameAs>
            <ol:item>
              <ol:title>Sub One</ol:title>
              <olx:sameAs>
                <olx:uri>/data/original/sub_one</olx:uri>
              </olx:sameAs>
            </ol:item>
            <ol:item>
              <ol:title>Sub Two</ol:title>
              <olx:sameAs>
                <olx:uri>/data/original/sub_two</olx:uri>
              </olx:sameAs>
            </ol:item>
          </ol:item>"""
        )
        .assertXPathEquals("$output/ol:outline/ol:item[7]",
        "Title already exists and has subordinates that are referenced and have the same pointers in different order",
        """<ol:item>
            <ol:title>Title Duplicated And Subordinates Exist With Different Pointers</ol:title>
            <ol:from>13</ol:from>
            <ol:to>14</ol:to>
            <olx:sameAs>
              <olx:uri>/data/original/title_duplicated_and_subordinates_exist_with_different_pointers</olx:uri>
              <olx:warning>...</olx:warning>
            </olx:sameAs>
            <ol:item>
              <ol:title>Sub Two</ol:title>
              <olx:sameAs>
                <olx:uri>/data/original/sub_two</olx:uri>
              </olx:sameAs>
            </ol:item>
            <ol:item>
              <ol:title>Sub One</ol:title>
              <olx:sameAs>
                <olx:uri>/data/original/sub_one</olx:uri>
              </olx:sameAs>
            </ol:item>
          </ol:item>""")
        .assertXPathEquals("$output/ol:outline/ol:item[8]",
          "if the document has a confirmed identity and a status with respect to the source, the status is returned",
          """<ol:item>
            <ol:title>Has A Status</ol:title>
            <ol:from>15</ol:from>
            <ol:to>16</ol:to>
            <olx:sameAs>
              <olx:uri>/data/original/has_a_status</olx:uri>
              <olx:yes/>
            </olx:sameAs>
            <olx:status>outlined</olx:status>
          </ol:item>"""
        )
        .assertXPathEquals("$output/ol:outline/ol:item[9]",
          "if there is an internal duplicate title and one has items and the other does not, do nothing to the one that has items",
          """<ol:item>
            <ol:title>InternalDuplicate</ol:title>
            <ol:from>17</ol:from>
            <ol:to>18</ol:to>
            <ol:item>
              <ol:title>SubThree</ol:title>
            </ol:item>
            <ol:item>
              <ol:title>SubFour</ol:title>
            </ol:item>
          </ol:item>"""
        )
        .assertXPathEquals("$output/ol:outline/ol:item[10]",
          "if there is an internal duplicate title and one has items and the other does not, do nothing to the one that has no items",
          """<ol:item>
            <ol:title>InternalDuplicate</ol:title>
            <ol:from>19</ol:from>
            <ol:to>20</ol:to>
          </ol:item>"""
        )
        .assertXPathEquals("$output/ol:outline/ol:item[11]",
          "if there is an internal duplicate title and both have identical items, do nothing to the duplicate",
          """<ol:item>
            <ol:title>InternalDuplicate</ol:title>
            <ol:from>21</ol:from>
            <ol:to>22</ol:to>
            <ol:item>
              <ol:title>SubThree</ol:title>
            </ol:item>
            <ol:item>
              <ol:title>SubFour</ol:title>
            </ol:item>
          </ol:item>"""
        )
        .assertXPathEquals("$output/ol:outline/ol:item[12]",
          "if there is an internal duplicate title and the items are not identical, flag olx:error on the first copy",
          """<ol:item>
            <ol:title>BadInternalDuplicate</ol:title>
            <ol:from>23</ol:from>
            <ol:to>24</ol:to>
            <olx:error>...</olx:error>
            <ol:item>
              <ol:title>SubFive</ol:title>
            </ol:item>
          </ol:item>"""
        )
        .assertXPathEquals("$output/ol:outline/ol:item[13]",
          "if there is an internal duplicate title and the items are not identical, flag olx:error on the second copy",
          """<ol:item>
            <ol:title>BadInternalDuplicate</ol:title>
            <ol:from>25</ol:from>
            <ol:to>26</ol:to>
            <olx:error>...</olx:error>
            <ol:item>
              <ol:title>SubSix</ol:title>
            </ol:item>
          </ol:item>"""
        )
        .assertXPath("outl:validate($output, ())", "the resulting file is valid")
        .go
    }
  }  

  describe("outl:post with execute") {
    it("fails on an outline file with olx:error after check") {
      xq("""outl:post-execute("test_outline_with_error")""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
    
    it("fails on an outline file with an unconfirmed olx:sameAs") {
      xq("""outl:post-execute("test_outline_with_unconfirmed")""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
    
    it("executes an executable outline") {
      val expectedResult = readXmlFile("src/test/resources/api/data/outlines/test_outline_executable_result.xml")
      xq("""outl:post-execute("test_outline_executable")""")
        .user("xqtest1")
        .assertXPathEquals("$output/*", "Result is a copy of the rewritten outline", expectedResult)
        .assertXPathEquals("""doc("/db/data/outlines/test_outline_executable.xml")/*""",
          "the original outline file has been rewritten to correspond to the new data from execution",
         expectedResult)
        .assertXPath("""exists(data:doc("/data/original/test_outline_executable"))""", "the outline main file exists")
        .assertXPath("""contains(document-uri(data:doc("/data/original/test_outline_executable")), "/en")""", "the outline main file is placed in the correct collection for its language")
        .assertXPath("""data:doc("/data/original/test_outline_executable")//tei:titleStmt/tei:title[@type="main"]="test_outline_executable"""", "the outline main file has the correct title")
        .assertXPath("""data:doc("/data/original/test_outline_executable")/tei:TEI/@xml:lang="en"""", "the outline main file references the correct xml:lang")
        .assertXPath("""data:doc("/data/original/test_outline_executable")//tei:availability/tei:licence/@target="http://www.creativecommons.org/publicdomain/zero/1.0"""", "the outline main file references the correct license")
        .assertXPath("""data:doc("/data/original/test_outline_executable")//tei:sourceDesc/tei:bibl[@j:docStatus="outlined"]/tei:ptr[@type="bibl"]/@target="/data/sources/test_outline_source"""", "the outline main file references the correct source and status")
        .assertXPath("""data:doc("/data/original/test_outline_executable")//j:streamText/tei:ptr/@target="/data/original/test_outline_executable_new_title#stream"""", "the outline main file has a streamText containing a pointer to the included file")
        .assertXPath("""empty(data:doc("/data/original/test_outline_executable")//j:streamText/tei:seg)""", "the outline main file streamText filler has been removed")
        .assertXPath("""count(data:doc("/data/original/test_outline_executable")//tei:revisionDesc/tei:change[@type="created"])=1""", "the outline main file has 1 creation change record")
        .assertXPath("""count(data:doc("/data/original/test_outline_executable")//tei:revisionDesc/tei:change[@type="edited"])=1""", "the outline main file has 1 edit change record")
        .assertXPath("""exists(data:doc("/data/original/test_outline_executable_new_title"))""", "the outline included file exists")
        .assertXPath("""contains(document-uri(data:doc("/data/original/test_outline_executable_new_title")), "/en")""", "the outline included file is placed in the correct collection for its language")
        .assertXPath("""data:doc("/data/original/test_outline_executable_new_title")//tei:titleStmt/tei:title[@type="main"]="test_outline_executable_new_title"""", "the outline included file has the correct title")
        .assertXPath("""data:doc("/data/original/test_outline_executable_new_title")/tei:TEI/@xml:lang="en"""", "the outline included file references the correct xml:lang")
        .assertXPath("""data:doc("/data/original/test_outline_executable_new_title")//tei:availability/tei:licence/@target="http://www.creativecommons.org/publicdomain/zero/1.0"""", "the outline included file references the correct license")
        .assertXPath("""data:doc("/data/original/test_outline_executable_new_title")//tei:titleStmt/tei:respStmt[tei:resp[@key="trc"][.="Transcribed by"]][tei:name[@ref="/user/xqtest1"]]""", "the outline included file references a contributor credit")
        .assertXPath("""data:doc("/data/original/test_outline_executable_new_title")//tei:sourceDesc/tei:bibl[@j:docStatus="outlined"][tei:biblScope[@unit="pages"][@from="1"][@to="2"]]/tei:ptr[@type="bibl"]/@target="/data/sources/test_outline_source"""", "the outline included file references the correct source, status, and page numbers")
        .assertXPath("""count(data:doc("/data/original/test_outline_executable_new_title")//j:streamText/tei:seg)=2""", "the outline included file has a streamText containing filler")
        .assertXPath("""count(data:doc("/data/original/test_outline_executable_new_title")//tei:revisionDesc/tei:change[@type="created"])=1""", "the outline included file has 1 creation change record")
        .assertXPath("""count(data:doc("/data/original/test_outline_executable_new_title")//tei:revisionDesc/tei:change[@type="edited"])=0""", "the outline included file has no edit change records")
        .go
    }
    
    it("executes an outline with duplicates") {
      xq("""outl:post-execute("test_outline_executable_with_duplicates")""")
        .user("xqtest1")
        .assertXPath("""exists(data:doc("/data/original/test_outline_executable_with_duplicates"))""", "the outline main file exists")
        .assertXPath("""
        let $d := data:doc("/data/original/test_outline_executable_with_duplicates")
        let $st := $d//j:streamText
        return
          count($st/tei:ptr[@target='/data/original/test_outline_executable_duplicate#stream'])=2 and
          count($st/tei:ptr[@target='/data/original/test_outline_executable_duplicate_with_items#stream'])=2
      """, "The main outline file references test_outline_executable_duplicate 2x and test_outline_executable_duplicate_with_items 2x")
          .assertXPath("""count(collection("/db/data/original/en")/tei:TEI[descendant::tei:titleStmt/tei:title[@type="main"][.="Test Outline Executable Duplicate"]])=1""",
            "Documents with the title TestOutlineExecutableDuplicate exist only once")
          .assertXPath("""count(data:doc("/data/original/test_outline_executable_duplicate")//tei:revisionDesc/tei:change)=1""",
            "TestOutlineExecutableDuplicate has been written to once on creation, since it has no filler pointers")
          .assertXPath("""
        let $b := data:doc("/data/original/test_outline_executable_duplicate")//tei:sourceDesc/tei:bibl
        return
          count($b/tei:biblScope)=2
          and exists($b/tei:biblScope[@unit='pages'][@from='1'][@to='2'])
          and exists($b/tei:biblScope[@unit='pages'][@from='3'][@to='4'])
        """, "TestOutlineExecutableDuplicate references two different page ranges")
          .assertXPath("""count(collection("/db/data/original/en")/tei:TEI[descendant::tei:titleStmt/tei:title[@type="main"][.="Test Outline Executable Duplicate With Items"]])=1""",
            "Documents with the title TestOutlineExecutableDuplicateWithItems exist only once")
          .assertXPath("""
            let $st := data:doc("/data/original/test_outline_executable_duplicate_with_items")//j:streamText
            return exists($st/tei:ptr[1]["/data/original/test_sub_one#stream"=@target])
            and exists($st/tei:ptr[2]["/data/original/test_sub_two#stream"=@target])
          """, "TestOutlineExecutableDuplicateWithItems has a streamText that points to its two subordinates")
          .assertXPath("""exists(data:doc("/data/original/test_sub_one"))""", "TestSubOne exists")
          .assertXPath("""exists(data:doc("/data/original/test_sub_two"))""", "TestSubTwo exists")
          .assertXPathEquals("$output/*", "The return outline contains the expected data and references",
            readXmlFile("src/test/resources/api/data/outlines/test_outline_executable_with_duplicates_result.xml"))
          .go
    }

    it("executes an outline containing external duplicate references") {
      xq("""outl:post-execute("test_outline_executable_with_external_duplicates")""")
        .user("xqtest1")
        //.assertXPath("false()", "forced fail")
        .assertXPath("""exists(data:doc("/data/original/test_outline_executable_with_external_duplicates"))""", "the outline main file exists")
        /*.assertXPath("""count(collection("/db/data/original/en")//tei:titleStmt/tei:title[@type="main"][.="title_already_confirmed_and_duplicated"])=1""",
          "There is only file with the same title as the confirmed resource")*/
        .assertXPath("""exists(data:doc("/data/original/title_already_confirmed_and_duplicated")//tei:sourceDesc/tei:bibl[@j:docStatus="outlined"]/tei:ptr[@type="bibl"]["/data/sources/test_outline_source"=@target])""",
          "A reference to the source has been added to the confirmed resource")
        .assertXPath("""exists(data:doc("/data/original/title_already_confirmed_and_duplicated")//tei:sourceDesc/tei:bibl[@j:docStatus="outlined"]/tei:biblScope[@unit="pages"][@from="1"][@to="2"])""",
          "A reference to the source's pages has been added to the confirmed resource")
        .assertXPath("""exists(data:doc("/data/original/title_already_confirmed_and_duplicated")//tei:revisionDesc/tei:change[1][@type="edited"][contains(., "outline tool")])""",
          "An edited by change record has been added to the confirmed resource")
        .assertXPath(
          """every $resource in ("Title Already Confirmed And Duplicated", "Title Duplicated And Subordinates Exist With Same Pointers", "Title Contains Source One Time", "Title Has Source And Pages One Time") satisfies
            count($output//ol:item[ol:title=$resource]/olx:sameAs[olx:yes])=1""",
          "For each confirmed resource, a single olx:sameAs[olx:yes] record exists in the output outline")
        .assertXPath("""data:doc("/data/original/title_already_confirmed_and_duplicated")//j:streamText/tei:seg[1]="Test data."""",
          "The text data in the confirmed resource has not been overwritten")
        .assertXPath("""exists(data:doc("/data/original/title_exists_once-1"))""",
          "A second file with the same title and different URI as the confirmed negative file has been created")
        .assertXPath("""exists($output/ol:outline/ol:item[ol:title="Title Exists Once"]/olx:sameAs[olx:yes]/olx:uri="/data/original/title_exists_once-1")""",
          "The second file is referenced in the returned outline")
        .assertXPath("""exists(data:doc("/data/original/title_duplicated_and_subordinates_exist_with_same_pointers")//tei:sourceDesc/tei:bibl[tei:ptr[@type="bibl"]["/data/sources/test_outline_source"=@target]])""",
          "When the title is duplicated and sub-items exist, a reference to the source has been added to the file")
        .assertXPath("""exists(data:doc("/data/original/title_contains_source_one_time")//tei:sourceDesc/tei:bibl[tei:ptr[@type="bibl"]["/data/sources/test_outline_source"=@target]][tei:biblScope[@unit="pages"][@from="11"][@to="12"]])""",
          "When the title is confirmed and the source is already referenced, page numbers are added")
        .assertXPath("""count(data:doc("/data/original/title_has_source_and_pages_one_time")//tei:sourceDesc/tei:bibl[@j:docStatus="outlined"][tei:ptr/@target="/data/sources/test_outline_source"][count(tei:biblScope)=1])=1""",
          "When the title is confirmed and the source and pages already referenced, @j:docStatus is added to the tei:bibl and only 1 biblScope exists")
        .assertXPathEquals("""data:doc("/data/original/title_exists_once")/*""", "The confirmed negative duplicate file remains unchanged",
          readXmlFile("src/test/resources/api/data/outlines/title_exists_once.xml"))
        .go
    }
  }
  
  describe("outl:list") {
    it("lists all resources") {
      xq("""outl:list("", 1, 100)""")
        .assertSearchResults
        .assertXPath("""count($output//html:li[@class="result"])>=1""", "returns at least 1 result")
        .go
    }

    it("lists some resources") {
      xq("""outl:list("", 1, 1)""")
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"])=1""", "returns 1 result")
        .assertSearchResults
        .go
    }
    
    it("responds to a query") {
      xq("""outl:list("existing", 1, 100)""")
        .assertXPath("""count($output//html:ol[@class="results"]/html:li)=1""", "returns 1 result (existing)")
        .assertSearchResults
        .go
    }
  }
}

class TestOutlinesDelete extends DbTest with CommonTestOutlines {

  override def beforeEach(): Unit = {
    super.beforeEach()

    setupUsers(1)
    setupResource("src/test/resources/api/data/outlines/existing.xml", "existing", "outlines", 1)
  }

  override def afterEach(): Unit = {
    super.afterEach()

    teardownResource("existing", "outlines", 1)
    teardownUsers(1)
  }

  describe("outl:delete") {
    it("removes an existing resource") {
      xq("""outl:delete("existing")""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }
    
    it("does not remove an existing resource when unauthenticated") {
      xq("""outl:delete("existing")""")
        .assertHttpUnauthorized
        .go
    }

    it("fails to remove a nonexisting resource") {
      xq("""outl:delete("does_not_exist")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
  }
}