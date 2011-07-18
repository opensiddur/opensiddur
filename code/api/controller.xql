xquery version "1.0";
(: api controller.
 : forward the request to the given action with a .xql extension
 :
 :)
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/code/modules/paths.xqm";
	
declare namespace exist="http://exist.sourceforge.net/NS/exist";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

if ($paths:debug)
then
	util:log-system-out(
	<debug from="api controller">
	  <uri>{request:get-uri()}</uri>
	  <path>{$exist:path}</path>
	  <root>{$exist:root}</root>
	  <controller>{$exist:controller}</controller>
	  <prefix>{$exist:prefix}</prefix>
	  <resource>{$exist:resource}</resource>
	</debug>
	)
else (),
  if ($exist:resource = "OpenSearchDescription")
  then
    <exist:dispatch>
      <exist:forward url="{$exist:controller}/OpenSearchDescription.xql"/>
    </exist:dispatch>
  else if (ends-with($exist:resource, '.xql'))
  then
    <exist:ignore/>
  else if (not($exist:resource))
  then 
  	<exist:dispatch>
  		<exist:forward url="{$exist:controller}/index.xql"/>
  	</exist:dispatch>
  else
    <exist:dispatch/>

