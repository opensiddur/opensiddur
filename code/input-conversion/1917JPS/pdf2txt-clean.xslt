<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" indent="yes"/>

  <xsl:strip-space elements="*"/>
  <xsl:preserve-space elements="text"/>

  <xsl:template match="@* | node()">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="textline">
    <xsl:copy>
      <!-- copy attributes -->
      <xsl:apply-templates select="@*" />

      <!-- select first text element, others handled recursively -->
      <xsl:apply-templates select="text[1]" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="text">
    <xsl:variable name="size">
      <xsl:value-of select="@size" />
    </xsl:variable>

    <!-- join same size adjacent text elements -->
    <xsl:element name="text">
      <xsl:attribute name="size">
	<xsl:value-of select="@size" />
      </xsl:attribute>
      <xsl:call-template name="text-same-size">
	<xsl:with-param name="size" select="$size" />
      </xsl:call-template>
    </xsl:element>

    <!-- Recurse with next text element not same size -->
    <xsl:for-each select="following-sibling::text[@size != $size][1]">
      <xsl:apply-templates select="." />
    </xsl:for-each>

  </xsl:template>

  <!-- Recursively find same size adjacent text elements.
       Call in context of a text element. -->
  <xsl:template name="text-same-size">
    <xsl:param name="size" />
    <!-- If no size, join in anyway -->
    <xsl:if test="not(@size) or @size=$size">
      <xsl:value-of select="." />
      <!-- Get next sibling and recurse -->      
      <xsl:for-each select="following-sibling::text[1]">
	<xsl:call-template name="text-same-size">
	  <xsl:with-param name="size" select="$size" />
	</xsl:call-template>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
