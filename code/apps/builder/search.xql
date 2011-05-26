xquery version "1.0";
(:~ Search UI
 : 
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :) 
import module namespace request="http://exist-db.org/xquery/request";
 
import module namespace app="http://jewishliturgy.org/modules/app" 
 	at "/code/modules/app.xqm";
import module namespace builder="http://jewishliturgy.org/apps/builder/controls" 
 	at "/code/apps/builder/modules/builder.xqm";
import module namespace controls="http://jewishliturgy.org/modules/controls" 
 	at "/code/modules/controls.xqm"; 	
import module namespace site="http://jewishliturgy.org/modules/site" 
 	at "/code/modules/site.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths" 
 	at "/code/modules/paths.xqm";
import module namespace login="http://jewishliturgy.org/apps/user/login" 
	at "/code/apps/user/modules/login.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace ev="http://www.w3.org/2001/xml-events";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xf="http://www.w3.org/2002/xforms";

declare option exist:serialize "method=xhtml media-type=text/xml indent=yes omit-xml-declaration=no
	process-xsl-pi=no
	doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
	doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"; 



let $login-instance-id := 'login'
let $error-instance-id := 'error'
let $result-instance-id := 'result'
let $result-control-id := 'control-results'
return
site:form(
	<xf:model>{
		login:login-instance($login-instance-id, 
			(
			site:sidebar-login-actions-id(),
			builder:sidebar-login-actions-id()
			)),
    controls:error-instance($error-instance-id),
    <xf:instance id="garbage">
      <html tei:junk="1" html:junk="1"/>
    </xf:instance>,
    builder:document-chooser-instance($result-instance-id, true(), 'everyone', ())
		}
		
	</xf:model>,
	<title>Full text search</title>,
	(
    builder:document-chooser-ui($result-instance-id, $result-control-id, 
      <xf:trigger appearance="minimal">
        <xf:label>Edit</xf:label>
        <xf:load ev:event="DOMActivate">
          <xf:resource value="concat('{$builder:app-location}/edit-metadata.xql?item=', ./html:a/@href)"/>
        </xf:load>
      </xf:trigger>, true(), true(), 'Result',
      <xf:repeat id="search-result" nodeset="./html:a/html:p">
        {builder:search-results-block()}
      </xf:repeat>)
  ),
 	(site:css(), builder:css(), controls:faketable-style($result-control-id, 90, 3)),
 	site:header(),
 	(site:sidebar-with-login($login-instance-id),
 	builder:sidebar()),
 	site:footer()
)
