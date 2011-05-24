xquery version "1.0";
(: output text data api controller.
 :
 : $Id: controller.xql 769 2011-04-29 00:02:54Z efraim.feinstein $
 :)
import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
	at "/code/api/modules/data.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/code/modules/paths.xqm";
	
declare namespace exist="http://exist.sourceforge.net/NS/exist";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

(: queries that handle specific subresources :)
declare variable $local:query-base := concat($exist:controller, '/../queries');

if ($paths:debug)
then
	util:log-system-out(
	<debug from="data/output api controller">
		<user>{app:auth-user()}:{app:auth-password()}</user>
	  <uri>{request:get-uri()}</uri>
	  <path>{$exist:path}</path>
	  <root>{$exist:root}</root>
	  <controller>{$exist:controller}</controller>
	  <prefix>{$exist:prefix}</prefix>
	  <resource>{$exist:resource}</resource>
	</debug>
	)
else (),
let $has-search-query := request:get-parameter('q', ())
let $uri := request:get-uri()
return
  if ($has-search-query)
  then
    <exist:dispatch>
      {app:pass-credentials-xq()}
      <exist:forward url="{$exist:controller}/../queries/search.xql">
        {data:path-to-parameters($uri)}
      </exist:forward>
    </exist:dispatch>
  else
    <exist:dispatch>
      {app:pass-credentials-xq()}
      <exist:forward url="{$exist:controller}/output.xql">
        {
        (: send all the normal parameters + the whole path :)
        data:path-to-parameters($uri)
        }
        <exist:add-parameter name="path" value="{$uri}"/>
      </exist:forward>
    </exist:dispatch>
