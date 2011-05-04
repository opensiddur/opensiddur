xquery version "1.0";
(: do-wiki-import.xql
 : Take a corrected imported text and convert it to first-pass XML 
 : Requires login
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: do-convert-to-xml.xql 709 2011-02-24 06:37:44Z efraim.feinstein $
 :)
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace err="http://jewishliturgy.org/apps/errors";
declare option exist:serialize "method=xml media-type=text/xml";
declare option exist:output-size-limit "500000"; (: 50x larger than default :)

import module namespace app="http://jewishliturgy.org/ns/functions/app";
import module namespace contributors="http://jewishliturgy.org/apps/lib/contributors"
	at "../lib/contributors.xqm";
import module namespace paths="http://jewishliturgy.org/apps/lib/paths"
	at "../lib/paths.xqm";

declare function local:write-output-files(
	$output-files as element(result-document)+) as element(written-files) {
	let $user := app:auth-user()
	let $user-collection := xmldb:get-user-home($user)
	return
		<written-files xmlns="">{
			for $output in $output-files
			return 
				let $fname := string($output/@href)
				return
					if(xmldb:store($user-collection, $fname, $output/*))
					then <file xmlns="">{$fname}</file>
					else error(xs:QName('err:STORAGE'),concat('Cannot store ', $fname))
		}</written-files>
};

declare function local:unknown-contributors(
	$contributors-index as element(result-document))
	as element(unknown-contributors) {
	let $contributors-file := '/db/group/everyone/contributors/contributors.xml' 
	let $contributors :=
		if (doc-available($contributors-file))
		then doc($contributors-file)
		else () 
	return (
		util:log-system-out(('unknown-contributors', $contributors-index)),
		<unknown-contributors xmlns="">{
			for $contributor in $contributors-index//@xml:id
			return (
				util:log-system-out(('contributor: ', string($contributor))),
				(
				if ($contributors/id(string($contributor)))
				then ()
				else
					<tei:item>{(
						attribute xml:id {string($contributor)},
						$contributors:prototype/*)
					}</tei:item>
				)
			)
		}</unknown-contributors>
	)
};

let $logged-in := app:authenticate() or 
	error(xs:QName('err:NOT_LOGGED_IN'), 'You must be logged in.')
let $user-collection := 
	if ($logged-in) 
	then xmldb:get-user-home(app:auth-user()) 
	else ''
let $resource-name := 'upload.txt'
let $upload-path := 
	concat($paths:rest-prefix, $user-collection, '/', $resource-name)
let $path-to-grammar-xslt :=
	concat(
	$paths:rest-prefix,
	'/db/code/input-conversion/rawtext/rt-grammar.xsl2'
	)
let $path-to-xslt := concat(
	$paths:rest-prefix,
	'/db/code/input-conversion/rawtext/rawtext.xsl2'
	)
let $data := request:get-data()
let $text := string($data/text)
let $bibl-name := string($data/bibliography)
let $index-name := concat(string(($data/index-name,'index')[1]),'.xml')
let $facsimile-prefix := '/scans/'
let $facsimile-extension := '.jpg'
let $grammar-xslt :=
	<xsl:stylesheet 
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:xs="http://www.w3.org/2001/XMLSchema"
		version="2.0"
		exclude-result-prefixes="xs">
		<xsl:import href="{$path-to-grammar-xslt}"/>
  	
		<xsl:template match="/">
			<xsl:call-template name="main">
				<xsl:with-param name="text" as="xs:string"
					select="unparsed-text('{$upload-path}')"/>
			</xsl:call-template>
		</xsl:template>
		
	</xsl:stylesheet>	
let $xslt := 
	(: eXist's parameters function does not know about parameter types,
	: and makes them all strings.  This XSLT passes parameters with types :)
	<xsl:stylesheet 
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:xs="http://www.w3.org/2001/XMLSchema"
		version="2.0"
		exclude-result-prefixes="xs">
		<xsl:import href="{$path-to-xslt}"/>
		<xsl:param name="output-directory" as="xs:string" select="'{$user-collection}'"/>
		<xsl:param name="default-language" as="xs:string" select="'{$data/language}'"/>
		<xsl:param name="bibl-pointer" as="xs:string" select="'{$bibl-name}'"/>
		<xsl:param name="index-title" as="xs:string" select="'{$data/index-title}'"/>
		<xsl:param name="index-name" as="xs:string" select="'{$index-name}'"/>
		<xsl:param name="conditional-name" as="xs:string" select="'{$bibl-name}'"/>
		<xsl:param name="license-type" as="xs:string" select="'{$data/license}'"/>
		{if ($data/has-facsimile = 'true')
		then (
			<xsl:param name="facsimile-prefix" as="xs:string" 
				select="'{concat($facsimile-prefix, 
				if (ends-with($facsimile-prefix,'/')) then '' else '/',
				$data/facsimile)}'"/>,
			<xsl:param name="facsimile-extension" as="xs:string" select="'{$facsimile-extension}'"/>
		)
		else 
			<xsl:param name="facsimile-prefix" as="xs:string" select="''"/> 
		}
  	
		<xsl:template match="/">
			<xsl:apply-templates/>
		</xsl:template>
		
	</xsl:stylesheet>
let $stored :=
	(
	xmldb:store($user-collection, $resource-name, $text, 'text/plain')
	) 
let $grammar-transformed := 
	if ($stored)
	then
	(
		util:log-system-out(('Document stored.')) ,
		transform:transform(<main/>, $grammar-xslt, ())
	)
	else 
		error(xs:QName('err:STORAGE'), 'Cannot store the text.')
let $transformed :=
	if ($grammar-transformed/r:remainder)
	then 
		error(xs:QName('err:GRAMMAR'), 'Error in grammar parsing.')
	else (
		util:log-system-out('Grammar parsed successfully'),
		transform:transform($grammar-transformed, $xslt, ())
	)
return (
	if (exists($transformed))
	then 
		<contributors xmlns="">{(
			local:write-output-files($transformed), 
			local:unknown-contributors($transformed[@href=concat($user-collection,'/contributors.xml')])
		)}</contributors>
	else error(xs:QName('err:TRANSFORM'), 'Error transforming text.')
	)
