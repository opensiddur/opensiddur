xquery version "1.0";
(:~ set off the compiler and provide a waiting UI
 : 
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 : $Id: compile.xql 768 2011-04-28 18:35:25Z efraim.feinstein $
 :)  
import module namespace app="http://jewishliturgy.org/modules/app" 
 	at "/code/modules/app.xqm";
import module namespace collab="http://jewishliturgy.org/modules/collab" 
 	at "/code/modules/collab.xqm";
import module namespace controls="http://jewishliturgy.org/modules/controls" 
 	at "/code/modules/controls.xqm";
import module namespace builder="http://jewishliturgy.org/apps/builder/controls" 
	at "/code/apps/builder/modules/builder.xqm";
import module namespace site="http://jewishliturgy.org/modules/site" 
 	at "/code/modules/site.xqm";
import module namespace login="http://jewishliturgy.org/apps/user/login" 
	at "/code/apps/user/modules/login.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace ev="http://www.w3.org/2001/xml-events";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xf="http://www.w3.org/2002/xforms";

declare option exist:serialize "method=xhtml media-type=text/xml indent=yes omit-xml-declaration=no
	process-xsl-pi=no
	doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
	doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"; 

let $login-instance-id := 'login'
let $builder-instance-id := 'builder'
let $control-id := 'builder-control'
let $error-instance := 'builder-error'
return
	site:form(
		<xf:model id="model">{
			login:login-instance($login-instance-id, 
				(site:sidebar-login-actions-id(), 'model')
			),
			builder:login-actions($builder-instance-id),
			<xf:instance id="blank">
				<blank xmlns=""/>
			</xf:instance>,
			<xf:instance id="resource">
				<resource xmlns="">
					<item>{request:get-parameter('item', ())}</item>
				</resource>
			</xf:instance>,
			<xf:instance id="return">{
				<return xmlns="">
					<path/>
				</return>
			}</xf:instance>,
			controls:error-instance($error-instance),
			<xf:submission id="compile-submit"
				method="post"
				ref="instance('blank')"
				replace="none"
				mode="asynchronous"
				>
				<xf:resource value="concat(instance('resource')/item, '?compile=xhtml&amp;output={app:auth-user()}')"/>
				{
				controls:submission-response(
					$error-instance,
  				(),
  				(
  					<xf:setvalue ref="instance('return')/path" 
  						value="event('response-headers')/self::header[name='Location']/value"/>,
  					<xf:load show="new">
  						<xf:resource value="instance('return')/path"/>
  					</xf:load>,
  					<xf:toggle case="compile-done"/>
  				)
				)
			}</xf:submission>,
			<xf:action ev:event="xforms-ready">
				<xf:dispatch delay="500" name="delayed-compile-event" targetid="model"/>
			</xf:action>,
			<xf:action ev:event="delayed-compile-event">
				<xf:send submission="compile-submit"/>
			</xf:action>
		}</xf:model>,
		<title>Open Siddur Builder</title>,
		<fieldset>
			{controls:error-report($error-instance)}
			<xf:switch>
				<xf:case id="compile-working">
					<div>
						Please wait while the Open Siddur compiles your new siddur...
					</div>
				</xf:case>
				<xf:case id="compile-done">
					<div class="compile-done">
					Your compiled siddur should now appear in a new window or tab. 
					If it does not, add 
					{request:get-server-name()} as an exception to your popup blocker,
          then
          <xf:trigger>
            <xf:label>click here.</xf:label>
            <xf:load show="new" ev:event="DOMActivate">
  						<xf:resource value="instance('return')/path"/>
  					</xf:load>
          </xf:trigger>
					</div>
				</xf:case>
			</xf:switch>
		</fieldset>,
		(site:css(), builder:css()),
		site:header(),
		(site:sidebar-with-login($login-instance-id),
		builder:sidebar()),
		site:footer(),
		builder:app-header($builder-instance-id, 'app-header', (), 'resource')
	)
