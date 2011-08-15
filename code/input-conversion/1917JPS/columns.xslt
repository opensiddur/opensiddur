<?xml version="1.0" encoding="UTF-8"?>
<!--
columns.xslt for the OpenSiddur project.
Copyright 2011 Marc Stober and licensed under the GNU LGPL.

Given cleaned-up XML file produced by clean.xslt
sort into columns (including columns, header, footer, and footnotes).
This is done by analyzing the position of the text relative
to 

on the PDF of the JPS 1917 Tanakh, transform into more useful XML.
-->
<xsl:stylesheet version="1.0"
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
		xmlns:str="http://exslt.org/strings">
  <xsl:output method="xml" version="1.0" indent="yes" />

  <xsl:strip-space elements="*" />

  <!-- TODO
       Convert to XSL2
       Footnotes
       Paragraphs (poetry?)
       Make sure Hebrew is output (correctly)
       See how pages without columns (front matter, etc.) output.
       "Spell check" against a dictionary?
       Tidy?
       Extract Toc outline?
  -->

  <xsl:template match="@*|*">
    <xsl:param name="columnSplit" />
    <xsl:copy>
      <xsl:apply-templates select="*|@*|node()">
	<xsl:with-param name="columnSplit" select="$columnSplit" />
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="page">

    <!-- Analyze column, header, footer, footnote boundaries. 
	 Assumes two columns separated by a line. -->
    <!-- TODO what if we have 0 column boundaries (i.e., front matter, title pages) -->
    <xsl:variable name="columnSplit">
      <xsl:value-of select=".//rect[@x1 - @x &lt; 1]/@x" />
    </xsl:variable>
    <xsl:variable name="headerAbove">
      <xsl:value-of select=".//rect[@x1 - @x &lt; 1]/@y1" />
    </xsl:variable>
    <xsl:variable name="footerBelow">
      <xsl:value-of select=".//rect[@x1 - @x &lt; 1]/@y" />
    </xsl:variable>

    <xsl:copy>
      <xsl:apply-templates select="@id" />
      <!-- this is just for debugging and could potentially be removed -->
      <xsl:comment>
	$columnSplit=<xsl:value-of select="$columnSplit" />
	$headerAbove=<xsl:value-of select="$headerAbove" />
	$footerBelow=<xsl:value-of select="$footerBelow" />
      </xsl:comment>

      <xsl:element name="header">
	<xsl:apply-templates select=".//textline[@y &gt; $headerAbove]" />
      </xsl:element>

      <xsl:element name="column">
	<xsl:apply-templates select=".//textline[(@y &lt;= $headerAbove) and 
				     (@y &gt;= $footerBelow) and 
				     (@x &lt;= $columnSplit)]" />
      </xsl:element>

      <xsl:element name="footnotes">
      </xsl:element>

      <xsl:element name="column">
	<xsl:apply-templates select=".//textline[(@y &lt;= $headerAbove) and 
				     (@y &gt;= $footerBelow) and 
				     (@x &gt; $columnSplit)]" />
      </xsl:element>

      <xsl:element name="footnotes">
      </xsl:element>

      <xsl:element name="footer">
	<xsl:apply-templates select=".//textline[@y &lt; $footerBelow]" />
      </xsl:element>

    </xsl:copy>
  </xsl:template>

  <xsl:template match="rect[@y1-y &lt; 1]">
    <footnoteBoundary>
      <xsl:apply-templates select="str:split(@bbox, ',')" />
    </footnoteBoundary>
  </xsl:template>

  <xsl:template match="textline">
    <!-- don't output if empty or whitespace only -->
    <xsl:if test="normalize-space()">
      <xsl:copy>
	<xsl:apply-templates select="@* | *" />

	<!-- xsl:variable name="linetext">
	     <xsl:for-each select="text[1]">
	     <xsl:call-template name="text" />
	     </xsl:for-each>
	     </xsl:variable -->
	<!-- xsl:value-of select="normalize-space($linetext)" / -->
      </xsl:copy>
    </xsl:if>
  </xsl:template>

  <xsl:template match="text">
    <!-- don't output if empty or whitespace only -->
    <xsl:if test="normalize-space()">
      <xsl:choose>
	<xsl:when test="@size = 25.961" >
	  <xsl:element name="chapter-number">
	    <xsl:value-of select="." />
	  </xsl:element>
	</xsl:when>
	<xsl:when test="@size = 6.327" >
	  <xsl:element name="verse-number">
	    <xsl:value-of select="." />
	  </xsl:element>
	</xsl:when>
	<xsl:when test="@size = 10.035" >
	  <xsl:value-of select="." />
	</xsl:when>
	<xsl:otherwise>
	  <xsl:copy>
	    <xsl:if test="@size != 10.035">
	      <xsl:apply-templates select="@size" />
	    </xsl:if>
	    <xsl:value-of select="translate(.,'&#10;','&#9166;')" />
	  </xsl:copy>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>