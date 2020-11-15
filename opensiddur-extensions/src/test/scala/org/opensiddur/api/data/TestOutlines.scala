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
    setupResource("src/test/resources/api/data/outlines/Existing.xml", "Existing", "outlines", 1)
    setupResource("src/test/resources/api/data/outlines/TestEverythingOK.xml", "TestEverythingOK", "outlines", 1)
    setupResource("src/test/resources/api/data/outlines/TestOutline.xml", "TestOutline", "outlines", 1)
    setupResource("src/test/resources/api/data/outlines/TitleExistsOnce.xml", "TitleExistsOnce", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/TitleExistsOnceWithSource.xml", "TitleExistsOnceWithSource", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/TitleExistsOnceWithSourceAndPages.xml", "TitleExistsOnceWithSourceAndPages", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/TitleExistsTwice.xml", "TitleExistsTwice", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/TitleExistsTwice-1.xml", "TitleExistsTwice-1", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/TitleAlreadyConfirmed.xml", "TitleAlreadyConfirmed", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/TitleAlreadyConfirmedAndDuplicated.xml", "TitleAlreadyConfirmedAndDuplicated", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/TitleAlreadyConfirmedAndDuplicated-1.xml", "TitleAlreadyConfirmedAndDuplicated-1", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/TitleDuplicatedAndSubordinatesExistWithSamePointers.xml", "TitleDuplicatedAndSubordinatesExistWithSamePointers", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/TitleDuplicatedAndSubordinatesExistWithDifferentPointers.xml", "TitleDuplicatedAndSubordinatesExistWithDifferentPointers", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/SubOne.xml", "SubOne", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/SubTwo.xml", "SubTwo", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/HasAStatus.xml", "HasAStatus", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/TestOutlineWithError.xml", "TestOutlineWithError", "outlines", 1)
    setupResource("src/test/resources/api/data/outlines/TestOutlineWithUnconfirmed.xml", "TestOutlineWithUnconfirmed", "outlines", 1)
    setupResource("src/test/resources/api/data/outlines/HasUnconfirmed.xml", "HasUnconfirmed", "original", 1, Some("en"))
    setupResource("src/test/resources/api/data/outlines/TestOutlineSource.xml", "TestOutlineSource", "sources", 1)
    setupResource("src/test/resources/api/data/outlines/TestOutlineExecutable.xml", "TestOutlineExecutable", "outlines", 1)
    setupResource("src/test/resources/api/data/outlines/TestOutlineExecutableWithDuplicates.xml", "TestOutlineExecutableWithDuplicates", "outlines", 1)
    setupResource("src/test/resources/api/data/outlines/TestOutlineExecutableWithExternalDuplicates.xml", "TestOutlineExecutableWithExternalDuplicates", "outlines", 1)
  }

  override def afterAll()  {
    teardownResource("TestOutlineExecutableWithExternalDuplicates", "original", 1)
    teardownResource("TestOutlineExecutableWithExternalDuplicates", "outlines", 1)
    teardownResource("TestOutlineExecutableWithDuplicates", "original", 1)
    teardownResource("TestOutlineExecutableWithDuplicates", "outlines", 1)
    teardownResource("TestOutlineExecutableDuplicate", "original", 1)
    teardownResource("TestOutlineExecutableDuplicateWithItems", "original", 1)
    teardownResource("TestSubOne", "original", 1)
    teardownResource("TestSubTwo", "original", 1)
    teardownResource("TestOutlineExecutable", "original", 1)
    teardownResource("TestOutlineExecutableNewTitle", "original", 1)
    teardownResource("TestOutlineExecutable", "outlines", 1)
    teardownResource("TestOutlineSource", "sources", 1)
    teardownResource("HasUnconfirmed", "original", 1)
    teardownResource("TestOutlineWithUnconfirmed", "outlines", 1)
    teardownResource("TestOutlineWithError", "outlines", 1)
    teardownResource("HasAStatus", "original", 1)
    teardownResource("SubTwo", "original", 1)
    teardownResource("SubOne", "original", 1)
    teardownResource("TitleDuplicatedAndSubordinatesExistWithDifferentPointers", "original", 1)
    teardownResource("TitleDuplicatedAndSubordinatesExistWithSamePointers", "original", 1)
    teardownResource("TitleAlreadyConfirmedAndDuplicated-1", "original", 1)
    teardownResource("TitleAlreadyConfirmedAndDuplicated", "original", 1)
    teardownResource("TitleAlreadyConfirmed", "original", 1)
    teardownResource("TitleExistsTwice-1", "original", 1)
    teardownResource("TitleExistsTwice", "original", 1)
    teardownResource("TitleExistsOnceWithSource-1", "original", 1)
    teardownResource("TitleExistsOnceWithSource", "original", 1)
    teardownResource("TitleExistsOnceWithSourceAndPages-1", "original", 1)
    teardownResource("TitleExistsOnceWithSourceAndPages", "original", 1)
    teardownResource("TitleExistsOnce-1", "original", 1)
    teardownResource("TitleExistsOnce", "original", 1)
    teardownResource("TestOutline", "outlines", 1)
    teardownResource("TestEverythingOK", "outlines", 1)
    teardownResource("Existing", "outlines", 1)
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
      xq("""outl:get("Existing", ())""")
        .assertXPath("""exists($output/ol:outline)""", "Returns a TEI resource")
        .go
    }
    
    it("fails to get a nonexisting resource, no check") {
      xq("""outl:get("DoesNotExist", ())""")
        .assertHttpNotFound
        .go
    }

    it("gets an existing resource, with identity check") {
      val identity = readXmlFile("src/test/resources/api/data/outlines/TestEverythingOK.xml")
      xq("""outl:get("TestEverythingOK", "1")/*""")
        .assertXmlEquals(identity)
        .go
    }

    it("gets an existing resource, with logic check") {
      xq("""outl:get("TestOutline", "1")""")
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
              <ol:title>TitleExistsOnce</ol:title>
              <ol:from>3</ol:from>
              <ol:to>4</ol:to>
              <olx:sameAs>
                <olx:uri>/data/original/TitleExistsOnce</olx:uri>
              </olx:sameAs>
          </ol:item>""")
        .assertXPathEquals("$output/ol:outline/ol:item[3]",
        "for each item with a duplicate title external to the outline without a duplication confirmation, " +
          "return an olx:sameAs with an olx:uri for each duplicate entry (title exists more than once)",
        """<ol:item>
              <ol:title>TitleExistsTwice</ol:title>
              <ol:from>5</ol:from>
              <ol:to>6</ol:to>
              <olx:sameAs>
                <olx:uri>/data/original/TitleExistsTwice</olx:uri>
              </olx:sameAs>
              <olx:sameAs>
                <olx:uri>/data/original/TitleExistsTwice-1</olx:uri>
              </olx:sameAs>
          </ol:item>""")
        .assertXPathEquals("$output/ol:outline/ol:item[4]",
        "for an item with a duplicate title that is already confirmed, the confirmation is maintained exactly",
        """<ol:item>
              <ol:title>TitleAlreadyConfirmed</ol:title>
              <ol:from>7</ol:from>
              <ol:to>8</ol:to>
              <olx:sameAs>
                  <olx:uri>/data/original/TitleAlreadyConfirmed</olx:uri>
                  <olx:yes/>
              </olx:sameAs>
          </ol:item>""")
        .assertXPathEquals("$output/ol:outline/ol:item[5]",
          "for an item with a duplicate title that is already confirmed and duplicated again, " +
            "the confirmation is maintained exactly and the additional duplicate is recorded with a negative confirmation",
        """<ol:item>
              <ol:title>TitleAlreadyConfirmedAndDuplicated</ol:title>
              <ol:from>9</ol:from>
              <ol:to>10</ol:to>
              <olx:sameAs>
                  <olx:uri>/data/original/TitleAlreadyConfirmedAndDuplicated</olx:uri>
                  <olx:yes/>
              </olx:sameAs>
              <olx:sameAs>
                  <olx:uri>/data/original/TitleAlreadyConfirmedAndDuplicated-1</olx:uri>
                  <olx:no/>
              </olx:sameAs>
          </ol:item>""")
        .assertXPathEquals("$output/ol:outline/ol:item[6]",
          "Title already exists and has subordinates that are referenced and have the same pointers in the same order",
          """<ol:item>
            <ol:title>TitleDuplicatedAndSubordinatesExistWithSamePointers</ol:title>
            <ol:from>11</ol:from>
            <ol:to>12</ol:to>
            <olx:sameAs>
              <olx:uri>/data/original/TitleDuplicatedAndSubordinatesExistWithSamePointers</olx:uri>
            </olx:sameAs>
            <ol:item>
              <ol:title>SubOne</ol:title>
              <olx:sameAs>
                <olx:uri>/data/original/SubOne</olx:uri>
              </olx:sameAs>
            </ol:item>
            <ol:item>
              <ol:title>SubTwo</ol:title>
              <olx:sameAs>
                <olx:uri>/data/original/SubTwo</olx:uri>
              </olx:sameAs>
            </ol:item>
          </ol:item>"""
        )
        .assertXPathEquals("$output/ol:outline/ol:item[7]",
        "Title already exists and has subordinates that are referenced and have the same pointers in different order",
        """<ol:item>
            <ol:title>TitleDuplicatedAndSubordinatesExistWithDifferentPointers</ol:title>
            <ol:from>13</ol:from>
            <ol:to>14</ol:to>
            <olx:sameAs>
              <olx:uri>/data/original/TitleDuplicatedAndSubordinatesExistWithDifferentPointers</olx:uri>
              <olx:warning>...</olx:warning>
            </olx:sameAs>
            <ol:item>
              <ol:title>SubTwo</ol:title>
              <olx:sameAs>
                <olx:uri>/data/original/SubTwo</olx:uri>
              </olx:sameAs>
            </ol:item>
            <ol:item>
              <ol:title>SubOne</ol:title>
              <olx:sameAs>
                <olx:uri>/data/original/SubOne</olx:uri>
              </olx:sameAs>
            </ol:item>
          </ol:item>""")
        .assertXPathEquals("$output/ol:outline/ol:item[8]",
          "if the document has a confirmed identity and a status with respect to the source, the status is returned",
          """<ol:item>
            <ol:title>HasAStatus</ol:title>
            <ol:from>15</ol:from>
            <ol:to>16</ol:to>
            <olx:sameAs>
              <olx:uri>/data/original/HasAStatus</olx:uri>
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
      xq("""outl:post-execute("TestOutlineWithError")""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
    
    it("fails on an outline file with an unconfirmed olx:sameAs") {
      xq("""outl:post-execute("TestOutlineWithUnconfirmed")""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
    
    it("executes an executable outline") {
      val expectedResult = readXmlFile("src/test/resources/api/data/outlines/TestOutlineExecutableResult.xml")
      xq("""outl:post-execute("TestOutlineExecutable")""")
        .user("xqtest1")
        .assertXPathEquals("$output/*", "Result is a copy of the rewritten outline", expectedResult)
        .assertXPathEquals("""doc("/db/data/outlines/TestOutlineExecutable.xml")/*""",
          "the original outline file has been rewritten to correspond to the new data from execution",
         expectedResult)
        .assertXPath("""exists(data:doc("/data/original/TestOutlineExecutable"))""", "the outline main file exists")
        .assertXPath("""contains(document-uri(data:doc("/data/original/TestOutlineExecutable")), "/en")""", "the outline main file is placed in the correct collection for its language")
        .assertXPath("""data:doc("/data/original/TestOutlineExecutable")//tei:titleStmt/tei:title[@type="main"]="TestOutlineExecutable"""", "the outline main file has the correct title")
        .assertXPath("""data:doc("/data/original/TestOutlineExecutable")/tei:TEI/@xml:lang="en"""", "the outline main file references the correct xml:lang")
        .assertXPath("""data:doc("/data/original/TestOutlineExecutable")//tei:availability/tei:licence/@target="http://www.creativecommons.org/publicdomain/zero/1.0"""", "the outline main file references the correct license")
        .assertXPath("""data:doc("/data/original/TestOutlineExecutable")//tei:sourceDesc/tei:bibl[@j:docStatus="outlined"]/tei:ptr[@type="bibl"]/@target="/data/sources/TestOutlineSource"""", "the outline main file references the correct source and status")
        .assertXPath("""data:doc("/data/original/TestOutlineExecutable")//j:streamText/tei:ptr/@target="/data/original/TestOutlineExecutableNewTitle#stream"""", "the outline main file has a streamText containing a pointer to the included file")
        .assertXPath("""empty(data:doc("/data/original/TestOutlineExecutable")//j:streamText/tei:seg)""", "the outline main file streamText filler has been removed")
        .assertXPath("""count(data:doc("/data/original/TestOutlineExecutable")//tei:revisionDesc/tei:change[@type="created"])=1""", "the outline main file has 1 creation change record")
        .assertXPath("""count(data:doc("/data/original/TestOutlineExecutable")//tei:revisionDesc/tei:change[@type="edited"])=1""", "the outline main file has 1 edit change record")
        .assertXPath("""exists(data:doc("/data/original/TestOutlineExecutableNewTitle"))""", "the outline included file exists")
        .assertXPath("""contains(document-uri(data:doc("/data/original/TestOutlineExecutableNewTitle")), "/en")""", "the outline included file is placed in the correct collection for its language")
        .assertXPath("""data:doc("/data/original/TestOutlineExecutableNewTitle")//tei:titleStmt/tei:title[@type="main"]="TestOutlineExecutableNewTitle"""", "the outline included file has the correct title")
        .assertXPath("""data:doc("/data/original/TestOutlineExecutableNewTitle")/tei:TEI/@xml:lang="en"""", "the outline included file references the correct xml:lang")
        .assertXPath("""data:doc("/data/original/TestOutlineExecutableNewTitle")//tei:availability/tei:licence/@target="http://www.creativecommons.org/publicdomain/zero/1.0"""", "the outline included file references the correct license")
        .assertXPath("""data:doc("/data/original/TestOutlineExecutableNewTitle")//tei:titleStmt/tei:respStmt[tei:resp[@key="trc"][.="Transcribed by"]][tei:name[@ref="/user/xqtest1"]]""", "the outline included file references a contributor credit")
        .assertXPath("""data:doc("/data/original/TestOutlineExecutableNewTitle")//tei:sourceDesc/tei:bibl[@j:docStatus="outlined"][tei:biblScope[@unit="pages"][@from="1"][@to="2"]]/tei:ptr[@type="bibl"]/@target="/data/sources/TestOutlineSource"""", "the outline included file references the correct source, status, and page numbers")
        .assertXPath("""count(data:doc("/data/original/TestOutlineExecutableNewTitle")//j:streamText/tei:seg)=2""", "the outline included file has a streamText containing filler")
        .assertXPath("""count(data:doc("/data/original/TestOutlineExecutableNewTitle")//tei:revisionDesc/tei:change[@type="created"])=1""", "the outline included file has 1 creation change record")
        .assertXPath("""count(data:doc("/data/original/TestOutlineExecutableNewTitle")//tei:revisionDesc/tei:change[@type="edited"])=0""", "the outline included file has no edit change records")
        .go
    }
    
    it("executes an outline with duplicates") {
      xq("""outl:post-execute("TestOutlineExecutableWithDuplicates")""")
        .user("xqtest1")
        .assertXPath("""exists(data:doc("/data/original/TestOutlineExecutableWithDuplicates"))""", "the outline main file exists")
        .assertXPath("""
        let $d := data:doc("/data/original/TestOutlineExecutableWithDuplicates")
        let $st := $d//j:streamText
        return
          count($st/tei:ptr[@target='/data/original/TestOutlineExecutableDuplicate#stream'])=2 and 
          count($st/tei:ptr[@target='/data/original/TestOutlineExecutableDuplicateWithItems#stream'])=2
      """, "The main outline file references TestOutlineExecutableDuplicate 2x and TestOutlineExecutableDuplicateWithItems 2x")
          .assertXPath("""count(collection("/db/data/original/en")/tei:TEI[descendant::tei:titleStmt/tei:title[@type="main"][.="TestOutlineExecutableDuplicate"]])=1""", 
            "Documents with the title TestOutlineExecutableDuplicate exist only once")
          .assertXPath("""count(data:doc("/data/original/TestOutlineExecutableDuplicate")//tei:revisionDesc/tei:change)=1""", 
            "TestOutlineExecutableDuplicate has been written to once on creation, since it has no filler pointers")
          .assertXPath("""
        let $b := data:doc("/data/original/TestOutlineExecutableDuplicate")//tei:sourceDesc/tei:bibl
        return
          count($b/tei:biblScope)=2
          and exists($b/tei:biblScope[@unit='pages'][@from='1'][@to='2'])
          and exists($b/tei:biblScope[@unit='pages'][@from='3'][@to='4'])
        """, "TestOutlineExecutableDuplicate references two different page ranges")
          .assertXPath("""count(collection("/db/data/original/en")/tei:TEI[descendant::tei:titleStmt/tei:title[@type="main"][.="TestOutlineExecutableDuplicateWithItems"]])=1""", 
            "Documents with the title TestOutlineExecutableDuplicateWithItems exist only once")
          .assertXPath("""
            let $st := data:doc("/data/original/TestOutlineExecutableDuplicateWithItems")//j:streamText
            return exists($st/tei:ptr[1]["/data/original/TestSubOne#stream"=@target])
            and exists($st/tei:ptr[2]["/data/original/TestSubTwo#stream"=@target])
          """, "TestOutlineExecutableDuplicateWithItems has a streamText that points to its two subordinates")
          .assertXPath("""exists(data:doc("/data/original/TestSubOne"))""", "TestSubOne exists")
          .assertXPath("""exists(data:doc("/data/original/TestSubTwo"))""", "TestSubTwo exists")
          .assertXPathEquals("$output/*", "The return outline contains the expected data and references",
            readXmlFile("src/test/resources/api/data/outlines/TestOutlineExecutableWithDuplicatesResult.xml"))
          .go
    }

    it("executes an outline containing external duplicate references") {
      xq("""outl:post-execute("TestOutlineExecutableWithExternalDuplicates")""")
        .user("xqtest1")
        .assertXPath("""exists(data:doc("/data/original/TestOutlineExecutableWithExternalDuplicates"))""", "the outline main file exists")
        /*.assertXPath("""count(collection("/db/data/original/en")//tei:titleStmt/tei:title[@type="main"][.="TitleAlreadyConfirmedAndDuplicated"])=1""",
          "There is only file with the same title as the confirmed resource")*/
        .assertXPath("""exists(data:doc("/data/original/TitleAlreadyConfirmedAndDuplicated")//tei:sourceDesc/tei:bibl[@j:docStatus="outlined"]/tei:ptr[@type="bibl"]["/data/sources/TestOutlineSource"=@target])""",
          "A reference to the source has been added to the confirmed resource")
        .assertXPath("""exists(data:doc("/data/original/TitleAlreadyConfirmedAndDuplicated")//tei:sourceDesc/tei:bibl[@j:docStatus="outlined"]/tei:biblScope[@unit="pages"][@from="1"][@to="2"])""",
          "A reference to the source's pages has been added to the confirmed resource")
        .assertXPath("""exists(data:doc("/data/original/TitleAlreadyConfirmedAndDuplicated")//tei:revisionDesc/tei:change[1][@type="edited"][contains(., "outline tool")])""",
          "An edited by change record has been added to the confirmed resource")
        .assertXPath(
          """every $resource in ("TitleAlreadyConfirmedAndDuplicated", "TitleDuplicatedAndSubordinatesExistWithSamePointers", "TitleExistsOnceWithSource", "TitleExistsOnceWithSourceAndPages") satisfies
            count($output//ol:item[ol:title=$resource]/olx:sameAs[olx:yes])=1""",
          "For each confirmed resource, a single olx:sameAs[olx:yes] record exists in the output outline")
        .assertXPath("""data:doc("/data/original/TitleAlreadyConfirmedAndDuplicated")//j:streamText/tei:seg[1]="Test data."""",
          "The text data in the confirmed resource has not been overwritten")
        .assertXPath("""exists(data:doc("/data/original/TitleExistsOnce-1"))""",
          "A second file with the same title and different URI as the confirmed negative file has been created")
        .assertXPath("""exists($output/ol:outline/ol:item[ol:title="TitleExistsOnce"]/olx:sameAs[olx:yes]/olx:uri="/data/original/TitleExistsOnce-1")""",
          "The second file is referenced in the returned outline")
        .assertXPath("""exists(data:doc("/data/original/TitleDuplicatedAndSubordinatesExistWithSamePointers")//tei:sourceDesc/tei:bibl[tei:ptr[@type="bibl"]["/data/sources/TestOutlineSource"=@target]])""",
          "When the title is duplicated and sub-items exist, a reference to the source has been added to the file")
        .assertXPath("""exists(data:doc("/data/original/TitleExistsOnceWithSource")//tei:sourceDesc/tei:bibl[tei:ptr[@type="bibl"]["/data/sources/TestOutlineSource"=@target]][tei:biblScope[@unit="pages"][@from="11"][@to="12"]])""",
          "When the title is confirmed and the source is already referenced, page numbers are added")
        .assertXPath("""count(data:doc("/data/original/TitleExistsOnceWithSourceAndPages")//tei:sourceDesc/tei:bibl[@j:docStatus="outlined"][tei:ptr/@target="/data/sources/TestOutlineSource"][count(tei:biblScope)=1])=1""",
          "When the title is confirmed and the source and pages already referenced, @j:docStatus is added to the tei:bibl and only 1 biblScope exists")
        .assertXPathEquals("""data:doc("/data/original/TitleExistsOnce")/*""", "The confirmed negative duplicate file remains unchanged",
          readXmlFile("src/test/resources/api/data/outlines/TitleExistsOnce.xml"))
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
      xq("""outl:list("Existing", 1, 100)""")
        .assertXPath("""count($output//html:ol[@class="results"]/html:li)=1""", "returns 1 result (Existing)")
        .assertSearchResults
        .go
    }
  }
}

class TestOutlinesDelete extends DbTest with CommonTestOutlines {

  override def beforeEach(): Unit = {
    super.beforeEach()

    setupUsers(1)
    setupResource("src/test/resources/api/data/outlines/Existing.xml", "Existing", "outlines", 1)
  }

  override def afterEach(): Unit = {
    super.afterEach()

    teardownResource("Existing", "outlines", 1)
    teardownUsers(1)
  }

  describe("outl:delete") {
    it("removes an existing resource") {
      xq("""outl:delete("Existing")""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }
    
    it("does not remove an existing resource when unauthenticated") {
      xq("""outl:delete("Existing")""")
        .assertHttpUnauthorized
        .go
    }

    it("fails to remove a nonexisting resource") {
      xq("""outl:delete("DoesNotExist")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
  }
}