xquery version "3.0";

(:~ Tests for API index
 : Copyright 2019 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)

module namespace t = "http://test.jewishliturgy.org/api/test";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

import module namespace index="http://jewishliturgy.org/api/index" at "../../api/index.xqm";

import module namespace tcommon="http://jewishliturgy.org/test/tcommon" at "../tcommon.xqm";

declare
  %test:assertEmpty
  function t:index-list-returns-a-discovery-api() {
  tcommon:contains-discovery-api(index:list())
};