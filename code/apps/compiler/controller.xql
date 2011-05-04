xquery version "1.0";
(: controller for compiler.
 : logs in the demo user and passes on to compiler.xql
 : $Id: controller.xql 765 2011-04-27 21:32:17Z efraim.feinstein $
 :)
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
	
declare variable $local:demouser := 'demouser';
declare variable $local:demopassword := 'resuomed';

let $x := 
	if (app:auth-user())
	then ()
	else (
		xmldb:login('/db', $local:demouser, $local:demopassword, true()),
		app:login-credentials($local:demouser, $local:demopassword)
	)
return
	if (not($exist:resource) or $exist:resource = 'compiler.xql')
	then (
		<exist:dispatch>
			<exist:set-attribute name="xquery.user" value="{$local:demouser}"/>
			<exist:set-attribute name="xquery.password" value="{$local:demopassword}"/>
			<exist:forward url="{$exist:controller}/compiler.xql"/>
		</exist:dispatch>
		)
	else (
		<exist:ignore/>
	)