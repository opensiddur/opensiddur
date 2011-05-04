xquery version "1.0";
(: Demo of string-with-language widget :)

import module namespace site="http://jewishliturgy.org/modules/site" 
	at "/code/modules/site.xqm";
import module namespace controls="http://jewishliturgy.org/modules/controls" 
	at "/code/modules/controls.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare option exist:serialize "method=xhtml media-type=text/xml indent=yes omit-xml-declaration=no
	process-xsl-pi=no
	doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
	doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"; 


site:form(
	<xf:model>
		<xf:instance id="selection">
			<j:selection>
				<tei:ptr target="#1"/>
			</j:selection>
		</xf:instance>
		{controls:ordered-list-instance(
			'selection', <tei:ptr target=""/>
			)}
		<xf:submission ref="instance('selection')" id="submit" method="post" action="echo.xql" replace="all"/>
	</xf:model>,
  <title>ordered list widget demo</title>,
  (
  controls:ordered-list-ui(
  	'selection',
		'control',
		'Ordered list of ptrs',
		controls:instance-to-ref('selection','tei:ptr'), 
		<xf:input ref="@target">
			<xf:label>@target: </xf:label>
		</xf:input>,
		()),
  	<xf:submit submission="submit">
  		<xf:label>Submit</xf:label>
  	</xf:submit>
  ),
  site:css()
)
