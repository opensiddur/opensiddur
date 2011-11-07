xquery version "1.0";
(: api controller.
 : forward the request to the given action with a .xql extension
 :
 : Copyright 2010-2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
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


debug:debug($debug:info, "/api/user",
<debug from="user api controller">
	<user>{app:auth-user()}:{app:auth-password()}</user>
  <uri>{request:get-uri()}</uri>
  <path>{$exist:path}</path>
  <root>{$exist:root}</root>
  <controller>{$exist:controller}</controller>
  <prefix>{$exist:prefix}</prefix>
  <resource>{$exist:resource}</resource>
</debug>
),
if (ends-with($exist:resource, '.xql'))
then
  <exist:ignore/>
else if (not($exist:resource))
then
	<exist:dispatch>
		{app:pass-credentials-xq()}
		<exist:forward url="{$exist:controller}/index.xql">
			<exist:add-parameter name="user-name" value="{app:auth-user()}"/>
		</exist:forward>
	</exist:dispatch>
else if ($exist:resource = 'logout')
then
	<exist:dispatch>
		{app:pass-credentials-xq()}
		<exist:forward url="{$exist:controller}/logout.xql"/>
	</exist:dispatch> 
else 
	let $path := 
		if (starts-with($exist:path, '/'))
		then substring($exist:path, 2)
		else $exist:path
	return
		if (starts-with($path, 'login'))
		then 
			<exist:dispatch>
				<exist:forward url="{$exist:controller}/login.xql">
					{app:pass-credentials-xq()}
					<exist:add-parameter name="user-name" value="{substring-after($path,'/')}"/>
				</exist:forward>
			</exist:dispatch>  
		else 
			let $user-name :=
				if (contains($path, '/'))
				then 
					substring-before($path, '/')
				else
					$path
			let $property :=
				substring-after($path, '/')
			return
				(: attempt to access user profile :)
			  <exist:dispatch>
			  	{app:pass-credentials-xq()}
			  	<exist:forward url="{$exist:controller}/profile.xql">
			    	<exist:add-parameter name="user-name" value="{$user-name}"/>
			    	<exist:add-parameter name="property" value="{$property}"/>
			    </exist:forward>
			  </exist:dispatch>
