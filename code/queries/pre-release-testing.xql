xquery version "3.0";
(: run all pre-release tests :)
import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:///code/magic/magic.xqm";
import module namespace t="http://exist-db.org/xquery/testing/modified"
  at "xmldb:exist:///code/modules/test2.xqm";
import module namespace api="http://jewishliturgy.org/modules/api"
  at "/code/api/modules/api.xqm";

let $tests-to-run :=
  <tests>
    <test module="/code/tests/api/data.t.xml" admin="1"/>
    <test module="/code/tests/api/demo.t.xml"/>
    <test module="/code/tests/api/access.t.xml" />
    <test module="/code/tests/api/login.t.xml"/>
    <test module="/code/tests/api/user.t.xml"/>
    <test module="/code/tests/modules/mirror.t.xml" admin="1"/>
    <test module="/code/tests/api/data/dindex.t.xml"/>
    <test module="/code/tests/api/data/transliteration.t.xml"/>
    <test module="/code/tests/transforms/translit/translit.t.xml"/>
  </tests>
return (
  api:serialize-as("xhtml"),
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
