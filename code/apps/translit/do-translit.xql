xquery version "1.0";
(: do-translit.xql
 : Run the transliteration engine for the XForms front-end
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: do-translit.xql 775 2011-05-01 06:46:55Z efraim.feinstein $
 :)
declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";
declare namespace xsl="http://www.w3.org/1999/XSL/Transform";

import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/code/modules/paths.xqm";

let $path-to-transliterator := '/code/transforms/stage1/translit.xsl2'
let $path-to-tables := '/group/everyone/transliteration'
let $data := request:get-data()
let $table := $data/table
let $text := $data/text 
let $transliteration-table-path :=	concat($path-to-tables, '/', $table, '.tr.xml')
let $transliteration-table as element(tr:table) :=
	if (doc-available($transliteration-table-path))
	then 
		doc($transliteration-table-path)/tr:table
	else 
		error(xs:QName('err:LOADING_TABLE'), 
			concat('Cannot load transliteration table from ', $transliteration-table-path))
let $xslt := 
	<xsl:stylesheet 
		version="2.0"
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:tr="http://jewishliturgy.org/ns/tr/1.0"
		xmlns:xs="http://www.w3.org/2001/XMLSchema">
		<xsl:import href="{$paths:rest-prefix}/code/common/common.xsl2"/>
		<xsl:include href="{$paths:rest-prefix}{$path-to-transliterator}"/>
		
		<xsl:template match="/">
			<xsl:apply-templates select="." mode="standalone">
				<xsl:with-param name="transliteration-table" as="element(tr:table)"
					tunnel="yes">{
					$transliteration-table
				}</xsl:with-param>
			</xsl:apply-templates>
		</xsl:template>
	</xsl:stylesheet>
return
	<transliteration-result xmlns="">{
		transform:transform($text, $xslt, ())
	}</transliteration-result>
