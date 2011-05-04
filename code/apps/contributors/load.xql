xquery version "1.0";
(: Contributors list loader
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: load.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "../../modules/paths.xqm";
import module namespace common="http://jewishliturgy.org/apps/contributors/common"
	at "modules/common.xqm";

(: this XSLT transform converts an active contributor list into something that fits the prototype :)
let $transform :=
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
    
    <xsl:include href="{$paths:rest-prefix}{$paths:modules}/prototype.xsl2"/>
    
    <xsl:param name="prototype" as="element(tei:item)">
    	{$common:prototype}
    </xsl:param>
    
    <xsl:template match="tei:list">
    	<xsl:for-each select="tei:item">
        <xsl:sort select="@xml:id"/>
    		<xsl:apply-templates select="$prototype">
 					<xsl:with-param name="data" as="element()" select=".">
 					</xsl:with-param>
 				</xsl:apply-templates>
    	</xsl:for-each>
    </xsl:template>
	</xsl:stylesheet>

let $contrib-list-items := 
	if (doc-available($common:list))
	then transform:transform(
		doc($common:list)//tei:div[@type='contributors']/tei:list,
		$transform, ())
	else ()
let $id := request:get-parameter('id','')
let $items as element(tei:item)* := 
	if ($id) 
	then ($contrib-list-items[@xml:id=$id], $common:prototype)[1]
	else $contrib-list-items
return (
	<tei:list>{
		($items)
	}</tei:list>
	)

