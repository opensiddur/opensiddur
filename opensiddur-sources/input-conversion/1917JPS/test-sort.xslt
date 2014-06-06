<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" indent="yes" />

  <xsl:strip-space elements="*" />

  <xsl:template match="page">
    <xsl:copy>
      <xsl:apply-templates select="* | @id" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="textline">

    <!-- Find textline element that are *followed* by
        another one positioned to the *left*;
	probably indicates its out of order
	and need to adjust pdf2txt parameters. -->
    <xsl:variable name="left">
      <xsl:value-of select="@x" />
    </xsl:variable>
    <xsl:variable name="next-right">
      <xsl:value-of select="following-sibling::textline[1]/@x1" />
    </xsl:variable>
    <xsl:variable name="bottom">
      <xsl:value-of select="@y" />
    </xsl:variable>
    <xsl:variable name="next-top">
      <xsl:value-of select="following-sibling::textline[1]/@y1" />
    </xsl:variable>
    <xsl:if test="($left > $next-right) and ($bottom &lt; $next-top)">
      <xsl:element name="error">
	<xsl:attribute name="number">
	  <xsl:number />
	</xsl:attribute>
      <xsl:copy>
	<xsl:apply-templates select="@* | node()"/>
      </xsl:copy>
      <xsl:for-each select="following-sibling::textline[1]">
	<xsl:copy>
	  <xsl:apply-templates select="@* | node()"/>
	</xsl:copy>
      </xsl:for-each>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <xsl:template match="@*">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>


</xsl:stylesheet>
