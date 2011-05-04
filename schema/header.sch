<?xml version="1.0" encoding="utf-8"?>
<!-- 
  Schematron schema for JLPTEI headers.
  
  Copyright 2009 Efraim Feinstein <efraim.feinstein@gmail.com>
  
  This file is part of the Jewish Liturgy Project/Open Siddur.
  
  This file is released under the GNU Lesser General Public License version 3, 
  or at your option, any later version.
  
  $Id: header.sch 452 2010-02-16 02:08:52Z efraim.feinstein $
 -->
<sch:schema 
         xmlns:sch="http://purl.oclc.org/dsdl/schematron" 
         xmlns:tei ="http://www.tei-c.org/ns/1.0"
         xmlns:j ="http://jewishliturgy.org/ns/jlptei/1.0"
         queryBinding='xslt2'
         schemaVersion="sch19757-3"
         xml:lang="en">
  <sch:title>Rules for headers (aka, all valid JLPTEI files)</sch:title>
  <sch:ns prefix='tei' uri='http://www.tei-c.org/ns/1.0'/>
  <sch:ns prefix='j' uri='http://jewishliturgy.org/ns/jlptei/1.0'/>
  <sch:pattern name="licensing information">
    <sch:rule context="tei:availability">
      <sch:assert test="tei:p">
        All JLPTEI files must have a human-readable license description in the header.
      </sch:assert>
    </sch:rule>
  </sch:pattern>
</sch:schema>
