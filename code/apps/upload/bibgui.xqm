xquery version "1.0";
(: bibgui.xqm
 : Source selection GUI controls
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: bibgui.xqm 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
module namespace bibgui="http://jewishliturgy.org/apps/upload/bibgui";
 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xrx="http://jewishliturgy.org/ns/xrx";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";

import module namespace bibliography="http://jewishliturgy.org/apps/lib/bibliography" 
	at "../lib/bibliography.xqm";
import module namespace controls="http://jewishliturgy.org/apps/lib/controls" 
	at "../lib/controls.xqm";
import module namespace paths="http://jewishliturgy.org/apps/lib/paths" 
	at "../lib/paths.xqm";

(:~ Additional instance for bibliography selection.  The primary
 : $instance-id should include a bibliography element, which is *not* 
 : added by this function. :)
declare function bibgui:bib-instance(
	$instance-id as xs:string) 
	as element()+ {
	(
	<xf:bind nodeset="instance('{$instance-id}')/bibliography" type="xf:string" required="true()"/>,
	bibliography:list-instance(concat($instance-id,'-bibliography-list')),
	<xf:submission id="{$instance-id}-submit-bibliography"
		ref="instance('{$instance-id}-bibliography-list')"
		instance="{$instance-id}-bibliography-list" 
		replace="instance" 
		action="{$paths:prefix}{$paths:apps}/bibliography/save.xql" method="post">
		<xf:action ev:event="xforms-submit-done">
			<xf:toggle case="{$instance-id}-bibliography-closed"/>
		</xf:action>
		<xf:action ev:event="xforms-submit-error">{
			controls:submit-error-handler-action()
		}</xf:action>
	</xf:submission>
	)
};

declare function bibgui:bib-ui(
	$instance-id as xs:string,
	$control-id as xs:string)
	as element()+ {
	<xf:group ref="instance('{$instance-id}')" id="{$control-id}">
		<h2>Source selection</h2>
		<xf:select1 ref="bibliography">
			<xf:label>Select the text's source:</xf:label>
			<xf:itemset nodeset="instance('{$instance-id}-bibliography-list')/tei:biblStruct">
				<xf:label ref="tei:monogr/xrx:titles[1]/tei:title[@type='main']"/>
				<xf:value ref="@xml:id"/>
			</xf:itemset>
		</xf:select1>
		<p>If the source of the imported text is not listed, 
		use the bibliography editor below to add a new source
		to the bibliography.</p>
		<xf:switch>
			<xf:case id="{$instance-id}-bibliography-closed">
				<xf:trigger>
					<xf:label>Expand bibliography editor</xf:label>
					<xf:action ev:event="DOMActivate">
						<xf:toggle case="{$instance-id}-bibliography-open"/>
					</xf:action>
				</xf:trigger>
			</xf:case>
			<xf:case id="{$instance-id}-bibliography-open">
				<xf:submit submission="{$instance-id}-submit-bibliography">
					<xf:label>Collapse bibliography editor and save</xf:label>
				</xf:submit>
				<xf:trigger>
					<xf:label>Collapse bibliography editor without saving</xf:label>
					<xf:action ev:event="DOMActivate">
						<xf:toggle case="{$instance-id}-bibliography-closed"/>
						<!--xf:load resource="{$paths:prefix}{$paths:apps}/bibliography/load.xql"
							ref="instance('{$instance-id}-bibliography-list')" 
							show="replace" /-->
					</xf:action>
				</xf:trigger>
				<fieldset>
					{bibliography:list-gui(
						concat($instance-id,'-bibliography-list'),
						concat($instance-id,'-bibliography-list-gui'))}
					<xf:submit submission="{$instance-id}-submit-bibliography">
						<xf:label>Save changes to bibliography</xf:label>
					</xf:submit>
				</fieldset>
			</xf:case>
		</xf:switch>
	</xf:group>	
}; 