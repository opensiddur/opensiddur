xquery version "1.0";
(:~ Welcome page
 : 
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :) 
import module namespace request="http://exist-db.org/xquery/request";
 
import module namespace app="http://jewishliturgy.org/modules/app" 
 	at "/code/modules/app.xqm";
import module namespace builder="http://jewishliturgy.org/apps/builder/controls" 
 	at "/code/apps/builder/modules/builder.xqm";
import module namespace controls="http://jewishliturgy.org/modules/controls" 
 	at "/code/modules/controls.xqm"; 	
import module namespace site="http://jewishliturgy.org/modules/site" 
 	at "/code/modules/site.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths" 
 	at "/code/modules/paths.xqm";
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

declare function local:welcome-message(
	) {
	<div class="welcome" xml:lang="en" lang="en">
		<h1>Welcome to the Open Siddur Project v.{app:get-version()}</h1>
		<div>
			<p>To get started immediately, create an account or log in and press My Siddurim.</p>
			<p><strong>Security notice</strong>: This version sends usernames, passwords, and all other
			information in clear text over the Internet. Do not enter any information you would not want
			to be public!</p>
			<p>This version is a pre-alpha technology demonstration, a thin user interface wrapper
			around the <a href="/code/api">REST API</a>.
			<a href="http://wiki.jewishliturgy.org/Release_Notes/{app:get-version()}">Follow this link 
			for the full release notes</a>, including information on what is new in this version,
			how to obtain the source code, and how to report bugs.</p>
      <p><strong>Do not</strong> assume that the data you store in this application is secure! It may be read or deleted
      at any time!</p>
		</div>
	</div>
};

let $login-instance-id := 'login'
return
site:form(
	<xf:model>{
		login:login-instance($login-instance-id, 
			(
			site:sidebar-login-actions-id(),
			builder:sidebar-login-actions-id()
			))
		}
		
	</xf:model>,
	<title>Welcome to the Open Siddur</title>,
	local:welcome-message(),
 	site:css(),
 	site:header(),
 	(site:sidebar-with-login($login-instance-id),
 	builder:sidebar()),
 	site:footer()
)
