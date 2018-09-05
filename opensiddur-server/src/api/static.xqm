xquery version "3.1";
(:~ API module for accessing static data 
 : 
 : Copyright 2014 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed Under the GNU Lesser General Public License, version 3 or later
 :)
module namespace static = 'http://jewishliturgy.org/api/static';

import module namespace api="http://jewishliturgy.org/modules/api"
  at "../modules/api.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "../modules/paths.xqm";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(:~ List all static data 
 : @return An HTML list
 :)
declare 
  %rest:GET
  %rest:path("/api/static")
  %rest:produces("application/xhtml+xml", "text/html", "application/xml", "text/xml")
  function static:list(
  ) as item()+ {
  <rest:response>
    <output:serialization-parameters>
      <output:method>html5</output:method>
    </output:serialization-parameters>
  </rest:response>,
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Static API</title>
    </head>
    <body>
      <ul class="results">
        {
        let $api-base := api:uri-of("/api/static")
        let $collection := $paths:repo-base || "/static"
        for $resource in xmldb:get-child-resources($collection)
        order by $resource
        return 
          <li class="result">
            <a class="document" href="{$api-base}/{$resource}">{$resource}</a>
          </li>
        }
      </ul>
    </body>
  </html>
};

declare 
    %rest:GET
    %rest:path("/api/static/{$name}")
    %output:method("xml")
    %rest:produces("image/svg+xml", "application/xml", "text/xml")
    %output:media-type("image/svg+xml")
    function static:get(
        $name as xs:string
    ) as item()+ {
    let $collection := $paths:repo-base || "/static"
    let $resource-uri := $collection || "/" || $name 
    let $doc :=
        if (util:is-binary-doc($resource-uri))
        then util:binary-doc($resource-uri)
        else doc($resource-uri)
    return
        if ($doc)
        then 
        (
          <rest:response>
              <output:serialization-parameters>
                <output:media-type value="{xmldb:get-mime-type(xs:anyURI($resource-uri))}"/>
                <output:method>{if (util:is-binary-doc($resource-uri)) then 'binary' else 'xml'}</output:method>  
              </output:serialization-parameters>
          </rest:response>,
          $doc
        )
        else api:rest-error(404, "Not Found", $name)
};
