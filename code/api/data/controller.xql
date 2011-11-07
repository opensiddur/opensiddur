xquery version "1.0";
(: data api controller.
 :
 :)
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
	at "/code/modules/debug.xqm";
	
declare namespace exist="http://exist.sourceforge.net/NS/exist";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

debug:debug($debug:info,
  "/api/data",
	<debug from="data api controller">
		<user>{app:auth-user()}:{app:auth-password()}</user>
	  <uri>{request:get-uri()}</uri>
	  <path>{$exist:path}</path>
	  <root>{$exist:root}</root>
	  <controller>{$exist:controller}</controller>
	  <prefix>{$exist:prefix}</prefix>
	  <resource>{$exist:resource}</resource>
	</debug>
	),
if (not($exist:resource) or $exist:resource = 'data.xql')
then
	<exist:dispatch>
		{app:pass-credentials-xq()}
		<exist:forward url="{$exist:controller}/data.xql"/>
	</exist:dispatch>
else
	<exist:dispatch>
		{app:pass-credentials-xq()}
	</exist:dispatch>