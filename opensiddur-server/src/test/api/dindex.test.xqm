xquery version "3.0";

(:~ Tests for data API index
 : Copyright 2019 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)

module namespace t = "http://test.jewishliturgy.org/api/test";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

import module namespace dindex="http://jewishliturgy.org/api/data/index" at "../../api/data/dindex.xqm";

import module namespace tcommon="http://jewishliturgy.org/test/tcommon" at "../tcommon.xqm";

declare namespace o="http://a9.com/-/spec/opensearch/1.1/";

declare
  %test:assertEmpty
  function t:dindex-list-returns-a-discovery-api() {
  tcommon:contains-discovery-api(dindex:list())
};

declare
  %test:assertEmpty
  function t:dindex-list-serializes-as-html5() {
  tcommon:serialize-as-html5(dindex:list())
};

declare
  %test:assertEmpty
  function t:dindex-open-search-returns-an-opensearch-description() {
  let $result := dindex:open-search("")
  let $test := $result/self::o:OpenSearchDescription
  where empty($test)
  return <error desc="an Open Search description was expected">{$result}</error>
};