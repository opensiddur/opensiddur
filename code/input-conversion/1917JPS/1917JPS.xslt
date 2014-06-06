<?xml version="1.0" encoding="UTF-8"?>
<!--
1917JPS.xslt for the OpenSiddur project.
Copyright 2011 Marc Stober and licensed under the GNU LGPL.

Given the XML file produced by running the PDFMiner tool pdf2txt.py 
on the PDF of the JPS 1917 Tanakh, transform into more useful XML.
-->
<xsl:stylesheet version="1.0"
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
		xmlns:str="http://exslt.org/strings">
  <xsl:output method="xml" version="1.0" indent="yes" />

  <!-- xsl:strip-space elements="*" / -->
  <!-- xsl:preserve-space elements="text" / -->

  <xsl:template match="@* | node()">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

<xsl:template match="textline">
      <xsl:apply-templates select="node()"/>
</xsl:template>

</xsl:stylesheet>