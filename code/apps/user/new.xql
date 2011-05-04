xquery version "1.0";
(:~ New user form
 :  
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :) 
import module namespace request="http://exist-db.org/xquery/request";
 
import module namespace app="http://jewishliturgy.org/modules/app" 
 	at "/code/modules/app.xqm";
import module namespace controls="http://jewishliturgy.org/modules/controls" 
 	at "/code/modules/controls.xqm"; 	
import module namespace site="http://jewishliturgy.org/modules/site" 
 	at "/code/modules/site.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths" 
 	at "/code/modules/paths.xqm";
import module namespace login="http://jewishliturgy.org/apps/user/login" 
	at "modules/login.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace ev="http://www.w3.org/2001/xml-events";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xf="http://www.w3.org/2002/xforms";

declare option exist:serialize "method=xhtml media-type=text/xml indent=yes omit-xml-declaration=no
	process-xsl-pi=no
	doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
	doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"; 

let $app-location := app:concat-path($paths:external-rest-prefix, '/code/apps/user')
let $instance-id := 'new-user'
let $control-id := 'control-new-user'
let $login-instance-id := 'login'
let $error-instance-id := concat($instance-id, '-error')
let $invalid-instance-id := concat($error-instance-id, '-invalid')
let $result-instance-id := concat($instance-id, '-result')
let $logged-in-user := app:auth-user()
let $user-name as xs:string? := request:get-parameter('item', $logged-in-user) 
let $new-user as xs:boolean := xs:boolean(request:get-parameter('new', string(empty($user-name))))
return (
 site:form(
 	<xf:model id="model">
 		{ 
 			login:login-instance($login-instance-id, (
 				'model',
 				site:sidebar-login-actions-id())),
 			controls:validator-instance-get(
				concat($control-id, '-user'), 
				controls:instance-to-ref(concat($instance-id, '-blank')),
				<xf:resource value="concat('/code/api/user/', instance('{$instance-id}')/user)"/>,
				false()
			),
			controls:error-instance($error-instance-id)
 		}
 		<xf:action id="new-login-actions" ev:event="login">
 			<xf:load show="replace" resource="{$app-location}/edit.xql">
 			</xf:load>
 		</xf:action>
 		<xf:instance id="{$instance-id}-blank">
 			<blank xmlns=""/>
 		</xf:instance>
 		<xf:instance id="{$instance-id}">
 			<new xmlns="">
 				<user/>
 				<password/>
 			</new>
 		</xf:instance>
 		<xf:instance id="{$instance-id}-repeat">
 			<repeat xmlns="">
 				<password/>
 			</repeat>
 		</xf:instance>
 		<xf:instance id="{$result-instance-id}">
 			<result xmlns=""/>
 		</xf:instance>
 		<xf:bind nodeset="instance('{$instance-id}')/user" required="true()" 
 			constraint="boolean-from-string(instance('{controls:validator-instance-id(concat($control-id,'-user'))}')/valid)"/>
 		<xf:bind nodeset="instance('{$instance-id}')/password"
 			type="xf:string"
 		  required="true()" 
 			constraint=". = instance('{$instance-id}-repeat')/password"/>
 		<xf:bind nodeset="instance('{$instance-id}-repeat')/password" 
 			type="xf:string"
 			required="true()"/>
 		<xf:submission id="{$instance-id}-submit"
 			ref="instance('{$instance-id}')/password"
 			instance="{$instance-id}-result"
 			replace="instance"
 			method="post">
 			<xf:resource value="concat('/code/api/user/', instance('{$instance-id}')/user,'?_method=PUT')"/>
 			{
 			controls:submission-response(
  			$error-instance-id,
  			(),
  			( (: reload after success :)
  				<xf:dispatch name="login" targetid="model"/>
  			)
  		)
 		}</xf:submission>
 	</xf:model>, 
 	<title>Create new user</title>,
 	(
 	<fieldset class="block-form">{
 		<xf:group id="{$control-id}" ref="instance('{$instance-id}')">
 			{controls:error-report($error-instance-id)}
 			<xf:input id="{$control-id}-user" ref="user" incremental="true">
	 			<xf:label>Username: </xf:label>
	 			{ 
	 			controls:validate-action(
					concat($control-id, '-user'), 
					'.', 
					true())
				}
				<xf:alert>Username already exists</xf:alert>
	 		</xf:input>
	 		<xf:secret id="{$control-id}-password" ref="password" incremental="true">
	 			<xf:label>Password: </xf:label>
			</xf:secret>
			<xf:secret id="{$control-id}-repeat-password" 
				ref="instance('{$instance-id}-repeat')/password" incremental="true">
	 			<xf:label>Repeat password: </xf:label>
			</xf:secret>
			<xf:submit submission="{$instance-id}-submit">
				<xf:label>Create new user</xf:label>
			</xf:submit>
 		</xf:group>,
 		controls:debug-show-instance($login-instance-id)
 	}</fieldset>
 	),
 	(
 		site:css(),
 		<link rel="stylesheet" type="text/css" href="styles/user.css" />
 	),
 	site:header(),
 	site:sidebar-with-login($login-instance-id),
 	site:footer())
)