package org.opensiddur.api.data

import org.opensiddur.DbTest

class TestDataIndex extends DbTest {
  override val prolog: String =
    """xquery version '3.1';

import module namespace dindex="http://jewishliturgy.org/api/data/index"
  at "xmldb:exist:/db/apps/opensiddur-server/api/data/dindex.xqm";

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace http="http://expath.org/ns/http-client";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace o="http://a9.com/-/spec/opensearch/1.1/";
    """

  describe("dindex:list") {
    it("returns a discovery API") {
      xq("dindex:list()")
        .assertDiscoveryApi
        .assertSerializesAs(DbTest.HTML5_SERIALIZATION)
        .go
    }
  }

  describe("dindex:open-search") {
    it("returns an Open Search description") {
      xq("""dindex:open-search("")""")
        .assertXPath("""exists($output/self::o:OpenSearchDescription)""")
        .go
    }
  }
}
