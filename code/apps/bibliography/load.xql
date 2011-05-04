xquery version "1.0";
(: Bibliography loader
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace xrx="http://jewishliturgy.org/ns/xrx";
declare option exist:serialize "method=xml media-type=text/xml indent=yes process-pi-xsl=no";

import module namespace paths="http://jewishliturgy.org/apps/lib/paths"
	at "../lib/paths.xqm";

(: :)
let $bibliography-file := '/group/everyone/bibliography/bibliography.xml'
let $prototype := 
	<tei:biblStruct xml:id="">
		<tei:monogr>
    	<tei:author/>
	    <tei:editor/>
	    <xrx:titles>
  	  	<tei:title xml:id="" corresp="" xml:lang="" type="main"/>
    		<tei:title xml:id="" corresp="" xml:lang="" type="subtitle"/>
    	</xrx:titles>
    	<tei:edition/>
    	<tei:idno type="url"/>
    	<tei:imprint>
      	<tei:publisher/>
      	<tei:pubPlace/>
      	<tei:date/>
 	  		<tei:distributor>
  	  		<tei:ref type="url" target=""/>
      		<tei:date type="access"/>
      	</tei:distributor>
    	</tei:imprint>
	  </tei:monogr>
  	<tei:note type="copyright"/>
  	<tei:note/>
	</tei:biblStruct>
let $incoming-transform :=
	<xsl:stylesheet version="2.0" 
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:tei="http://www.tei-c.org/ns/1.0"
		xmlns:xs="http://www.w3.org/2001/XMLSchema"
		xmlns:xrx="http://jewishliturgy.org/ns/xrx"
		xmlns:local="local-function"
		exclude-result-prefixes="xs"
		extension-element-prefixes="local">		
		<xsl:output encoding="utf-8" indent="yes" method="xml"/>
    <xsl:strip-space elements="*"/>
   	
   	<!--xsl:include href="http://{request:get-server-name()}:{request:get-server-port()}/code/apps/lib/prototype.xsl2"/-->
   	<!-- xsl:include is all fsck-ed up in eXist.  Using kluge code below: -->
   	{
   	let $prototype-xsl := concat($paths:rest-prefix, $paths:apps, '/lib/prototype.xsl2')
   	return
	   	if (doc-available($prototype-xsl))
	   	then doc($prototype-xsl)/xsl:stylesheet/node()
	   	else error(xs:QName('xrx:WTF'),'Prototype doesnt exist')
	  }
   	 
    <xsl:param name="prototype" as="element(tei:biblStruct)">
    	{$prototype}
    </xsl:param>
    
       
    <!-- marshall data from expanded names to a string -->
    <xsl:template match="tei:author|tei:editor" priority="10">
			<xsl:param name="data" as="element()?"/>    	
			
			<xsl:next-match>
				<xsl:with-param name="data"	as="element()">
					<xsl:copy>
						<xsl:copy-of select="@*"/>
						<xsl:sequence select="
							(string-join($data/
								(tei:roleName|
								tei:forename|
								tei:nameLink|
								tei:surname|
								tei:genName), ' '), 
							$data/text())"/>
					</xsl:copy>
				</xsl:with-param>
    	</xsl:next-match>
    </xsl:template>
   
    
    <xsl:template match="tei:title[@type='main']" mode="xrx-titles" priority="10">
    	<xrx:titles>
    		<xsl:apply-templates 
    			select="(.,following-sibling::*[1][self::tei:title][@type='subtitle'])"
    			mode="xrx-titles-2"/>
    	</xrx:titles>
    </xsl:template>
    
    <xsl:template match="tei:title[@type='subtitle']" mode="xrx-titles" priority="10"/>
    
    <xsl:template match="*" mode="xrx-titles xrx-titles-2">
    	<xsl:copy>
    		<xsl:copy-of select="@*"/>
    		<xsl:apply-templates mode="#current"/>
    	</xsl:copy>
    </xsl:template>
    
    <xsl:template match="tei:listBibl">
    	<xsl:for-each select="tei:biblStruct">
    		<xsl:message>biblStruct</xsl:message>
    		<xsl:apply-templates select="$prototype">
    			<xsl:with-param name="data" as="element()">
    				<xsl:apply-templates select="." mode="xrx-titles"/>
    			</xsl:with-param>
    		</xsl:apply-templates>
    	</xsl:for-each>
    </xsl:template>

 	</xsl:stylesheet>
return
	<tei:listBibl>{
		(
		if (doc-available($bibliography-file))
		then
			let $result :=
			transform:transform(
				doc($bibliography-file)//tei:div[@type='bibliography']/tei:listBibl, $incoming-transform, ())
			return ($result, 
			util:log-system-out(('transform in:', $incoming-transform, 'using:', doc($bibliography-file)//tei:div[@type='bibliography']/tei:listBibl, 'transform result: ', $result)))
		else 
			util:log-system-out('Loading unavailable bibliography file') (: not available :)
		)
	}</tei:listBibl>
		
