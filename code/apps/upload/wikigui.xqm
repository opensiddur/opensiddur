xquery version "1.0";
(: wiki-import.xql
 : Wiki import GUI controls
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: wikigui.xqm 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
module namespace wikigui="http://jewishliturgy.org/apps/upload/wikigui";
 
import module namespace controls="http://jewishliturgy.org/apps/lib/controls"
	at "../lib/controls.xqm";
import module namespace wiki="http://jewishliturgy.org/apps/lib/wiki" 
	at "../lib/wiki.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";

declare function wikigui:individual-import-ui(
	$instance-id as xs:string,
	$control-id as xs:string,
	$ref as xs:string?
	) 
	as element(xf:group) {
	<xf:group id="{$control-id}">
		{if ($ref)
		then attribute ref {$ref}
		else ()}
		<fieldset>
			Import...
			<xf:trigger id="{$control-id}-make-one-page">
				<xf:label>From one wiki page</xf:label>
				<xf:action ev:event="DOMActivate">
					<xf:toggle case="{$control-id}-one-page"/>
					<xf:setvalue ref="group/name-base" value=""/>
					<xf:setvalue ref="group/digits" value=""/>
					<xf:setvalue ref="group/start" value=""/>
					<xf:setvalue ref="group/finish" value=""/>
					<xf:setvalue ref="group/suffix" value=""/>
				</xf:action>
			</xf:trigger>
			<xf:trigger id="{$control-id}-make-multiple-pages">
				<xf:label>From a series of pages</xf:label>
				<xf:action ev:event="DOMActivate">
					<xf:toggle case="{$control-id}-multiple-pages"/>
					<xf:setvalue ref="individual/page" value=""/>
				</xf:action>
			</xf:trigger>
			<br/>
			<xf:switch>
				<xf:case id="{$control-id}-one-page">
					<xf:input ref="individual/page" incremental="true">
						<xf:label>Page URL: {$wiki:server}/</xf:label>
					</xf:input>
				</xf:case>
				<xf:case id="{$control-id}-multiple-pages">
					<xf:group ref="group">
						<xf:input ref="name-base" incremental="true">
							<xf:label>Base: </xf:label>
						</xf:input>
						<br/>
						<xf:input ref="digits" incremental="true">
							<xf:label>Number of digits: </xf:label>
						</xf:input>
						<xf:input ref="start" incremental="true">
							<xf:label>Starting number: </xf:label>
						</xf:input>
						<xf:input ref="finish" incremental="true">
							<xf:label>Ending number: </xf:label>
						</xf:input>
						<br/>
						<xf:input ref="suffix" incremental="true">
							<xf:label>Ending: </xf:label>
						</xf:input>
						<br/>
						<xf:output ref="concat(name-base,	substring(instance('{$instance-id}-zeros'), 1, number(digits) - string-length(start)), start, suffix)" incremental="true">
							<xf:label>Example URL: {$wiki:server}/Page:</xf:label>
						</xf:output>
					</xf:group>
				</xf:case>
			</xf:switch>
		</fieldset>
	</xf:group>
};

(:~ produce an imports instance :)
declare function wikigui:imports-instance(
	$instance-id as xs:string
	) 
	as element()+ {
	let $import-prototype := 
		<import xmlns="">
			<individual>
				<page/>
			</individual>
			<group>
				<name-base/>
				<digits/>
				<start/>
				<finish/>
				<suffix/>
			</group>
		</import>
	return (
		<xf:instance id="{$instance-id}" xmlns="">
			<importList xmlns="">{
				$import-prototype
			}</importList>
		</xf:instance>,
		<xf:bind nodeset="instance('{$instance-id}')/import/individual/page"
			type="xf:string" 
			required="../../group/name-base = ''" />,
		<xf:bind nodeset="instance('{$instance-id}')/import/group/name-base"
			type="xf:string" 
			required="../../individual/page = ''" />,
		<xf:bind nodeset="instance('{$instance-id}')/import/group/suffix"
			type="xf:string" 
			required="../../individual/page = ''" />,
		<xf:bind nodeset="instance('{$instance-id}')/import/group/start"
			type="xf:integer" 
			required="../../individual/page = ''" />,	
		<xf:bind nodeset="instance('{$instance-id}')/import/group/finish"
			type="xf:integer" 
			required="../../individual/page = ''" />,
		<xf:bind nodeset="instance('{$instance-id}')/import/group/digits"
			type="xf:integer" 
			required="../../individual/page = ''" />,
		(: how to make a zero padded string in XPath 1.0? :)
		<xf:instance id="{$instance-id}-zeros" xmlns="">
			<zeros>{string-join(for $i in (1 to 100) return '0','')}</zeros>
		</xf:instance>,				
		controls:ordered-list-instance(
			concat($instance-id,'-list'), 
			$import-prototype)
	)
};

declare function wikigui:imports-gui(
	$instance-id as xs:string,
	$control-id as xs:string)
	as element(xf:group) {
	<xf:group ref="instance('{$instance-id}')">
		{controls:ordered-list-ui(
			concat($instance-id,'-list'),
			concat($control-id,'-list'),
			'Import options',
			"import",
			wikigui:individual-import-ui(
				$instance-id,
				concat($control-id,'-individual'),
				()))}
	</xf:group>	
};			
