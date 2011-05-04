xquery version "1.0";
(: license-gui.xqm
 : License chooser GUI.  Assumes the existence of an instance with a license element.
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: license-gui.xqm 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
module namespace licensegui="http://jewishliturgy.org/apps/upload/licensegui";
 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xrx="http://jewishliturgy.org/ns/xrx";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";

declare variable $licensegui:default-license := 'cc0';
declare variable $licensegui:supported-licenses 
	as element(xf:item)+ := ( 
	<xf:item>
		<xf:label>Creative Commons Zero/Public Domain</xf:label>
		<xf:value>cc0</xf:value>
	</xf:item>,
	<xf:item>
		<xf:label>Creative Commons Attribution 3.0 Unported</xf:label>
		<xf:value>cc-by</xf:value>
	</xf:item>,
	<xf:item>
		<xf:label>Creative Commons Attribution-ShareAlike 3.0 Unported</xf:label>
		<xf:value>cc-by-sa</xf:value>
	</xf:item>
	);

declare function licensegui:license-instance(
	$instance-id as xs:string) 
	as element()+ {
	(
	<xf:bind nodeset="instance('{$instance-id}')/license" type="xf:string" required="true()"/>
	)
};

declare function licensegui:license-ui(
	$instance-id as xs:string,
	$control-id as xs:string)
	as element()+ {
	<xf:group ref="instance('{$instance-id}')" id="{$control-id}">
		<xf:select1 ref="license" appearance="full">
			<xf:label>Choose the license that the text is released under.  
			If the license requires attribution,
			make sure that the {{contrib}} tags reflect the correct attributions in the next step.</xf:label>
			{$licensegui:supported-licenses}
		</xf:select1>
	</xf:group>	
}; 