<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
	version="2.0" 
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:tei="http://www.tei-c.org/ns/1.0"
	xmlns:xs="http://www.w3.org/2001/XMLSchema"
	xmlns:j="http://jewishliturgy.org/ns/1.0"
	xmlns:xd="http://www.pnp-software.com/XSLTdoc"
	xmlns:html="http://www.w3.org/1999/xhtml"
	exclude-result-prefixes="#all"
	>
	<xd:doc type="stylesheet">
		<xd:short>Defines conversions between syntactic sugar elements defined by JLPTEI and canonical TEI.</xd:short>
		<xd:author>$Author$</xd:author>
		<xd:svnId>$Id: canonical-tei.xsl2 217 2009-07-24 21:56:37Z efraim.feinstein $</xd:svnId>
	</xd:doc>

	<xd:doc>
		<xd:short>Convert the concurrent tag to a canonical tei:div</xd:short>
	</xd:doc>
	<xsl:template match="j:concurrent" xml:id="transform.concurrent">
		<tei:div type="concurrent">
			<xsl:apply-templates/>
		</tei:div>
	</xsl:template>
	
	<xd:doc>
		<xd:short>Convert the Divine name tag to a canonical tei:name</xd:short>
	</xd:doc>
	<xsl:template match="j:divineName" xml:id="transform.divineName">
		<tei:name type="divine">
			<xsl:if test="@type">
				<xsl:attribute name="subtype" select="@type"/>
			</xsl:if>
			<xsl:apply-templates/>
		</tei:name>
	</xsl:template>
	
	<xd:doc>
		<xd:short>Convert the option tag to a canonical tei:seg</xd:short>
	</xd:doc>
	<xsl:template match="j:option" xml:id="transform.option">
		<tei:seg type="option">
			<xsl:if test="@type">
				<xsl:attribute name="subtype" select="@type"/>
			</xsl:if>
			<xsl:copy-of select="@*[not(name()='type')]"/>
			<xsl:attribute name="subtype" select="@type"/>
			<xsl:apply-templates/>
		</tei:seg>
	</xsl:template>

	<xd:doc>
		<xd:short>Convert the read tag to a canonical tei:seg</xd:short>
	</xd:doc>
	<xsl:template match="j:read" xml:id="transform.read">
		<tei:seg type="read">
			<xsl:apply-templates/>
		</tei:seg>
	</xsl:template>

	<xd:doc>
		<xd:short>Convert the written tag to a canonical tei respStmt</xd:short>
	</xd:doc>
	<xsl:template match="j:respList" xml:id="transform.respList">
		<tei:respStmt>
			<xsl:apply-templates mode="respList"/>
		</tei:respStmt>
	</xsl:template>
	
	<!-- TODO: add mode=respList to convert tei:respons->tei:respStmt internals -->
	
	<xd:doc>
		<xd:short>Convert the RDF tag to nothing</xd:short>
	</xd:doc>
	<xsl:template match="rdf:RDF" xml:id="transform.RDF" />
	
	<xd:doc>
		<xd:short>Convert the repository tag to a canonical tei:div</xd:short>
	</xd:doc>
	<xsl:template match="j:repository" xml:id="transform.repository">
		<tei:div type="repository">
			<xsl:if test="@type">
				<xsl:attribute name="subtype" select="@type"/>
			</xsl:if>
			<xsl:apply-templates/>
		</tei:div>
	</xsl:template>

	<xd:doc>
		<xd:short>Convert the view tag to a canonical tei:div</xd:short>
	</xd:doc>
	<xsl:template match="j:view" xml:id="transform.view">
		<tei:div type="view">
			<xsl:attribute name="subtype" select="@type"/>
			<xsl:apply-templates/>
		</tei:div>
	</xsl:template>

	<xd:doc>
		<xd:short>Convert the written tag to a canonical tei:seg</xd:short>
	</xd:doc>
	<xsl:template match="j:written" xml:id="transform.written">
		<tei:seg type="written">
			<xsl:apply-templates/>
		</tei:seg>
	</xsl:template>
	
	<xd:doc>
		<xd:short>By default, copy.</xd:short>
	</xd:doc>
	<xsl:template match="*|@*">
		<xsl:copy>
			<xsl:apply-templates select="@*|*"/>
		</xsl:copy>
	</xsl:template>
</xsl:stylesheet>