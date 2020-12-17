xquery version "3.0";

(:~ Tests for utility API index
 : Copyright 2019 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace t = "http://test.jewishliturgy.org/api/test";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

import module namespace uindex="http://jewishliturgy.org/api/utility" at "../../api/utility/utilityindex.xqm";
import module namespace tcommon="http://jewishliturgy.org/test/tcommon" at "../tcommon.xqm";

declare
  %test:assertEmpty
  function t:uindex-list-returns-a-discovery-api() {
  tcommon:contains-discovery-api(uindex:list())
};