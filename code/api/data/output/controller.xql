xquery version "1.0";
(: output text data api controller.
 :
 :)
import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
	at "/code/api/modules/data.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
	at "/code/modules/debug.xqm";
	
declare namespace exist="http://exist.sourceforge.net/NS/exist";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

(: queries that handle specific subresources :)
declare variable $local:query-base := concat($exist:controller, '/../queries');


debug:debug($debug:info,
"/api/data",
<debug from="data/output api controller">
	<user>{app:auth-user()}:{app:auth-password()}</user>
  <uri>{request:get-uri()}</uri>
  <path>{$exist:path}</path>
  <root>{$exist:root}</root>
  <controller>{$exist:controller}</controller>
  <prefix>{$exist:prefix}</prefix>
  <resource>{$exist:resource}</resource>
</debug>
),
let $has-search-query := request:get-parameter('q', ())
let $uri := request:get-uri()
let $path-parts := data:path-to-parts($uri)
let $path-parameters := data:path-to-parameters($path-parts)
let $null := 
  util:log-system-out(("$path-parts for $uri=",$uri,"=", $path-parts, " $parameters=", $path-parameters))
return
  if ($has-search-query)
  then
    <exist:dispatch>
      {app:pass-credentials-xq()}
      <exist:forward url="{$exist:controller}/../queries/search.xql">
        {$path-parameters}
      </exist:forward>
    </exist:dispatch>
  else if ($path-parts/data:subresource = "status")
  then 
    <exist:dispatch>
      {app:pass-credentials-xq()}
      <exist:forward url="{$exist:controller}/status.xql">
        {$path-parameters}
        <exist:add-parameter name="path" value="{$uri}"/>
      </exist:forward>
    </exist:dispatch>
  else
    <exist:dispatch>
      {app:pass-credentials-xq()}
      <exist:forward url="{$exist:controller}/output.xql">
        {
        (: send all the normal parameters + the whole path :)
        $path-parameters
        }
        <exist:add-parameter name="path" value="{$uri}"/>
      </exist:forward>
    </exist:dispatch>
