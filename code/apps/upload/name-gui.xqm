xquery version "1.0";
(: correction-gui.xqm
 : Correction GUI controls
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: name-gui.xqm 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
module namespace namegui="http://jewishliturgy.org/apps/upload/namegui";
 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xrx="http://jewishliturgy.org/ns/xrx";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";


declare variable $namegui:default-index-name := 'index';

declare function namegui:name-instance(
	$instance-id as xs:string) 
	as element()+ {
	(
	<xf:bind nodeset="instance('{$instance-id}')/index-name" type="xf:string" required="true()"/>,
	<xf:bind nodeset="instance('{$instance-id}')/index-title" type="xf:string" required="true()"/>
	)
};

declare function namegui:name-ui(
	$instance-id as xs:string,
	$control-id as xs:string)
	as element()+ {
	<xf:group ref="instance('{$instance-id}')" id="{$control-id}">
		<p>If this entry includes data that will be split into multiple XML files, 
		a single file that represents the entire content will also be generated.
		This "index" file should have a name that represents the content well, 
		and is readable	to a human.  For entire books, it should be the name of the book.  
		A .xml extension will be added to it automatically.  Please do not use 
		spaces in the book file name.  Underscores (_) may be substituted for spaces.
		will contain pointers to all of them.</p>
		<xf:input ref="index-name" incremental="true">
			<xf:label>Index file name: </xf:label>
		</xf:input>.xml
		
		<p>The index title is a human-readable title for all the content.  
		It may contain any characters, including spaces.  For entire books, it should be
		the name of the book.  For sections of the prayer service, the incipit or
		a well-known section name (eg, "Amidah") may be used.</p>
		<xf:input ref="index-title" incremental="true">
			<xf:label>Index title: </xf:label>
		</xf:input>
	</xf:group>	
}; 