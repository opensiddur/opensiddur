xquery version "3.0";
(: run all pre-release tests :)
import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:///db/code/magic/magic.xqm";
import module namespace t="http://exist-db.org/xquery/testing/modified"
  at "xmldb:exist:///db/code/modules/test2.xqm";
import module namespace api="http://jewishliturgy.org/modules/api"
  at "xmldb:exist:///db/code/api/modules/api.xqm";

let $tests-to-run :=
  <tests>
    <test module="/db/code/tests/modules/common.t.xml"/>
    <test module="/db/code/tests/modules/mirror.t.xml"/>
    <test module="/db/code/tests/modules/follow-uri.t.xml"/>
    <test module="/db/code/tests/modules/refindex.t.xml"/>
    <test module="/db/code/tests/api/data.t.xml" admin="1"/>
    <test module="/db/code/tests/api/index.t.xml" />
    <test module="/db/code/tests/api/access.t.xml" />
    <test module="/db/code/tests/api/login.t.xml"/>
    <test module="/db/code/tests/api/user.t.xml"/>
    <test module="/db/code/tests/api/group.t.xml"/>
    <test module="/db/code/tests/api/data/dindex.t.xml"/>
    <test module="/db/code/tests/api/data/conditionals.t.xml"/>
    <test module="/db/code/tests/api/data/dictionaries.t.xml"/>
    <test module="/db/code/tests/api/data/linkage.t.xml"/>
    <test module="/db/code/tests/api/data/notes.t.xml"/>
    <test module="/db/code/tests/api/data/original.t.xml"/>
    <test module="/db/code/tests/api/data/styles.t.xml"/>
    <test module="/db/code/tests/api/data/sources.t.xml"/>
    <test module="/db/code/tests/api/data/transliteration.t.xml"/>
    <test module="/db/code/tests/api/utility/translit.t.xml"/>
    <test module="/db/code/tests/api/utility/utilityindex.t.xml"/>
    <test module="/db/code/tests/transforms/flatten/reverse.t.xml"/>
    <test module="/db/code/tests/transforms/flatten/unflatten.t.xml"/>
    <test module="/db/code/tests/transforms/flatten/combine.t.xml"/>
    <test module="/db/code/tests/transforms/translit/translit.t.xml"/>
    { ((: transforms :))}
    <!-- 
    <test module="/code/tests/transforms/flatten/intermediate-links.t.xml"/>
    <test module="/code/tests/transforms/flatten/resolve-internal.t.xml"/>
    <test module="/code/tests/transforms/flatten/set-priorities.t.xml"/>
    -->
  </tests>
return (
  api:serialize-as("xhtml", api:get-accept-format(("text/html","application/xhtml+xml"))),
  t:format-testResult(
    <TestSuites>{
      for $test in $tests-to-run/test
      let $as-admin := boolean($test/@admin)
      let $testSuite :=
        doc($test/@module)/TestSuite
      return
        if ($as-admin)
        then t:run-testSuite($testSuite, "admin", $magic:password)
        else t:run-testSuite($testSuite)
    }</TestSuites>
  )
)
