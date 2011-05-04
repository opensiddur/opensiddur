xquery version "1.0";
(: contrib-gui.xqm
 : Contributor addition GUI controls
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: contrib-gui.xqm 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
module namespace contribgui="http://jewishliturgy.org/apps/upload/contribgui";
 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xrx="http://jewishliturgy.org/ns/xrx";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";

import module namespace controls="http://jewishliturgy.org/apps/lib/controls" 
	at "../lib/controls.xqm";
import module namespace contributors="http://jewishliturgy.org/apps/lib/contributors" 
	at "../lib/contributors.xqm";
import module namespace paths="http://jewishliturgy.org/apps/lib/paths" 
	at "../lib/paths.xqm";


declare function contribgui:contrib-instance(
	$instance-id as xs:string) 
	as element()+ {
	(
	<xf:instance id="{$instance-id}" xmlns="">
		<contributors>
			<written-files/>
			<unknown-contributors/>
		</contributors>
	</xf:instance>,
	contributors:list-instance('contributors-list'),
	<xf:bind nodeset="instance('{$instance-id}')/unknown-contributors/tei:item/@xml:id" 
		readonly="true()" type="xf:NCName"/>,
	<xf:bind nodeset="instance('{$instance-id}')/unknown-contributors/tei:item/tei:email" required="true()"/>,
	<xf:bind nodeset="instance('{$instance-id}')/unknown-contributors/tei:item/tei:orgName" relevant="../tei:name = ''" required="../tei:name = ''"/>,
	<xf:bind nodeset="instance('{$instance-id}')/unknown-contributors/tei:item/tei:name" relevant="../tei:orgName = ''" required="../tei:orgName = ''"/>,
	<xf:bind nodeset="instance('{$instance-id}')/unknown-contributors/tei:item/tei:affiliation" relevant="../tei:name"/>
	)
};

declare function contribgui:contrib-gui(
	$instance-id as xs:string,
	$control-id as xs:string)
	as element()+ {
	<xf:group ref="instance('{$instance-id}')">
		<h2>Written files</h2>
		<p>The following files were successfully generated:</p>
		<p>
			<xf:repeat nodeset="written-files/file">
				<xf:output ref="."/><br/>
			</xf:repeat>
		</p>
		
		<h2>Unknown contributors</h2>
		<p>The following identifiers identify unknown contributors.
		Before entering data into the database, all contributors must be
		properly identified, either by a real name (preferable) or by an
		Internet pseudonym.</p>
		<p>
			<xf:repeat nodeset="unknown-contributors/tei:item">{
				contributors:individual-entry-ui(
					'contributors-list',
					'contributors-list',
					'individual-contributor',
					'.',
					())
			}</xf:repeat>
		</p>  
	</xf:group>	
}; 