xquery version "1.0";
(:~ controller.xql
 : Copyright 2010-2011 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3
 : 
 : This controller is used this to redirect or forward paths
 : if you are not logged in, you are forwarded to a a new user page
 : if you are logged in, you are forwarded to your own user profile page
 :)
declare namespace ex="http://exist.sourceforge.net/NS/exist";
declare namespace exist="http://exist.sourceforge.net/NS/exist";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace app="http://jewishliturgy.org/modules/app" at
	"/code/modules/app.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths" at
	"/code/modules/paths.xqm";
	
declare variable $local:path-to-here := '/code/apps/user';

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

if ($paths:debug)
then
	util:log-system-out(
	<debug from="user app controller">
		<user>{app:auth-user()}</user>
	  <uri>{request:get-uri()}</uri>
	  <path>{$exist:path}</path>
	  <root>{$exist:root}</root>
	  <controller>{$exist:controller}</controller>
	  <prefix>{$exist:prefix}</prefix>
	  <resource>{$exist:resource}</resource>
	</debug>
	)
else (),
if ($exist:path = ("/","") or $exist:resource = ('edit.xql', 'new.xql', 'edit', 'new')) 
then
	let $login := app:auth-user()
	return
		if ($login)
		then 
			<ex:dispatch>
				{app:pass-credentials-xq()}
				<ex:forward url="{$local:path-to-here}/edit.xql"/>
			</ex:dispatch>
		else
			<ex:dispatch>
				{app:pass-credentials-xq()}
				<ex:forward url="{$local:path-to-here}/new.xql"/>
			</ex:dispatch>
			
else
	<ex:ignore>
		{app:pass-credentials-xq()}
		<ex:cache-control cache="yes"/>
	</ex:ignore>
