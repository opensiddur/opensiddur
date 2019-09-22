xquery version "3.1";

(:~
: Common tests
:
: Copyright 2019 Efraim Feinstein <efraim@opensiddur.org>
: Open Siddur Project
: Licensed under the GNU Lesser General Public License, version 3 or later
:)

module namespace tcommon = "http://jewishliturgy.org/test/tcommon";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

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