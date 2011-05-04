xquery version "1.0";
(: Login controls module
 : 
 :
 : Copyright 2010-2011 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: login.xqm 767 2011-04-28 18:15:42Z efraim.feinstein $
 :)
module namespace login="http://jewishliturgy.org/apps/user/login"; 

declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace util="http://exist-db.org/xquery/util";

import module namespace app="http://jewishliturgy.org/modules/app" at 
	"../../../modules/app.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths" at
	"../../../modules/paths.xqm";
import module namespace controls="http://jewishliturgy.org/modules/controls" at
	"../../../modules/controls.xqm";


declare variable $login:view-path := app:concat-path(($paths:prefix, $paths:apps, '/user/login.xql'));
declare variable $login:login-path := app:concat-path(($paths:prefix, $paths:apps, '/user/login.xql'));

(:~ login instance with no event target :)
declare function login:login-instance(
	$instance-id as xs:string) {
	login:login-instance($instance-id, ())
};

(:~ add the login form as an instance in an existing model.
 : The instance will dispatch 'login', 'logout', 'xforms-submit-done' and 'xforms-submit-error' 
 : events to the target control(s) $event-target
 :)
declare function login:login-instance(
	$instance-id as xs:string,
	$event-target as xs:string*) 
	as element()+ {
	let $error-instance-id := concat($instance-id, '-error')
	let $validation-error-instance-id := concat($instance-id, '-validation-error')
	let $result-instance-id := concat($instance-id, '-result')
	let $blank-instance-id := concat($instance-id, '-blank')
	let $login-user := app:auth-user()
	return (
		<xf:instance id="{$instance-id}">
			<login xmlns="">
				<loggedin>{$login-user}</loggedin>
				<user>{$login-user}</user>
				<password></password>
			</login>
		</xf:instance>,
		<xf:instance id="{$blank-instance-id}">
			<blank xmlns=""/>
		</xf:instance>,
		<xf:instance id="{$result-instance-id}">
			<result xmlns=""/>
		</xf:instance>,
    controls:error-instance($error-instance-id,
    	<exception>Login name and password must be filled in.</exception>
    ),
		<xf:bind nodeset="instance('{$instance-id}')/user" required="../loggedin = ''"/>,
		<xf:bind nodeset="instance('{$instance-id}')/password" required="../loggedin = ''"/>,
		<xf:submission id="{$instance-id}-login-submit" 
			method="post"  
			ref="instance('{$instance-id}')/password"
			replace="none">
			<xf:resource value="concat('/code/api/user/login/',instance('{$instance-id}')/user,'?_method=PUT')"/>
      {
      controls:submission-response(
        $error-instance-id,
        $event-target, (
        	<xf:setvalue ref="{controls:instance-to-ref($instance-id, '/loggedin')}" 
        		value="{controls:instance-to-ref($instance-id, '/user')}"/>,
				  <xf:toggle case="{$instance-id}-logout-form-case"/>,
          for $e-target in ($event-target)
          return <xf:dispatch name="login" targetid="{$e-target}"/>
        ))}
		</xf:submission>,
		<xf:submission id="{$instance-id}-logout-submit" 
			method="post" 
			action="/code/api/user/logout" 
			ref="instance('{$blank-instance-id}')"
			instance="{$result-instance-id}" 
			replace="none">
      {
      controls:submission-response(
        $error-instance-id,
        $event-target, (
          <xf:setvalue ref="instance('{$instance-id}')/loggedin" value="''"/>,
          <xf:setvalue ref="instance('{$instance-id}')/user" value="''"/>,
          <xf:setvalue ref="instance('{$instance-id}')/password" value="''"/>,
				  <xf:toggle case="{$instance-id}-login-form-case"/>,
          for $e-target in ($event-target)
          return <xf:dispatch name="logout" targetid="{$e-target}"/>
        ))}
		</xf:submission>,
		<xf:action ev:event="xforms-ready">
			<xf:toggle case="{
				if ($login-user) 
				then concat($instance-id,'-logout-form-case')
				else concat($instance-id, '-login-form-case')
				}"/>
			{
				for $e-target in $event-target
				return
					<xf:dispatch name="{if ($login-user) then 'login' else 'logout'}" 
						targetid="{$e-target}"/>
			}
		</xf:action>
	)
};

(:~ login form ui, long form
 :)
declare function login:login-ui(
	$instance-id as xs:string,
	$control-id as xs:string)
	as element() {
	login:login-ui($instance-id, $control-id, true())
};

(:~ login form UI 
 : The short form has fewer explanatory notes, so it is usable in sidebars
 : @param $instance-id Name of the instance
 : @param $control-id Name of the control
 : @param $long-form Use the long form of the login UI (default is true()) 
 :)
declare function login:login-ui(
	$instance-id as xs:string,
	$control-id as xs:string,
	$long-form as xs:boolean) 
	as element() {
	<xf:group ref="instance('{$instance-id}')" id="{$control-id}">
		{
		if ($long-form) 
		then 
			<xf:label>Database login</xf:label> 
		else ()
		}
		<div class="control control-login">
			<xf:switch>
				<xf:case id="{$instance-id}-login-form-case">
					{
					if ($long-form)
					then (
						<p>Log in to the database with your user name and password from the 
						<a href="http://wiki.jewishliturgy.org">Open Siddur Project wiki</a>.  If you do not yet have a user name, please
						<a href="http://wiki.jewishliturgy.org/w/index.php?title=Special:UserLogin&amp;type=signup">create one</a> and come back here.
						</p>
					)
					else ()					
					}
					<xf:group id="{$control-id}-login">
						{
						if ($paths:xforms-processor eq 'betterform')
						then attribute {'appearance'}{"minimal"}
						else ()
						}
						<xf:input ref="user" incremental="true">
							<xf:label>Username: </xf:label>
						</xf:input>
						<xf:secret ref="password" incremental="true">
							<xf:label>Password: </xf:label>
						</xf:secret>
						<xf:submit submission="{$instance-id}-login-submit">
							<xf:label>Login</xf:label>
						</xf:submit>
	   				{controls:error-report(concat($instance-id,'-error'))}
					</xf:group>
				</xf:case>
				<xf:case id="{$instance-id}-logout-form-case">
					<div class="control-login-as">You are logged in as <xf:output ref="loggedin" incremental="true"/> {(: for debugging: (<xf:output ref="auth" incremental="true"/>):)()}.</div> 
					<xf:submit submission="{$instance-id}-logout-submit">
						<xf:label>Logout</xf:label>
					</xf:submit>
				</xf:case>
			</xf:switch>
		</div>
	</xf:group>
};
