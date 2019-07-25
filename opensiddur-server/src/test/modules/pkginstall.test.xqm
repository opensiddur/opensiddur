xquery version "3.1";

module namespace t = "http://test.jewishliturgy.org/modules/pkginstall";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace deepequality="http://jewishliturgy.org/modules/deepequality" at "../../modules/deepequality.xqm";

import module namespace pkginstall="http://jewishliturgy.org/modules/pkginstall"
  at "../../modules/pkginstall.xqm";

(: pkginstall:duplicate-titles returns empty when there are no duplicate titles :)

(: pkginstall:duplicate-titles returns a list of documents with duplicate titles :)

(: :)