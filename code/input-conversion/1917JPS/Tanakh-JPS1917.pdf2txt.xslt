<?xml version="1.0" encoding="UTF-8"?>
<!--
Tanakh-JPS1917.pdf2txt.xslt for the OpenSiddur project.
Copyright 2011 Marc Stober and licensed under the GNU LGPL.

Given the XML file produced by running the PDFMiner tool pdf2txt.py 
on the PDF of the JPS 1917 Tanakh, transform into more useful XML.
-->
<xsl:stylesheet version="1.0"
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
		xmlns:str="http://exslt.org/strings">
  <xsl:output method="xml" version="1.0" indent="yes" />

  <xsl:strip-space elements="*" />
  <xsl:preserve-space elements="text" />

  <!-- TODO
       Split columns (in progress)
       Backup!!!
       "Spell check" against a dictionary.
       Identify verse numbers, etc.
       Poetry?
  -->

  <xsl:template match="@*|*">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="page">

    <!-- Analyze column and footnote position. (Is there a cleaner way?) -->
    <xsl:variable name="columnBoundaryX">
      <xsl:for-each select="//rect">
	<xsl:variable name="x"><xsl:value-of select="str:split(@bbox,',')[1]" /></xsl:variable>
	<xsl:if test="(str:split(@bbox,',')[3])-($x) &lt; 1">
	  <xsl:value-of select="$x" />
	</xsl:if>
      </xsl:for-each>
    </xsl:variable>
    <!-- TODO check that we only have one column boundary -->
    <!-- TODO what if we have 0 column boundaries (i.e., front matter, title pages) -->

    <xsl:copy>
      <xsl:attribute name="columnBoundaryX">
	<xsl:value-of select="$columnBoundaryX" />
      </xsl:attribute>
      <xsl:apply-templates select="@*"/>
      <!-- rects divide columns and footnotes. Find them first. -->
      <!-- TODO: are there ever any other rects? -->
      <xsl:apply-templates select="rect" />
      <xsl:apply-templates select="*[name()!='rect']"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="rect">
      <!-- is there a way to make this prettier? -->
      <xsl:variable name="x"><xsl:value-of select="substring-before(@bbox,',')" /></xsl:variable>
      <xsl:variable name="x1">
	<xsl:value-of select="substring-before(substring-after(substring-after(@bbox,','),','),',')" />
      </xsl:variable>
      <xsl:choose>
	<xsl:when test="($x1)-($x) &lt; 1">
	</xsl:when>
	<xsl:otherwise>
	  <footnoteBoundary>
	    <xsl:apply-templates select="str:split(@bbox, ',')" />
	  </footnoteBoundary>
	</xsl:otherwise>
      </xsl:choose>

  </xsl:template>

  <xsl:template match="textline">
    <xsl:copy>
      <!-- copy attributes TODO might not always need this -->
      <xsl:apply-templates select="@*" />
      <xsl:attribute name="class">
	<xsl:value-of select="substring-before(@bbox,',')" />
	<xsl:choose>
	  <xsl:when>
	    col-left
	  </xsl:when>
	  <xsl:otherwise>
	    col-right
	  </xsl:otherwise>
	</xsl:choose>
      </xsl:attribute>
      <xsl:variable name="linetext"><xsl:apply-templates select="text" /></xsl:variable>
      <xsl:value-of select="normalize-space($linetext)" />
    </xsl:copy>
  </xsl:template>

  <!-- DON'T xsl:copy the text element, just its contents -->
  <xsl:template match="text">
    <xsl:value-of select="." />
  </xsl:template>

</xsl:stylesheet>