xquery version "1.0";
(: Contributors list saver module
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: save.xqm 709 2011-02-24 06:37:44Z efraim.feinstein $
 :)
module namespace savecontrib="http://jewishliturgy.org/apps/contributors/save";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace cc="http://web.resource.org/cc/";
declare namespace err="http://jewishliturgy.org/apps/errors";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";

import module namespace app = 'http://jewishliturgy.org/ns/functions/app';
import module namespace contributors = 'http://jewishliturgy.org/apps/lib/contributors'
	at '../lib/contributors.xqm';
import module namespace paths = 'http://jewishliturgy.org/apps/lib/paths'
	at '../lib/paths.xqm';

(:~ perform the work for save.xql; return back the data if successful,
 : flag an error if not
 :)
declare function savecontrib:save(
	$data as element(tei:list),
	$action as xs:string?) 
	as element(tei:list) {  
	let $debug := false()
	let $clean-stylesheet :=
		<xsl:stylesheet version="2.0" 
			xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			xmlns:tei="http://www.tei-c.org/ns/1.0"
			xmlns:xs="http://www.w3.org/2001/XMLSchema"
			xmlns:xrx="http://jewishliturgy.org/ns/xrx"
			xmlns:local="local-function"
			exclude-result-prefixes="xs"
			extension-element-prefixes="local">
			<xsl:import href="{$paths:rest-prefix}{$paths:apps}/lib/name.xsl2"/>
			<xsl:output encoding="utf-8" indent="yes" method="xml"/>
	    <xsl:strip-space elements="*"/>
			
			<!-- convert name text into expanded names -->
			<xsl:template match="tei:name/text()">
				<xsl:call-template name="split-name"/>
			</xsl:template>
			
			<xsl:template match="tei:name" priority="10">
				<xsl:apply-templates/>
			</xsl:template>
			
			<!-- ptr w/target is not empty -->
			<xsl:template match="tei:ptr[@target]">
				<xsl:if test="normalize-space(@target)">
					<xsl:copy>
						<xsl:copy-of select="@* except @xrx:*"/>
					</xsl:copy>
				</xsl:if>
			</xsl:template>
			
			<xsl:template match="*[element() or text()[string-length(.) &gt; 0]]">
				<xsl:variable name="children" as="node()*">
					<xsl:apply-templates/>
				</xsl:variable>
				
				<xsl:if test="exists($children)">
					<xsl:copy>
						<xsl:sequence select="(@*[not(empty(.))] except @xrx:*, $children)"/>	
					</xsl:copy>
				</xsl:if>
			</xsl:template>		
			
			<xsl:template match="tei:list" priority="10">
				<xsl:copy>
					<xsl:sequence select="@*"/>
					<xsl:apply-templates/>
				</xsl:copy>
			</xsl:template>
			
		</xsl:stylesheet>
	let $cleaned-data as element(tei:list) := 
		transform:transform($data, $clean-stylesheet, ())	
	let $contrib-template :=
		<tei:TEI>
	  	<tei:teiHeader>
	    	<tei:fileDesc>
	      	<tei:titleStmt>
	      		<tei:title xml:lang="en">Global contributors list</tei:title>
	        </tei:titleStmt>
	        <tei:publicationStmt>
	    	    <tei:availability status="free">
	      	  	<tei:p xml:lang="en" xmlns="http://www.tei-c.org/ns/1.0">
	        			To the extent possible under law, the contributors who associated
	        			<tei:ref type="license" target="http://www.creativecommons.org/publicdomain/zero/1.0">Creative Commons Zero
	        			</tei:ref>
	      	  		with this work have waived all copyright and related or neighboring rights to this work.
	    	  		</tei:p>
	  	    		<rdf:RDF>
		        		<cc:License rdf:about="http://creativecommons.org/publicdomain/zero/1.0/">
	          			<cc:legalcode
	          				rdf:resource="http://creativecommons.org/publicdomain/zero/1.0/legalcode" />
	          			<cc:permits rdf:resource="http://creativecommons.org/ns#Reproduction" />
	          			<cc:permits rdf:resource="http://creativecommons.org/ns#Distribution" />
		        		</cc:License>
	  	    		</rdf:RDF>
						</tei:availability>
					</tei:publicationStmt>
	      	<tei:sourceDesc>
	      		<tei:bibl><tei:p>Born digital</tei:p></tei:bibl>
	      	</tei:sourceDesc>
				</tei:fileDesc>
			</tei:teiHeader>
	    <tei:text>
				<tei:body>
	    		<tei:div type="contributors">
						{$cleaned-data}    						
	    		</tei:div>
	    	</tei:body>
	    </tei:text>
		</tei:TEI>
	return
		(
		app:make-collection-path(
		$contributors:collection, '/db', 'admin',	'everyone', util:base-to-integer(0775, 8)),
		util:log-system-out(('INCOMING : ', $data, ' CLEANED-DATA: ', $cleaned-data)),
		if (app:auth-user())
		then
			if (doc-available($contributors:list))
			then 
				if ($action = 'append')
				then (
					update insert $cleaned-data/tei:item into doc($contributors:list)//tei:div[@type='contributors']/tei:list,
					$data
				)
				else (
					update replace doc($contributors:list)//tei:div[@type='contributors']/tei:list with $cleaned-data,
					$data
				)
			else (
				if (xmldb:store($contributors:collection, $contributors:resource, $contrib-template))
				then (
					xmldb:set-resource-permissions(
						$contributors:collection, $contributors:resource, 
						app:auth-user(),
						'everyone',
						util:base-to-integer(0775, 8)),
					$data)
				else error(xs:QName('err:SAVE'), 'Cannot store!')
				)
		else error(xs:QName('err:NOT_LOGGED_IN'), 'Not logged in')
		)
};
