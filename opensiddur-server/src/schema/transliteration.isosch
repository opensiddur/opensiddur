<?xml version="1.0" encoding="utf-8"?>
<!-- 
  Schematron schema for transliteration schema files
  
  Copyright 2009,2012 Efraim Feinstein <efraim@opensiddur.org>
  
  This file is part of the Open Siddur Project.
  
  This file is released under the GNU Lesser General Public License version 3, 
  or at your option, any later version.
 -->
<sch:schema 
         xmlns:sch="http://purl.oclc.org/dsdl/schematron"
         xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
         xmlns:tei ="http://www.tei-c.org/ns/1.0"
         xmlns:j ="http://jewishliturgy.org/ns/jlptei/1.0"
         queryBinding='xslt2'
         schemaVersion="sch19757-3"
         xml:lang="en">
  <sch:title>Rules for transliteration schema</sch:title>
  <sch:ns prefix='tr' uri='http://jewishliturgy.org/ns/tr/1.0'/>
  <xsl:key match="tr:lang" use="@in" name="input-language"/>
  <sch:pattern>
    <sch:title>Uniqueness of table input language</sch:title>
    <sch:rule context="tr:lang">
      <sch:assert test="count(key('input-language', @in))=1">
        The input language in a tr:lang must be unique.
      </sch:assert>
    </sch:rule>
  </sch:pattern>
</sch:schema>
