xquery version "1.0";
(: api controller.
 : forward the request to the given action with a .xql extension
 :
 : $Id: controller.xql 769 2011-04-29 00:02:54Z efraim.feinstein $
 :)
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
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
	<debug from="user api controller">
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
				if ($property)
				then 
					(: attempt to access user profile :)
				  <exist:dispatch>
				  	{app:pass-credentials-xq()}
				  	<exist:forward url="{$exist:controller}/profile.xql">
				    	<exist:add-parameter name="user-name" value="{$user-name}"/>
				    	<exist:add-parameter name="property" value="{$property}"/>
				    </exist:forward>
				  </exist:dispatch>			
				else 
					(: want a user index/find if user exists :)
				  <exist:dispatch>
				  	{app:pass-credentials-xq()}
				  	<exist:forward url="{$exist:controller}/user.xql">
				    	<exist:add-parameter name="user-name" value="{$user-name}"/>
				    </exist:forward>
				  </exist:dispatch>
