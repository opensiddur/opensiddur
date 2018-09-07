xquery version "3.1";
(:~ API module for functions for index URIs 
 : 
 : Copyright 2012-2014 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed Under the GNU Lesser General Public License, version 3 or later
 :)
module namespace index = 'http://jewishliturgy.org/api/index';

import module namespace api="http://jewishliturgy.org/modules/api"
  at "../modules/api.xqm";

declare namespace o="http://a9.com/-/spec/opensearch/1.1/";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(:~ display an element if a package is installed :)
declare 
  %private 
  function index:if-installed(
    $package as xs:string,
    $item as element()
  ) as element()? {
  let $pkgs := repo:list()
  where $pkgs = $package
  return $item
};

(:~ List all available APIs 
 : @return An HTML list
 :)
declare 
  %rest:GET
  %rest:path("/api")
  %rest:produces("application/xhtml+xml", "text/html", "application/xml", "text/xml")
  function index:list(
  ) as item()+ {
  <rest:response>
    <output:serialization-parameters>
      <output:method>xhtml</output:method>
    </output:serialization-parameters>
  </rest:response>,
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Open Siddur API Index</title>
    </head>
    <body>
      <ul class="apis">
        {
        let $api-base := api:uri-of("/api")
        return (
          <li class="api">
            <a class="discovery" href="{$api-base}/changes">Recent changes</a>
          </li>,
          <li class="api">
            <a class="discovery" href="{$api-base}/data">Data</a>
          </li>,
          index:if-installed(
            "http://jewishliturgy.org/apps/opensiddur-demos",
            <li class="api">
              <a class="discovery" href="{$api-base}/demo">Demo</a>
            </li>
          ),
          <li class="api">
            <a class="discovery" href="{$api-base}/group">Group</a>
          </li>,
          <li class="api">
            <a class="discovery" href="{$api-base}/jobs">Jobs (compilation)</a>
          </li>,
          <li class="api">
            <a class="discovery" href="{$api-base}/login">Login</a>
          </li>,
          <li class="api">
            <a class="discovery" href="{$api-base}/logout">Logout</a>
          </li>,
          <li class="api">
            <a class="discovery" href="{$api-base}/static">Static files</a>
          </li>,
          index:if-installed(
            "http://jewishliturgy.org/apps/opensiddur-tests",
            <li class="api">
              <a class="discovery" href="{$api-base}/tests">Tests</a>
            </li>
          ),
          <li class="api">
            <a class="discovery" href="{$api-base}/user">User</a>
          </li>
        )
        }
      </ul>
    </body>
  </html>
};
