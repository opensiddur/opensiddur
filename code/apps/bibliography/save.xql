xquery version "1.0";
(: Bibliography saver
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace cc="http://web.resource.org/cc/";
declare namespace err="http://jewishliturgy.org/apps/errors";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";

import module namespace app="http://jewishliturgy.org/ns/functions/app";

let $debug := false()
let $bibliography-collection := '/group/everyone/bibliography'
let $bibliography-resource := 'bibliography.xml'
let $bibliography-file := concat($bibliography-collection, '/', $bibliography-resource)
let $clean-stylesheet :=
	<xsl:stylesheet version="2.0" 
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:tei="http://www.tei-c.org/ns/1.0"
		xmlns:xs="http://www.w3.org/2001/XMLSchema"
		xmlns:xrx="http://jewishliturgy.org/ns/xrx"
		xmlns:local="local-function"
		exclude-result-prefixes="xs"
		extension-element-prefixes="local">
		<xsl:output encoding="utf-8" indent="yes" method="xml"/>
    <xsl:strip-space elements="*"/>
		
		<!-- convert author/editor text into expanded names -->
		<xsl:template match="tei:author/text()|tei:editor/text()">
			<xsl:variable name="roles" as="xs:string" 
				select="'(Dr|M|Mme|Mr|Mrs|Ms|Rabbi|R)\.?$'"/>
			<xsl:variable name="links" as="xs:string"
				select="'(ben|de|den|der|ibn|van|von)$'"/>
			<xsl:variable name="gens" as="xs:string"
				select="'((Jr|Jr)\.?)|(I|II|III|IV|V|VI|VII|VIII|IX|X|1st|2nd|3rd|4th|5th|6th|7th|8th|9th|10th)$'"/>
		
			<xsl:variable name="tokens" as="xs:string+"
				select="tokenize(., '[,\s]+')"/>
			<xsl:variable name="is-role" as="xs:boolean+"
				select="for $token in $tokens return matches($token, $roles)"/>
			<xsl:variable name="is-link" as="xs:boolean+"
				select="for $token in $tokens return matches($token, $links)"/>
			<xsl:variable name="is-gen" as="xs:boolean+"
				select="for $token in $tokens return matches($token, $gens)"/>
			<!--xsl:message>
				is-role = <xsl:sequence select="$is-role"/>
			</xsl:message-->  
			<xsl:for-each select="$tokens">
				<xsl:variable name="pos" as="xs:integer" select="position()"/>
				
				<xsl:choose>
					<xsl:when test="$is-role[$pos]">
						<tei:roleName><xsl:value-of select="."/></tei:roleName>
					</xsl:when>
					<xsl:when test="$is-link[$pos]">
						<tei:nameLink><xsl:value-of select="."/></tei:nameLink>
					</xsl:when>
					<xsl:when test="$is-gen[$pos]">
						<tei:genName><xsl:value-of select="."/></tei:genName>
					</xsl:when>
					<xsl:when test="($pos = count($tokens)) or
						(every $token-pos in (($pos + 1) to count($tokens)) 
						satisfies ($is-role[$token-pos] or $is-link[$token-pos] or $is-gen[$token-pos]))">
						<tei:surname><xsl:value-of select="."/></tei:surname>
					</xsl:when>
					<xsl:otherwise>
						<tei:forename><xsl:value-of select="."/></tei:forename>
					</xsl:otherwise>
				</xsl:choose>
				<!--	
				<xsl:element name="{
					if ($is-role[$pos])
					then 'tei:roleName'
					else if ($is-link[$pos])
					then 'tei:nameLink'
					else if ($is-gen[$pos])
					then 'tei:genName'
					else if (($pos = count($tokens)) or
						(every $token-pos in (($pos + 1) to count($tokens)) 
						satisfies ($is-role[$token-pos] or $is-link[$token-pos] or $is-gen[$token-pos])))
					then 'tei:surname'
					else 'tei:forename'
					}">
					
					<xsl:sequence select="."/>
				</xsl:element>
				-->
			</xsl:for-each>
		</xsl:template>
		
		<xsl:template match="*[element() or text()[string-length(.) &gt; 0]]">
			<xsl:variable name="children" as="node()*">
				<xsl:apply-templates/>
			</xsl:variable>
			
			<xsl:if test="exists($children)">
				<xsl:copy>
					<xsl:sequence select="(@*[not(empty(.))], $children)"/>	
				</xsl:copy>
			</xsl:if>
		</xsl:template>
		
		<xsl:template match="xrx:titles" priority="10">
			<xsl:apply-templates/>
		</xsl:template>
		
		<xsl:template match="tei:title" priority="10">
			<xsl:variable name="title" as="element()?">
				<xsl:next-match/>
			</xsl:variable>
			<xsl:variable name="original-context" as="element()" select="."/>
			<xsl:for-each select="$title">
				<xsl:copy>
					<xsl:variable name="title-number" as="xs:integer"
						select="count($original-context/parent::xrx:titles/preceding-sibling::xrx:titles)"/>
					<xsl:copy-of select="@*"/>
					<xsl:if test="not(@xml:id)">
						<xsl:attribute name="xml:id" 
							select="$original-context/string-join((ancestor::tei:biblStruct/@xml:id,
								'title', @type, string($title-number + 1)), '-')"/>
					</xsl:if>
					<xsl:if test="$title-number">
						<xsl:attribute name="corresp" 
							select="$original-context/(parent::xrx:titles/preceding-sibling::xrx-titles[last()]/
								tei:title[@type=current()/@type]/@xml:id,
								string-join((ancestor::tei:biblStruct/@xml:id,
								'title', @type, string(1)),'-'))[1]"/>
					</xsl:if>
					<xsl:sequence select="child::node()"/>
				</xsl:copy>
			</xsl:for-each>
		</xsl:template>
		
		<xsl:template match="tei:listBibl" priority="10">
			<!--xsl:message>listBibl</xsl:message-->
			<xsl:copy>
				<xsl:sequence select="@*"/>
				<xsl:apply-templates/>
			</xsl:copy>
		</xsl:template>
		
	</xsl:stylesheet>
