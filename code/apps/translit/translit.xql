xquery version "1.0";
(: translit.xql
 : Transliteration demo front-end
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: translit.xql 775 2011-05-01 06:46:55Z efraim.feinstein $
 :)

import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/code/modules/paths.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace xrx="http://jewishliturgy.org/ns/xrx";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";

declare variable $local:path-to-transliteration-tables :=
	'/data/transliteration';

declare function local:translit-instance(
	$instance-id as xs:string)
	as element()+ {
	(
	<xf:instance id="{$instance-id}" xmlns="">
		<translit>
			<table/>
			<text/>
		</translit>
	</xf:instance>,
	<xf:instance id="{$instance-id}-tables" xmlns="">
		<tables>{
			for $resource in 
				xmldb:get-child-resources($local:path-to-transliteration-tables)
			order by number(replace($resource, '[^\d]',''))
			return (
				if (ends-with($resource, '.tr.xml'))
				then
					<table>{replace($resource, '.tr.xml', '')}</table>
				else ()
			)
		}</tables>
	</xf:instance>,
	<xf:bind nodeset="instance('{$instance-id}')/table" required="true()"/>,
	<xf:bind nodeset="instance('{$instance-id}')/text" required="true()"/>
	)
};

declare function local:translit-ui(
	$instance-id as xs:string,
	$control-id as xs:string)
	as element(xf:group) {
	<xf:group ref="instance('{$instance-id}')" id="{$control-id}">
		<fieldset>
			<xf:select1 ref="table" id="{$control-id}-select" incremental="true">
				<xf:label>Select a transliteration table: </xf:label>
				<xf:itemset nodeset="instance('{$instance-id}-tables')/table">
					<xf:label ref="."/>
					<xf:value ref="."/>
				</xf:itemset>
			</xf:select1>
			<br/>
			<div class="textarea">
				<xf:textarea ref="text" id="{$control-id}-textarea" incremental="true">
					<xf:label>Enter the text to transliterate here:<br/></xf:label>
				</xf:textarea>
			</div>
		</fieldset>
	</xf:group>
};

let $form :=
<html xmlns="http://www.w3.org/1999/xhtml"
	xmlns:tei="http://www.tei-c.org/ns/1.0"
	xmlns:xs="http://www.w3.org/2001/XMLSchema"
	xmlns:xf="http://www.w3.org/2002/xforms">
	<head>
		<title>Open Siddur Transliterator Demo</title>
   	<xf:model>
			{local:translit-instance('translit')}
			
			<xf:instance id="transliteration-result" xmlns="">
				<transliteration-result>
					<text/>
				</transliteration-result>
			</xf:instance>
			
			<xf:submission id="transliterate" ref="instance('translit')" 
				instance="transliteration-result" replace="instance" 
				action="do-translit.xql" method="post">
				<xf:action ev:event="xforms-submit-error">
					<xf:message level="modal">Transliteration error. Fill in all required fields.</xf:message>
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
			<xf:output ref="instance('transliteration-result')/text[. != '']" 
				id="control-result">
				<xf:label>Transliteration: <br/></xf:label>
			</xf:output>
		</p>
  </body>
</html>
return
	($paths:xslt-pi, (:$paths:debug-pi,:) $form) 
