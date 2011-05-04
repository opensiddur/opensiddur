xquery version "1.0";
(: Demo of license selection widget :)

import module namespace site="http://jewishliturgy.org/modules/site" 
	at "/code/modules/site.xqm";
import module namespace controls="http://jewishliturgy.org/modules/controls" 
	at "/code/modules/controls.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare option exist:serialize "method=xhtml media-type=text/xml indent=yes omit-xml-declaration=no
	process-xsl-pi=no
	doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
	doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"; 


site:form(
	<xf:model>
		<xf:instance id="result">
			<result xmlns="">
				<tei:availability>unset</tei:availability>
			</result>
		</xf:instance>
		{
		controls:license-chooser-instance('chooser', true())
		}
		<xf:submission ref="instance('result')" id="submit" method="post" action="echo.xql" replace="all"/>
	</xf:model>,
  <title>License selection widget demo</title>,
  (
  controls:license-chooser-ui('control-chooser',
  	'chooser', 'Select one', controls:instance-to-ref('result'),
  	false(), 'radio'),
  <xf:submit submission="submit">
  	<xf:label>Submit</xf:label>
  </xf:submit>
  )
)
