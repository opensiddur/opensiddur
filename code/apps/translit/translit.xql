xquery version "1.0";
(: translit.xql
 : Transliteration demo front-end
 : Copyright 2010,2012-2013 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)

import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/db/code/modules/paths.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";


declare function local:translit-instance(
	$instance-id as xs:string)
	as element()+ {
	<xf:instance id="{$instance-id}">
		<transliterate xmlns="" xml:lang="he">
		</transliterate>
	</xf:instance>,
	<xf:instance id="{$instance-id}-table">
	  <table xmlns=""/>
	</xf:instance>,
	<xf:instance id="{$instance-id}-current-table">
	  <tr:schema/>
	</xf:instance>,
	<xf:instance id="{$instance-id}-tables" xmlns="" 
	  src="/api/data/transliteration">
	  <html xmlns="http://www.w3.org/1999/xhtml">
	    <head/>
	    <body/>
	  </html>
	</xf:instance>,(:
	<xf:submission id="{$instance-id}-load-tables"
	  method="get"
	  resource="/api/data/transliteration"
	  instance="{$instance-id}-tables"
	  replace="instance"
	  validate="false"
	  >
	  <xf:header>
	    <xf:name>Accept</xf:name>
	    <xf:value>application/xml</xf:value>
	  </xf:header>
	  <xf:action ev:event="xforms-submit-error">
      <xf:message level="modal">Cannot load transliteration table list.
      Error type: <xf:output value="event('error-type')"/>
      Error code: <xf:output value="event('response-status-code')"/>
      Error message: <xf:output value="event('response-body')"/>
      </xf:message>
    </xf:action>
	</xf:submission>,
	<xf:send ev:event="xforms-ready" submission="{$instance-id}-load-tables"/>,:)
	<xf:bind nodeset="instance('{$instance-id}')" type="xf:string" required="true()"/>,
	<xf:bind nodeset="instance('{$instance-id}')/@xml:lang" type="xf:string" required="true()"/>,
	<xf:bind nodeset="instance('{$instance-id}-table')" type="xf:string" required="true()"/>
};

declare function local:translit-ui(
	$instance-id as xs:string,
	$control-id as xs:string)
	as element(xf:group) {
	<xf:group ref="instance('{$instance-id}')" id="{$control-id}">
		<fieldset>
			<xf:select1 
			  ref="instance('{$instance-id}-table')" 
			  id="{$control-id}-select" incremental="true">
				<xf:label>Select a transliteration table: </xf:label>
				<xf:itemset nodeset="instance('{$instance-id}-tables')//*[@class='result']/html:a[@class='document']">
					<xf:label ref="."/>
					<xf:value ref="@href"/>
				</xf:itemset>
				<xf:action ev:event="xforms-value-changed">
				  <xf:send submission="current-table" />
				  <xf:setvalue 
				    ref="instance('{$instance-id}')/@xml:lang" 
				    value="instance('{$instance-id}-current-table')//tr:lang[1]/@in"
				    if="not(instance('{$instance-id}-current-table')//tr:lang/@in=instance('{$instance-id}')/@xml:lang)"/>
				</xf:action>
			</xf:select1>
			<!--
			<xf:select1 ref="instance('{$instance-id}')/self::*/@xml:lang" incremental="true">
			  <xf:label>Select an input language: </xf:label>
			  <xf:itemset nodeset="instance('{$instance-id}-current-table')/tr:table/tr:lang">
			    <xf:label ref="@in"/>
			    <xf:value ref="@in"/>
			  </xf:itemset>
			</xf:select1>
			-->
			<br/>
			<div class="textarea">
				<xf:textarea ref="self::*" id="{$control-id}-textarea" incremental="true">
					<xf:label>Enter the text to transliterate here:<br/></xf:label>
				</xf:textarea>
			</div>
		</fieldset>
	</xf:group>
};

let $form :=
<html xmlns="http://www.w3.org/1999/xhtml"
  xmlns:html="http://www.w3.org/1999/xhtml"
	xmlns:tei="http://www.tei-c.org/ns/1.0"
	xmlns:tr="http://jewishliturgy.org/ns/tr/1.0"
	xmlns:xs="http://www.w3.org/2001/XMLSchema"
	xmlns:xf="http://www.w3.org/2002/xforms">
	<head>
		<title>Open Siddur Transliterator Demo</title>
   	<xf:model>
			{local:translit-instance('translit')}
      {((: force Firefox to include namespace nodes :))}
      <xf:instance id="garbage">
        <garbage html:g="1" tr:g="1" />
      </xf:instance>
			<xf:instance id="transliteration-result" xmlns="">
			  <result/>
			</xf:instance>
			<xf:submission 
			  id="current-table"
			  serialization="none"
			  replace="instance"
			  instance="translit-current-table"
			  method="get">
			  <xf:resource value="instance('translit-table')"/>
			</xf:submission>
			<xf:submission id="transliterate" 
			  ref="instance('translit')" 
				instance="transliteration-result" 
				replace="instance" 
				method="post">
				<xf:resource value="concat('/api/demo',substring-after(instance('translit-table'),'/api/data'))"/>
				<xf:action ev:event="xforms-submit-error">
					<xf:message level="modal">Transliteration error. Make sure all required fields are filled in.
					Error code: <xf:output value="event('response-status-code')"/>
					Error message: <xf:output value="event('response-body')"/>
					</xf:message>
				</xf:action>
			</xf:submission>
		</xf:model>
		<style type="text/css"><![CDATA[
			.textarea textarea {
   			font-family: 'Ezra SIL',Cardo,'Keter YG','SBL Hebrew', 'Arial Unicode MS', Arial, sans-serif;
   			direction:rtl;
   			font-size:16pt;
   			height: 10em;
   			width: 90%;
			}
		]]></style>
		
	</head>
	<body>
		<h1>Open Siddur Transliteration Demo</h1>
		
		<p>This is a demo of the Open Siddur automated transliterator.</p>
		
		<p>Be aware of the following known issues:
			<ul>
				<li>All Hebrew text must be in Unicode encoding and all vowels must be written correctly.
				The transliterator is not tolerant of spelling mistakes.</li>
				<li>The transliterator is sensitive to the presence of the Unicode qamats qatan:<br/>
				<span xml:lang="he" lang="he">כָּל</span> will transliterate incorrectly,<br/> 
				<span xml:lang="he" lang="he">כׇּל</span> will transliterate correctly.</li>
				<li>The transliterator is sensitive to the presence of the Unicode holam haser for vav:<br/>
				<span xml:lang="he" lang="he">מִצְוֹת</span> will transliterate incorrectly,<br/> 
				<span xml:lang="he" lang="he">מִצְוֺת</span> will transliterate correctly.</li>
				<li>Problems? Tell us on the <a href="http://groups.google.com/group/opensiddur-tech">opensiddur-tech mailing list.</a></li>
			</ul>
		</p>
		{local:translit-ui('translit', 'control-translit')}
		
		<xf:submit submission="transliterate">
			<xf:label>Transliterate!</xf:label>
		</xf:submit>
		<p>
			<xf:output ref="instance('transliteration-result')/self::*[. != '']" 
				id="control-result">
				<xf:label>Transliteration: <br/></xf:label>
			</xf:output>
		</p>
  </body>
</html>
return
	($paths:xslt-pi,(: $paths:debug-pi,:) $form) 
