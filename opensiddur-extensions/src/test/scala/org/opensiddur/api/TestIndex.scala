package org.opensiddur.api

import org.opensiddur.DbTest

class TestIndex extends DbTest {
  override val prolog: String =
    """xquery version '3.1';

import module namespace index="http://jewishliturgy.org/api/index"
  at "xmldb:exist:/db/apps/opensiddur-server/api/index.xqm";

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace http="http://expath.org/ns/http-client";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace o="http://a9.com/-/spec/opensearch/1.1/";
    """

  describe("index:list") {
    it("returns a discovery API") {
      xq("""index:list()""")
        .assertDiscoveryApi
        .go
    }
  }
}
