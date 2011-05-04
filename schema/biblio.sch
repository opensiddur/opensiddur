<?xml version="1.0" encoding="UTF-8"?>
<!-- 
  Schematron schema for bibliography lists.
  
  Copyright 2009 Efraim Feinstein <efraim.feinstein@gmail.com>
  
  This file is part of the Jewish Liturgy Project/Open Siddur.
  
  This file is released under the GNU Lesser General Public License version 3, 
  or at your option, any later version.
  
  $Id: biblio.sch 452 2010-02-16 02:08:52Z efraim.feinstein $
 -->
<sch:schema 
         xmlns:sch="http://purl.oclc.org/dsdl/schematron"
         xmlns:tei ="http://www.tei-c.org/ns/1.0"
         xmlns:j ="http://jewishliturgy.org/ns/jlptei/1.0"
         xml:lang="en">
  <sch:ns prefix='tei' uri='http://www.tei-c.org/ns/1.0'/>
  <sch:ns prefix='j' uri='http://jewishliturgy.org/ns/jlptei/1.0'/>
  <sch:pattern name="Check if file contains a bibliography" id="pat.file">
    <sch:rule context="tei:TEI">
      <sch:assert test="tei:text/tei:body/tei:div[@type='bibliography']/tei:listBibl">
        The file does not contain a bibliography.
      </sch:assert>
    </sch:rule>
  </sch:pattern>
  <sch:pattern name="Generic test for biblStruct." id="pat.biblStruct">
    <sch:rule context="tei:biblStruct" >
      <sch:assert test="@xml:id">
        Each item in a bibliography must have a unique @xml:id attribute.
      </sch:assert>
      <sch:assert test="count(id(@xml:id)) &lt; 2">
        An item has a nonunique @xml:id.
      </sch:assert>
    </sch:rule>
  </sch:pattern>
  <sch:pattern name="Pattern for a published book" id="pat.book">
    <sch:rule context="tei:monogr">
      <sch:assert test="tei:author|tei:editor">
        A book must have an author or editor.
      </sch:assert>
      <sch:assert test="tei:title">
        A book must have a title.
      </sch:assert>
      <sch:assert test="tei:title/ancestor-or-self::*[@xml:lang]">
        The language of a title must be known by self or ancestor's @xml:lang.
      </sch:assert>
    </sch:rule>
    <sch:rule context="tei:imprint">
      <sch:assert test="tei:publisher">
        A book record is required to have a publisher.
      </sch:assert>
      <sch:assert test="tei:date">
        A book record is required to have a publication date.
      </sch:assert>
    </sch:rule>    
    <sch:rule context="tei:distributor">
      <sch:assert test="not(tei:ref[@type='url']) or 
        (tei:ref[@type='url'] and tei:date[@type='access'])">
        A bibliographic record for an Internet resource must include both a URL
        reference and an access date.
      </sch:assert>
    </sch:rule>   
  </sch:pattern>
</sch:schema>
