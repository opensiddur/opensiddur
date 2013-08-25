xquery version "3.0";
(:~ API module for functions for index URIs 
 : 
 : Functions assume that the following has already been done:
 :  authentication,
 :  content negotiation
 : 
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed Under the GNU Lesser General Public License, version 3 or later
 :)
module namespace index = 'http://jewishliturgy.org/api/index';

import module namespace api="http://jewishliturgy.org/modules/api"
  at "/db/code/api/modules/api.xqm";

declare namespace o="http://a9.com/-/spec/opensearch/1.1/";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

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
      <output:method value="html5"/>
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
            <a class="discovery" href="{$api-base}/data">Data</a>
          </li>,
          <li class="api">
            <a class="discovery" href="{$api-base}/demo">Demo</a>
          </li>,
          <li class="api">
            <a class="discovery" href="{$api-base}/group">Group</a>
          </li>,
          <li class="api">
            <a class="discovery" href="{$api-base}/login">Login</a>
          </li>,
          <li class="api">
            <a class="discovery" href="{$api-base}/logout">Logout</a>
          </li>,
          <li class="api">
            <a class="discovery" href="{$api-base}/user">User</a>
          </li>
        )
        }
      </ul>
    </body>
  </html>
};
