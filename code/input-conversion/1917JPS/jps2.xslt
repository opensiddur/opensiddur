<?xml version="1.0" encoding="UTF-8"?>
<!--
jps2.xslt for the OpenSiddur project.
Copyright 2011 Marc Stober and licensed under the GNU LGPL.

Given the XML produced by pdf2xml
from the 1917 JPS PDF, 
produce HTML as a test of certain conversion algorithms.
This particular HTML is more intended for testing/proofing than 
as reusable output.

Incorporates portions of: 

Program Name: jps.xslt
Author: Ze'ev Clementson
Created: May 19, 2011
License: Public Domain (http://creativecommons.org/publicdomain/zero/1.0/).
Description: Transform the XML code produced by running pdf2xml over Tanakh-JPS1917.pdf into 
something a bit more usable. Due to the limitations of the XML produced by pdf2xml, 
some manual corrections to the generated XML will be required.
-->
<xsl:stylesheet version="1.0"
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform" >
  <xsl:output method="xml" version="1.0" indent="yes"/>
  <xsl:param name="page" select="16"/><!-- default to Genesis 1 -->
  
  <xsl:template match="/">
    <!-- TODO HTML doctype (xhtml if not HTML5?) -->
    <!-- TODO build up stylesheet -->
    <!-- TODO don't try to import DTD in makefile -->
    <!-- TODO deal with broken words (certainly in Hebrew) -->
    <!-- TODO tidy this doc (within emacs?) -->
    <!-- TODO something in the top of the HTML that indicates what this is -->
    <html>
      <head>
        <meta http-equiv="Content-type" content="text/html;charset=UTF-8" />
        <link rel="stylesheet" type="text/css" href="style.css" />
      </head>
      <body>
	<xsl:for-each select="pdf2xml/page[@number = $page]">
	  <a>
	    <xsl:attribute name="href"><xsl:value-of select="($page)-1"/>.html</xsl:attribute>previous</a> | 
	    page <xsl:value-of select="@number"/> | 
	    <a>
	      <xsl:attribute name="href"><xsl:value-of select="($page)+1"/>.html</xsl:attribute>
	    next</a>
	    <div class="page">
	      <xsl:apply-templates select="text"/>
	    </div>
	</xsl:for-each>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="text">
    <div>
      <xsl:attribute name="class">
	text
	<!-- fudge of 3 pixels to account for superscripts -->
	<xsl:if test="preceding-sibling::text[1]/@top > (@top + 3)">
	  misplaced
	</xsl:if>
      </xsl:attribute>
      [
      top=<xsl:value-of select="@top" />
      ]
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  <xsl:variable name="prevvalue"><xsl:value-of select="preceding-sibling::text[1]"/></xsl:variable>
  <xsl:variable name="thisvalue"><xsl:value-of select="."/></xsl:variable>
  <xsl:template match="foo">
    <xsl:choose>
      <xsl:when test="@font = '0' and position() &gt; 2">
        <xsl:choose>
          <!-- If preceding TEXT was small font & alpha, it's a footnote (either ref or def)'. -->
          <xsl:when test="preceding-sibling::text[1]/@font = '9' and not(floor($prevvalue) = $prevvalue)">
            <footnote><xsl:apply-templates/></footnote>
          </xsl:when>
          <xsl:otherwise>
            <text><xsl:apply-templates/></text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="@font = '1' or @font = '3'">
        <xsl:choose>
          <xsl:when test="$thisvalue &gt; ' '">
            <!-- Book name. -->
            <book><xsl:apply-templates/></book>
          </xsl:when>
          <xsl:otherwise>
            <!-- Blank line. -->
            <br/><br/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="@font = '2' or @font = '14' or @font = '20' or @font = '22' or @font = '27'">
        <!-- Hebrew text. -->
        <heb><xsl:apply-templates/></heb>
      </xsl:when>
      <xsl:when test="@font = '4'">
        <!-- Blank line. -->
        <br/><br/>
      </xsl:when>
      <xsl:when test="@font = '8'">
        <footnote><xsl:apply-templates/></footnote>
      </xsl:when>
      <xsl:when test="@font = '9'">
        <xsl:choose>
          <xsl:when test="$thisvalue = ' '">
            <!-- New line after verse. -->
            <br/>
          </xsl:when>
          <xsl:when test="'OD' = $thisvalue">
            <!-- Divine name. -->
            <dn><xsl:apply-templates/></dn>
          </xsl:when>
          <!-- If TEXT is small font & alpha, it's a footnote (either ref or def)'. -->
          <xsl:when test="not(floor($thisvalue) = $thisvalue)">
            <fn><xsl:apply-templates/></fn>
          </xsl:when>
          <xsl:otherwise>
            <!-- If TEXT is small font & integer, it's a verse number'. -->
            <vn><xsl:apply-templates/></vn>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="@font = '16'">
        <text><xsl:apply-templates/></text>
      </xsl:when>
      <xsl:when test="@font = '17'">
        <xsl:choose>
          <xsl:when test="floor($thisvalue) = $thisvalue">
            <!-- Chapter number. -->
            <cn><xsl:apply-templates/></cn>
          </xsl:when>
          <xsl:otherwise>
            <!-- Text. -->
            <text><xsl:apply-templates/></text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="@font = '18'">
        <!-- Divine name. -->
        <dn><xsl:value-of select="."/></dn>
      </xsl:when>
      <xsl:otherwise>
        <!-- Anything else we missed? -->
        <xsl:choose>
          <xsl:when test="normalize-space($thisvalue) = ' '">
            <!-- Blank line. -->
            <br/>
          </xsl:when>
          <xsl:when test="floor($thisvalue) = $thisvalue">
            <!-- Throw away the "visible" page number (it's not always correct in the XML). -->
          </xsl:when>
          <xsl:otherwise>
            <!-- Text. -->
            <text><xsl:apply-templates/></text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="b">
    <b><xsl:apply-templates/></b>
  </xsl:template>

  <xsl:template match="i">
    <i><xsl:apply-templates/></i>
  </xsl:template>

  <xsl:template match="text()">
    <xsl:value-of select="."/>
  </xsl:template>
  
</xsl:stylesheet>