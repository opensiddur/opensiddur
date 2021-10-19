package org.opensiddur.modules

import org.opensiddur.DbTest

class TestValidation extends DbTest {
  /** imports, namespaces and variables */
  override val prolog: String =
    """xquery version '3.1';
       
import module namespace crest="http://jewishliturgy.org/modules/common-rest"
      at "xmldb:exist:///db/apps/opensiddur-server/modules/common-rest.xqm";
import module namespace orig="http://jewishliturgy.org/api/data/original"
  at "xmldb:exist:///db/apps/opensiddur-server/api/data/original.xqm";
import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:///db/apps/opensiddur-server/test/tcommon.xqm";  
  
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";
"""

  describe("orig:validate-report") {
    it("fails validation with an invalid license") {
      val bad = readXmlFile("src/test/resources/modules/validation/bad_license.xml")

      xq(s"""orig:validate-report(document { $bad }, ())""")
        .assertXPath("""$output/status="invalid" """)
        .go
    }

    it("succeeds validation with a valid license") {
      val good = readXmlFile("src/test/resources/modules/validation/good_license.xml")

      xq(s"""orig:validate-report(document { $good }, ())""")
        .assertXPath("""$output/status="valid" """)
        .go
    }
  }

}