let $data as element(tei:listBibl) := 
	if ($debug) 
	then (
		<tei:listBibl>
			<tei:biblStruct xml:id="Baer1901">
				<tei:monogr>
					<tei:editor>Rabbi Seligmann Baer</tei:editor>
					<tei:title xml:lang="en" type="main">Seder Avodat Yisrael</tei:title>
					<tei:imprint>
						<tei:publisher>Lehrenberger</tei:publisher>
						<tei:pubPlace>Rodelheim</tei:pubPlace>
					</tei:imprint>
				</tei:monogr>
			</tei:biblStruct>
		</tei:listBibl>
	)
	else request:get-data()
let $cleaned-data as element(tei:listBibl) := transform:transform($data, $clean-stylesheet, ())	
let $bibliography-template :=
	<tei:TEI>
  	<tei:teiHeader>
    	<tei:fileDesc>
      	<tei:titleStmt>
      		<tei:title xml:lang="en">Global bibliography</tei:title>
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
    		<tei:div type="bibliography">
					{$cleaned-data}    						
    		</tei:div>
    	</tei:body>
    </tei:text>
	</tei:TEI>
return
	(app:make-collection-path(
		$bibliography-collection, '/db', 'admin',	'everyone', util:base-to-integer(0775, 8)),
	util:log-system-out(('Attempting to save bibliography...', 
		'Incoming data = ', $data, ' Cleaned data = ', $cleaned-data)),
	if (app:auth-user())
	then
		if (doc-available($bibliography-file))
		then (util:log-system-out('Found an existing bibliography.'),
			update replace doc($bibliography-file)//tei:div[@type='bibliography']/tei:listBibl with $cleaned-data,
			$data
			)
		else (util:log-system-out('No existing bibliography, making a new one.'),
			if (xmldb:store($bibliography-collection, $bibliography-resource, $bibliography-template))
			then (util:log-system-out('New bibliography created'),
				xmldb:set-resource-permissions($bibliography-collection, $bibliography-resource, 
					app:auth-user(),
					'everyone',
					util:base-to-integer(0775, 8)),				
				$data)
			else (util:log-system-out('Cannot store bibliography.'),error(xs:QName('err:SAVE'),'Cannot store!'))
			)
	else (util:log-system-out('Cannot do it. Login issue.'),error(xs:QName('err:NOT_LOGGED_IN'),'Not logged in!'))
	)
