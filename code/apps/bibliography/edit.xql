xquery version "1.0";
(: Bibliography editing UI
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: edit.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace xrx="http://jewishliturgy.org/ns/xrx";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";

import module namespace paths="http://jewishliturgy.org/apps/lib/paths" 
	at "../lib/paths.xqm";
import module namespace controls="http://jewishliturgy.org/apps/lib/controls" 
	at "../lib/controls.xqm";
import module namespace login="http://jewishliturgy.org/apps/lib/login" 
	at "../lib/login.xqm";
import module namespace bibliography="http://jewishliturgy.org/apps/lib/bibliography"
	at "../lib/bibliography.xqm";

let $form := 
<html xmlns="http://www.w3.org/1999/xhtml"
	xmlns:tei="http://www.tei-c.org/ns/1.0"
	xmlns:xs="http://www.w3.org/2001/XMLSchema"
	xmlns:xf="http://www.w3.org/2002/xforms">
	<head>
		<title>Bibliography editor</title>
   	<xf:model>
			{bibliography:list-instance('items')}
			
			<xf:submission id="save" ref="instance('items')" 
				instance="items" replace="instance" 
				action="save.xql" method="post">
				<xf:action ev:event="xforms-submit-error">
					<xf:message level="modal">Save error. Fill in all required fields.</xf:message>
				</xf:action>
			</xf:submission>

			{login:form-instance('login')}	
		</xf:model>
		
	</head>
	<body>
		<h1>Open Siddur Global Bibliography Editor</h1>
		
		{login:form-ui('login')}
		
		<xf:submit submission="save">
			<xf:label>Save all records</xf:label>
		</xf:submit>
				
		{bibliography:list-gui('items','items-gui')}
		<xf:submit submission="save">
			<xf:label>Save all records</xf:label>
		</xf:submit>
			
  </body>
</html>
return ($paths:xslt-pi,$paths:debug-pi,$form)
