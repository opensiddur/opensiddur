<?xml version="1.0" encoding="utf-8"?>
<!-- Make changes to web.xml required for setup. Input is the existing web.xml -->
<xsl:stylesheet
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        xmlns="http://xmlns.jcp.org/xml/ns/javaee"
        version="2.0">
  <xsl:output method="xml" indent="yes"/>

    <!-- deny direct access to the REST interface -->
    <xsl:template match="*:servlet[*:servlet-name='EXistServlet']/*:init-param[*:param-name='hidden']">
    <xsl:copy>
        <xsl:copy-of select="@*"/>
        <param-name>hidden</param-name>
        <param-value>true</param-value>
    </xsl:copy>
    </xsl:template>

    <!-- disable xquery and xupdate through the rest server -->
    <xsl:template match="*:servlet[*:servlet-name='EXistServlet']/*:init-param[*:param-name=('xquery-submission', 'xupdate-submission')]">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="param-name"/>
            <param-value>disabled</param-value>
        </xsl:copy>
    </xsl:template>

    <!-- disable WebDAV -->
    <xsl:template match="*:servlet[*:servlet-name='milton']"/>

    <!-- disable BetterFORM -->
    <xsl:template match="*:context-param[*:param-name='betterform.configfile']"/>
    <xsl:template match="*:servlet[*:servlet-name=('Flux', 'XFormsPostServlet', 'FormsServlet', 'inspector', 'ResourceServlet', 'error')]"/>
    <xsl:template match="*:servlet-mapping[*:servlet-name=('Flux', 'XFormsPostServlet', 'FormsServlet', 'inspector', 'ResourceServlet', 'error')]"/>
    <xsl:template match="*:servlet-mapping[*:servlet-name='XQueryServlet'][*:url-pattern]"/>
    <xsl:template match="*:filter[*:filter-name='XFormsFilter']"/>
    <xsl:template match="*:filter-mapping[*:filter-name='XFormsFilter']"/>
    <xsl:template match="*:listener[contains(*:listener-class, 'betterform')]"/>

    <!-- default operation is identity -->
    <xsl:template match="element()|comment()">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>  
