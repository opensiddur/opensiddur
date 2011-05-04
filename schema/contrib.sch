<?xml version="1.0" encoding="utf-8"?>
<!-- 
  Schematron schema for contributor lists.
  
  Copyright 2009 Efraim Feinstein <efraim.feinstein@gmail.com>
  
  This file is part of the Jewish Liturgy Project/Open Siddur.
  
  This file is released under the GNU Lesser General Public License version 3, 
  or at your option, any later version.
  
  $Id: contrib.sch 452 2010-02-16 02:08:52Z efraim.feinstein $
 -->
<sch:schema 
         xmlns:sch="http://purl.oclc.org/dsdl/schematron" 
         xmlns:tei ="http://www.tei-c.org/ns/1.0"
         xmlns:j ="http://jewishliturgy.org/ns/jlptei/1.0"
         queryBinding='xslt2'
         schemaVersion="sch19757-3"
         xml:lang="en">
  <sch:title>Contributor list schema rules</sch:title>
  <sch:ns prefix='tei' uri='http://www.tei-c.org/ns/1.0'/>
  <sch:ns prefix='j' uri='http://jewishliturgy.org/ns/jlptei/1.0'/>
  <sch:pattern>
    <sch:rule context="tei:body">
      <sch:assert test="tei:div[@type='contributors']/tei:list">
        The file does not contain a contributor list.
      </sch:assert>
    </sch:rule>
  </sch:pattern>
  <sch:pattern>
    <sch:rule context="tei:item" >
      <sch:assert test="@xml:id">
        Each item in a contributor list must have an @xml:id attribute.
      </sch:assert>
      <sch:assert test="count(id(@xml:id)) &lt; 2">
        The item <sch:value-of select="@xml:id"/> has a nonunique @xml:id
      </sch:assert>
      <sch:assert test="tei:name|tei:forename|tei:surname|tei:orgName">
        Each item in a contributor list must include a person or organization's name.   
      </sch:assert>
    </sch:rule>
  </sch:pattern>
  <sch:pattern name="patterns for individual contributors">
    <sch:rule context="tei:item[tei:name|tei:forename|tei:surname]">
      <sch:assert test="tei:email">
        Each individual's contributor list item must have a contact email address.
      </sch:assert>
    </sch:rule>
    <sch:rule context="tei:item[tei:name|tei:forename|tei:surname]/tei:affiliation">
      <sch:report test="not(tei:ptr)">
        Affiliations must be linked to another contributor list item.
      </sch:report>
    </sch:rule>
    <sch:rule context="tei:affiliation/tei:ptr">
      <sch:assert test="//id(@target)/self::tei:item/tei:orgName">
        Affiliation pointers must point to organizational items in the contributor list.
      </sch:assert>
    </sch:rule>
    <sch:rule context="tei:item[tei:name|tei:forename|tei:surname]/tei:ptr">
      <sch:assert test="@type='openid'">
        The only supported pointer type in an individual's contributor list item
        is to an OpenID URI.
      </sch:assert>
      <sch:assert 
        test="count(../../tei:item/tei:ptr/@target=current()/@target) &lt; 2">
        Each contributor's OpenID must be unique.
      </sch:assert>
    </sch:rule>
  </sch:pattern>
  <sch:pattern name="patterns for organizational contributors">
    <sch:rule context="tei:item[tei:orgName]/tei:ptr">
      <sch:assert test="@type='url'">
        Organization listings may only have pointers of type 'url' that point to 
        the organization's Internet presence. 
      </sch:assert>
    </sch:rule>
  </sch:pattern>
</sch:schema>
