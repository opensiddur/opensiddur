xquery version "1.0";
(:~ User profile editor
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
import module namespace user="http://jewishliturgy.org/modules/user" 
 	at "/code/modules/user.xqm";
import module namespace login="http://jewishliturgy.org/apps/user/login" 
	at "modules/login.xqm";
import module namespace uctrl="http://jewishliturgy.org/apps/user/controls" 
 	at "modules/user.xqm";
	

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
let $save-status-instance-id := 'save'
let $instance-id := 'profile'
let $error-instance-id := 'profile-error'
let $control-id := 'control-profile'
let $login-instance-id := 'login'
let $user-name := app:auth-user()
return (
 site:form(
 	<xf:model id="model">
 		{ 
 			login:login-instance($login-instance-id, 
 				(
 				'model',
 				site:sidebar-login-actions-id()
 				)
 			),
 			controls:save-flag-instance($save-status-instance-id),
 			controls:error-instance($error-instance-id)
 		}
 		<xf:instance id="{$instance-id}">
 			{$user:profile-prototype}
 		</xf:instance>
 		<xf:bind id="{$instance-id}-name" nodeset="instance('{$instance-id}')/tei:name" 
 			type="xf:string"/>
 		<xf:bind id="{$instance-id}-email" nodeset="instance('{$instance-id}')/tei:email" 
 			type="xf:email" />
 		<xf:bind id="{$instance-id}-orgname" nodeset="instance('{$instance-id}')/tei:orgName" 
 			type="xf:string" />
 		{
 		controls:rt-submission(
 			attribute bind {concat($instance-id,'-name')},
 			attribute action {concat('/code/api/user/', $user-name, '/name.txt')},
 			attribute action {concat('/code/api/user/', $user-name, '/name?_method=PUT')},
 			attribute replace {'text'},
 			attribute targetref { controls:instance-to-ref($instance-id, '/tei:name') },
 			$error-instance-id
 		),
 		controls:rt-submission(
 			attribute bind {concat($instance-id,'-email')},
 			attribute action {concat('/code/api/user/', $user-name, '/email')},
 			attribute action {concat('/code/api/user/', $user-name, '/email?_method=PUT')},
 			attribute replace {'instance'},
 			attribute targetref { controls:instance-to-ref($instance-id, '/tei:email') },
 			$error-instance-id
 		),
 		controls:rt-submission(
 			attribute bind {concat($instance-id,'-orgname')},
 			attribute action {concat('/code/api/user/', $user-name, '/orgname')},
 			attribute action {concat('/code/api/user/', $user-name, '/orgname?_method=PUT')},
 			attribute replace {'instance'},
 			attribute targetref { controls:instance-to-ref($instance-id, '/tei:orgName') },
 			$error-instance-id
 		)
 		}
 		<xf:instance id="{$instance-id}-password">
 			<change-password xmlns="">
 				<password/>
 			</change-password>
 		</xf:instance>
 		<xf:instance id="{$instance-id}-repeat-password">
 			<repeat-password xmlns="">
 				<password/>
 				<valid/>
 			</repeat-password>
 		</xf:instance>
 		<xf:bind
 			type="xf:boolean"
 			nodeset="instance('{$instance-id}-repeat-password')/valid"
 			calculate="string-length(instance('{$instance-id}-password')/password) &gt; 0 and instance('{$instance-id}-password')/password = instance('{$instance-id}-repeat-password')/password"
 			/>
 		<xf:bind id="{$instance-id}-new-password" 
 			type="xf:string"
 			nodeset="instance('{$instance-id}-password')/password" 
 			constraint=". = instance('{$instance-id}-repeat-password')/password"/>
 		<xf:bind id="{$instance-id}-new-password-repeat" 
 			type="xf:string"
 			nodeset="instance('{$instance-id}-repeat-password')/password" 
 			required="instance('{$instance-id}-password')/password != ''"
 			/>
 		<xf:submission id="{$instance-id}-change-password-submit"
 			bind="{$instance-id}-new-password"
 			method="post"
 			replace="none">
 			<xf:resource value="concat('/code/api/user/', instance('{$login-instance-id}')/user, '?_method=PUT')"/>
 			{
 				controls:submission-response(
 					$error-instance-id,
 					(),
 					(
 						<xf:setvalue bind="{$instance-id}-new-password" value="''"/>,
 						<xf:setvalue bind="{$instance-id}-new-password-repeat" value="''"/>,
 						controls:set-save-flag($save-status-instance-id, true())
 					)
 				)
 			}
 		</xf:submission>
 		<xf:action id="profile-login-actions" ev:event="logout">
 			<xf:load show="replace" resource="{$app-location}/new.xql"/>
 		</xf:action>
 		<xf:action ev:event="xforms-ready">
 			{
 			(: after all the initial submissions have changed the save flag,
 			need to reset it:)
 			controls:set-save-flag($save-status-instance-id, true())}
 		</xf:action>
 	</xf:model>, 
 	<title>User Profile Editor</title>,
 	(
 	<fieldset class="block-form">
 		{controls:error-report($error-instance-id)}
		<xf:group id="{$control-id}">{
			<xf:input id="{concat($control-id, '-name')}" incremental="true" bind="{$instance-id}-name">
				<xf:label>Real name or pseudonym: </xf:label>
			</xf:input>,
			controls:rt-control(
				concat($control-id, '-name'),
				controls:rt-submission-id(concat($instance-id,'-name')),
				controls:set-save-flag($save-status-instance-id, true()),
				controls:unsave-save-flag($save-status-instance-id)
			),
			<xf:input id="{concat($control-id, '-email')}" incremental="true" bind="{$instance-id}-email">
				<xf:label>Public email address: </xf:label>
			</xf:input>,
			controls:rt-control(
				concat($control-id, '-email'),
				controls:rt-submission-id(concat($instance-id, '-email')),
				controls:set-save-flag($save-status-instance-id, true()),
				controls:unsave-save-flag($save-status-instance-id)
			),
			<xf:input id="{concat($control-id, '-orgname')}" incremental="true" bind="{$instance-id}-orgname">
				<xf:label>Organizational affiliation: </xf:label>
			</xf:input>,
			controls:rt-control(
				concat($control-id, '-orgname'),
				controls:rt-submission-id(concat($instance-id, '-orgname')),
				controls:set-save-flag($save-status-instance-id, true()),
				controls:unsave-save-flag($save-status-instance-id)
			)
		}</xf:group>
		<xf:group id="{$control-id}-change-password">
			<fieldset>
				<legend>Change password</legend>
				<xf:secret bind="{$instance-id}-new-password" incremental="true">
					<xf:label>New password: </xf:label>
				</xf:secret>
				<xf:secret bind="{$instance-id}-new-password-repeat" incremental="true">
					<xf:label>Repeat new password: </xf:label>
				</xf:secret>
				<xf:submit 
					submission="{$instance-id}-change-password-submit"
					ref="instance('{$instance-id}-repeat-password')/valid[. = 'true']">
					<xf:label>Change password</xf:label>
				</xf:submit>
			</fieldset>
		</xf:group>
		{
		controls:debug-show-instance($instance-id),
		controls:debug-show-instance(concat($instance-id,'-repeat-password'))
 		}
 	</fieldset>
 	),
 	(
 		site:css(),
 		<link rel="stylesheet" type="text/css" href="{$app-location}/styles/user.css" />
 	),
 	site:header(),
 	site:sidebar-with-login($login-instance-id),
 	site:footer(),
 	uctrl:app-header('app-header', controls:save-status-ui($save-status-instance-id, 'control-save-status', ())))
)
