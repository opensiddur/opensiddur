xquery version "1.0";
(: correction-gui.xqm
 : Correction GUI controls
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: correction-gui.xqm 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
module namespace corrgui="http://jewishliturgy.org/apps/upload/corrgui";
 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xrx="http://jewishliturgy.org/ns/xrx";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";

import module namespace controls="http://jewishliturgy.org/apps/lib/controls" 
	at "../lib/controls.xqm";
import module namespace licensegui="http://jewishliturgy.org/apps/upload/licensegui" 
	at "license-gui.xqm";
import module namespace namegui="http://jewishliturgy.org/apps/upload/namegui" 
	at "name-gui.xqm";
import module namespace paths="http://jewishliturgy.org/apps/lib/paths" 
	at "../lib/paths.xqm";
import module namespace scangui="http://jewishliturgy.org/apps/upload/scangui" 
	at "scangui.xqm";

declare function corrgui:correction-css() 
	as xs:string {
	'.textarea textarea {
   			font-family: Courier, sans-serif;
   			height: 20em;
   			width: 90%;
	}'
};

declare function corrgui:correction-instance(
	$instance-id as xs:string,
	$initial-text as xs:string) 
	as element()+ {
	(
	<xf:instance id="{$instance-id}" xmlns="">
		<corrections>
			<bibliography/>
			<language/>
			<license>{$licensegui:default-license}</license>
			<index-name>{$namegui:default-index-name}</index-name>
			<index-title/>
			<has-facsimile>true</has-facsimile>
			<facsimile/>
			<text>
				{$initial-text}
			</text>
		</corrections>
	</xf:instance>,
	<xf:bind nodeset="instance('{$instance-id}')/text" type="xf:string" required="true()"/>,
	<xf:bind nodeset="instance('{$instance-id}')/language" required="true()"/>
	)
};

declare function corrgui:correction-ui(
	$instance-id as xs:string,
	$control-id as xs:string)
	as element()+ {
	<xf:group ref="instance('{$instance-id}')" id="{$control-id}">
		<h2>Correct and enhance the text</h2>
		<ul>
			<li>Remove all text that should not be in this file.</li>  
			<li>Do not remove {{contrib}} and {{page}} tags that come before pages that 
			contain text for your new files.</li> 
			<li>Add {{file "Title" "Filename.xml"}} tags wherever the XML should be split
			into multiple files.  If the file split occurs at a page boundary, place the new
			file tag before the {{p. NNN}} and {{contrib ...}} tags.</li>
		</ul>
		<div class="textarea">
			<xf:textarea ref="text" incremental="true">
				<xf:label>Correct text: <br/></xf:label>
			</xf:textarea>
		</div>
	</xf:group>	
}; 