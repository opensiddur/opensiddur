xquery version "1.0";
(: scangui.xqm
 : Scan selection GUI controls
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: scangui.xqm 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
module namespace scangui="http://jewishliturgy.org/apps/upload/scangui";

import module namespace paths="http://jewishliturgy.org/apps/lib/paths"
	at "../lib/paths.xqm"; 

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xrx="http://jewishliturgy.org/ns/xrx";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";


declare variable $scangui:default-facsimile-prefix := '/scans/';
declare variable $scangui:default-facsimile-suffix := '.jpg';

declare function scangui:_get-scan-directory()
	as element(xf:item)* {
	scangui:_get-scan-directory($scangui:default-facsimile-prefix)
};

declare function scangui:_get-scan-directory(
	$prefix as xs:string) 
	as element(xf:item)* {
	let $index-list :=
		httpclient:get(xs:anyURI(
			concat('http://', 
				request:get-server-name(), ':', request:get-server-port(), 
				$prefix)),
			false(), ())//table/tr[position() > 3]//a[../../td/img/@alt='[DIR]']
	return
		for $dir in $index-list
		let $dir-sl := substring-before($dir, '/')
		let $subdirs := scangui:_get-scan-directory(concat($prefix, '/', $dir))
		return
			(
				for $subdir in $subdirs//xf:value
				let $subdir-str := 
					concat($dir, $subdir)
				return (
					<xf:item>
						<xf:value>{$subdir-str}</xf:value>
						<xf:label>{$subdir-str}</xf:label>
					</xf:item>
				),
				<xf:item>
					<xf:value>{$dir-sl}</xf:value>
					<xf:label>{$dir-sl}</xf:label>
				</xf:item>
			)
};

(:~ Instance for scan information.  The instance ID should be the same as
 : for the corrections :)
declare function scangui:scan-instance(
	$instance-id as xs:string) 
	as element()+ {
	(
	<xf:bind nodeset="instance('{$instance-id}')/has-facsimile"
		type="xf:boolean"
		required="true()"/>,
	<xf:bind nodeset="instance('{$instance-id}')/facsimile"
		type="xf:string"
		relevant="../has-facsimile = 'true'"
		required="../has-facsimile = 'true'"/>
	)
};

declare function scangui:scan-ui(
	$instance-id as xs:string,
	$control-id as xs:string,
	$next-case as xs:string)
	as element()+ {
	<xf:group ref="instance('{$instance-id}')" id="{$control-id}">
		<h2>Scan information</h2>
		<p>This section makes the linkage between scan sequence numbers 
		and the page numbers in the text.
		If no scans exist because the text was born digital, 
		<xf:trigger>
			<xf:label>click here to skip this step. &gt;&gt;</xf:label>
			<xf:action ev:event="DOMActivate">
				<xf:setvalue ref="has-facsimile">false</xf:setvalue>
				<xf:toggle case="{$next-case}"/>
			</xf:action>
		</xf:trigger>.</p>

		<p>
		<xf:input ref="has-facsimile" incremental="true">
			<xf:label>If scans do exist, check this box.</xf:label>
		</xf:input>
		</p>

		<xf:select1 ref="facsimile" incremental="true">
			<xf:label>Select the directory where scans of the imported content are stored: </xf:label>
			{scangui:_get-scan-directory()}
		</xf:select1>
		<br/>
	</xf:group>	
	
}; 