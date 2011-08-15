<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:exsl="http://exslt.org/common"
                extension-element-prefixes="exsl">

<!-- group-lines.xslt
     For the OpenSiddur project. Copyright 2011 Marc Stober and licensed under the LGPL. 
     TODO etc.
-->
<!-- Test: compare columns.xml to group-lines.xml -->

  <xsl:output method="xml" indent="yes"/>

  <xsl:strip-space elements="*" />

  <xsl:template match="@* | node()">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="header | column | footnotes| footer">
    <xsl:copy>
      <!-- pass first textline node into groups function -->
      <xsl:apply-templates select="textline[1]" mode="groups" />
    </xsl:copy>
  </xsl:template>

  <!-- find groups of textline nodes with same baseline (y) -->
  <xsl:template match="textline" mode="groups">
    <xsl:variable name="y">
      <xsl:value-of select="@y" />
    </xsl:variable>
    <!-- xsl:element name="textline-group"> TODO just sort don't enclose -->
      <xsl:variable name="the-group">
	<xsl:call-template name="join-same">
	  <xsl:with-param name="y">
	    <xsl:value-of select="$y" />
	  </xsl:with-param>
	</xsl:call-template>
      </xsl:variable>
      <xsl:apply-templates select="exsl:node-set($the-group)/textline">
	<xsl:sort select="@x" data-type="number" />
      </xsl:apply-templates>
    <!-- /xsl:element -->
    <!-- recurse, next group -->
    <xsl:apply-templates select="following-sibling::textline[@y != $y][1]" mode="groups" />
  </xsl:template>

  <!-- join adjacent (textline) with same (@y) -->
  <xsl:template name="join-same">
    <xsl:param name="y" />
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" />
    </xsl:copy>
    <xsl:if test="following-sibling::textline[1][@y = $y]">
      <xsl:for-each select="following-sibling::textline[1]">
      <xsl:call-template name="join-same">
	<xsl:with-param name="y">
	  <xsl:value-of select="$y" />
	</xsl:with-param>
      </xsl:call-template>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
