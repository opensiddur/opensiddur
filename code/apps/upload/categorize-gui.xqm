xquery version "1.0";
(: cat-gui.xqm
 : Categorization forms and GUI controls
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: categorize-gui.xqm 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
module namespace catgui="http://jewishliturgy.org/apps/upload/catgui";
 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xrx="http://jewishliturgy.org/ns/xrx";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";

import module namespace controls="http://jewishliturgy.org/apps/lib/controls" 
	at "../lib/controls.xqm";
import module namespace paths="http://jewishliturgy.org/apps/lib/paths" 
	at "../lib/paths.xqm";

declare variable $catgui:prototype :=
		<categories xmlns="">
			<is-original/>
			<translation-name/>
			<new-translation-name/>
			<language/>
		</categories>;
		(: also includes written-files :)

declare function catgui:cat-instance(
	$instance-id as xs:string) 
	as element()+ {
	(
	<xf:instance id="{$instance-id}" xmlns="">
		{$catgui:prototype}
	</xf:instance>,
	<xf:instance id="{$instance-id}-translations" xmlns="" 
		src="list-translations.xql">
	</xf:instance>,
	<xf:instance id="{$instance-id}-new-translation" xmlns="">
		<new-translation>
			<tei:item>
				<tei:ref>START NEW TRANSLATION</tei:ref>
			</tei:item>
		</new-translation>
	</xf:instance>,
	<xf:bind nodeset="instance('{$instance-id}')/is-original" type="xf:boolean"/>,
	<xf:bind nodeset="instance('{$instance-id}')/language" type="xf:string" required="true()"/>, 
	<xf:bind nodeset="instance('{$instance-id}')/translation-name" type="xf:string"
		required="../is-original != 'true' and ../new-translation-name = ''" 
		relevant="../is-original != 'true'"/>,
	<xf:bind nodeset="instance('{$instance-id}')/new-translation-name" type="xf:string"
		required="../is-original != 'true' and ../translation-name = 'START NEW TRANSLATION'" 
		relevant="../is-original != 'true' and ../translation-name = 'START NEW TRANSLATION'"/>
	)
};

declare function catgui:cat-gui(
	$instance-id as xs:string,
	$control-id as xs:string)
	as element()+ {
	<xf:group ref="instance('{$instance-id}')" id="{$control-id}">
		<xf:input ref="is-original">
			<xf:label>Check this box if the transcription is an original text (not a translation)</xf:label>
		</xf:input>
		<br/>
		{controls:language-selector-ui("transcription-language",
			"Main language of the transcription: ",	"language")}
		<br/>
		<xf:select1 ref="translation-name" incremental="true" selection="open">
			<xf:label>What is the name of the translation? </xf:label>
			<xf:itemset 
				nodeset="instance('{$instance-id}-new-translation')/tei:item|instance('{$instance-id}-translations')//tei:list[@n = choose(instance('{$instance-id}')/language = '', @n, instance('{$instance-id}')/language)]/tei:item">
				<xf:value ref="tei:ref" />
				<xf:label ref="tei:ref" />
			</xf:itemset>
		</xf:select1>
		<xf:input ref="new-translation-name" incremental="true">
			<xf:label>New translation name: </xf:label>
		</xf:input>
		<br/>
	</xf:group>	
}; 