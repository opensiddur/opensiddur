package org.opensiddur.api.utility

import org.opensiddur.DbTest

class TestUtilityIndex extends DbTest {
  override val prolog: String =
    """xquery version '3.1';

import module namespace uindex="http://jewishliturgy.org/api/utility"
  at "xmldb:exist:/db/apps/opensiddur-server/api/utility/utilityindex.xqm";

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace http="http://expath.org/ns/http-client";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace o="http://a9.com/-/spec/opensearch/1.1/";
    """
  describe("uindex:list") {
    it("returns a discovery API") {
      xq("""uindex:list()""")
        .assertDiscoveryApi
        .go
    }
  }
}
