xquery version "3.1";

(:~
: Common tests
:
: Copyright 2019 Efraim Feinstein <efraim@opensiddur.org>
: Open Siddur Project
: Licensed under the GNU Lesser General Public License, version 3 or later
:)

module namespace tcommon = "http://jewishliturgy.org/test/tcommon";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace format="http://jewishliturgy.org/modules/format"
  at "../modules/format.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "../modules/refindex.xqm";

(:~ test if a given returned index has a discovery API, return an error if it doesn't :)
declare function tcommon:contains-discovery-api(
  $result as item()*
  ) as element()? {
  let $test := $result/self::html:html/html:body/*[@class="apis"]/html:li[@class="api"]/html:a[@class="discovery"]
  where empty($test)
  return <error desc="expected a discovery api, got">{$result}</error>
};

(:~ test if an HTML5 serialization command is included :)
declare function tcommon:serialize-as-html5($result as item()*) as element()? {
  let $test := $result/self::rest:response/output:serialization-parameters/output:method="xhtml"
  where empty($test)
  return <error desc="expected serialization as HTML5, got">{$result}</error>
};

(:~ return a minimally "valid" TEI header :)
declare function tcommon:minimal-valid-header(
  $title as xs:string
) as element(tei:teiHeader) {
  <tei:teiHeader>
    <tei:fileDesc>
      <tei:titleStmt>
        <tei:title type="main">{$title}</tei:title>
      </tei:titleStmt>
      <tei:publicationStmt>
        <tei:distributor>
          <tei:ref target="http://opensiddur.org">Open Siddur Project</tei:ref>
        </tei:distributor>
        <tei:availability>
          <tei:licence target="http://www.creativecommons.org/publicdomain/zero/1.0"/>
        </tei:availability>
        <tei:date>2020-01-01</tei:date>
      </tei:publicationStmt>
      <tei:sourceDesc>
        <tei:bibl>
          <tei:ptr type="bibl" target="/data/sources/Born%20Digital"/>
          <tei:ptr type="bibl-content" target="#stream"/>
        </tei:bibl>
      </tei:sourceDesc>
    </tei:fileDesc>
    <tei:revisionDesc>
    </tei:revisionDesc>
  </tei:teiHeader>
};

(:~ set up a resource as if it had been added by API :)
declare function tcommon:setup-resource(
  $resource-name as xs:string,
  $data-type as xs:string,
  $content as item()
) as xs:string {
  let $name := xmldb:store("/db/data/" || $data-type, $resource-name || ".xml", $content)
  let $ridx := ridx:reindex(doc($name))
  return $name
};

(:~ remove a test resource :)
declare function tcommon:teardown-resource(
  $resource-name as xs:string,
  $data-type as xs:string
) {
  let $test-collection := "/db/data/" || $data-type
  return (
    format:clear-caches($test-collection || "/" || $resource-name),
    ridx:remove($test-collection, $resource-name),
    xmldb:remove($test-collection, $resource-name)
  )
};
