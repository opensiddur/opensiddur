xquery version "1.0";
(: wiki-import.xql
 : Wiki import GUI
 : accepts one parameter: ?step=n to specify where to start
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: wiki-import.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
import module namespace app="http://jewishliturgy.org/ns/functions/app";
import module namespace paths="http://jewishliturgy.org/apps/lib/paths"
	at "../lib/paths.xqm";
import module namespace bibgui="http://jewishliturgy.org/apps/upload/bibgui" 
	at "bibgui.xqm";
import module namespace catgui="http://jewishliturgy.org/apps/upload/catgui"
	at "categorize-gui.xqm";
import module namespace corrgui="http://jewishliturgy.org/apps/upload/corrgui" 
	at "correction-gui.xqm";
import module namespace contribgui="http://jewishliturgy.org/apps/upload/contribgui" 
	at "contrib-gui.xqm";	
import module namespace controls="http://jewishliturgy.org/apps/lib/controls"
	at "../lib/controls.xqm";
import module namespace licensegui="http://jewishliturgy.org/apps/upload/licensegui"
	at "license-gui.xqm";
import module namespace login="http://jewishliturgy.org/apps/lib/login" 
	at "../lib/login.xqm";
import module namespace namegui="http://jewishliturgy.org/apps/upload/namegui" 
	at "name-gui.xqm";
import module namespace scangui="http://jewishliturgy.org/apps/upload/scangui" 
	at "scangui.xqm";
import module namespace wiki="http://jewishliturgy.org/apps/lib/wiki" 
	at "../lib/wiki.xqm";
import module namespace wikigui="http://jewishliturgy.org/apps/upload/wikigui" 
	at "wikigui.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";

let $default-start := if (app:auth-user()) then '1' else '0'
let $start-step := 
	if (request:exists()) 
	then 
		let $asked-for := request:get-parameter('step', $default-start)
		return
			if ($asked-for castable as xs:integer and 
			xs:integer($asked-for) >= 1 and xs:integer($asked-for) <= 8)
			then $asked-for
			else $default-start
	else $default-start
let $form :=
	<html xmlns="http://www.w3.org/1999/xhtml">
		<head>
			<title>Wiki import</title>
			<xf:model id="import">
				{
				wikigui:imports-instance('imports'),
				corrgui:correction-instance('corrections',
          let $user := app:auth-user()
          let $upload-txt := 
            if ($user) 
            then concat(xmldb:get-user-home($user), '/upload.txt')
            else ()
          return
            if ($start-step='7' and $upload-txt and util:binary-doc-available($upload-txt) )
            then util:binary-to-string(util:binary-doc($upload-txt))
            else 'Initial text'
          ),
        scangui:scan-instance('corrections'),
				bibgui:bib-instance('corrections'),
				namegui:name-instance('corrections'),
				licensegui:license-instance('corrections'),
				contribgui:contrib-instance('contributors'),
				catgui:cat-instance('categorize')
				}
				<xf:instance id="blank" xmlns="">
          <null/>
        </xf:instance>
        <xf:submission id="submit-import" 
          action="do-wiki-import.xql" method="post" 
          ref="instance('imports')" 
          replace="instance"
          instance="corrections">
          <xf:action ev:event="xforms-submit-done">
            <xf:toggle case="step2"/>
          </xf:action>
          <xf:action ev:event="xforms-submit-error">
            {controls:submit-error-handler-action()}
          </xf:action>
        </xf:submission>
        
        <xf:submission id="submit-corrections"
          method="post"
          action="do-convert-to-xml.xql"
          ref="instance('corrections')"
          replace="instance"
          instance="contributors"
          >
          <xf:action ev:event="xforms-submit-done">
            <xf:toggle case="step8"/>
          </xf:action>
          <xf:action ev:event="xforms-submit-error">
            {controls:submit-error-handler-action()}
          </xf:action>
        </xf:submission>
        
        <xf:submission id="submit-contributors"
          method="post"
          ref="instance('contributors')"
          action="do-submit-contributors.xql"
          instance="categorize"
          replace="instance"
          >
          <xf:action ev:event="xforms-submit-done">
            <xf:toggle case="step9"/>
          </xf:action>
          <xf:action ev:event="xforms-submit-error">
            {controls:submit-error-handler-action()}
          </xf:action>
        </xf:submission>
        
        <xf:submission id="submit-categorize"
          method="post"
          ref="instance('categorize')"
          action="do-upload.xql"
          instance="categorize"
          replace="instance"
          >
          <xf:action ev:event="xforms-submit-done">
            <xf:toggle case="step10"/>
          </xf:action>
          <xf:action ev:event="xforms-submit-error">
            {controls:submit-error-handler-action()}
          </xf:action>
        </xf:submission>
        
				<xf:action ev:event="xforms-ready">
					<xf:toggle case="step{$start-step}"/>
				</xf:action>
				{login:form-instance('login')}
			</xf:model>
			
			
			<style><![CDATA[
			.textarea textarea {
   			font-family: Courier, sans-serif;
   			height: 40em;
   			width: 90%;
			}
			]]></style>
		</head>
		<body>
			<h1>Wiki import</h1>
			<p>This form provides a GUI for converting transcriptions from the wiki 
			to XML in the database.  It is a five step process</p>
			{login:form-ui('login')}
			
			<xf:switch>
				<xf:case id="step0">
					<p>You must be logged in to import.  After you log in successfully, press Next.</p>
					<xf:trigger ref="instance('login')/loggedin[string-length(.) &gt; 0]">
						<xf:label>Next &gt;&gt;</xf:label>
						<xf:action ev:event="DOMActivate">
							<xf:toggle case="step1"/>
						</xf:action>
					</xf:trigger>
				</xf:case>
        <xf:case id="step1">
          <h2>Step 1: Import from wiki</h2>
          <!-- step 1: specify what to import -->
          <p>At this step, you specify what text you want to import from the wiki.
          There are two types of imports:
          <ol>
            <li>Import a single page</li>
            <li>Import a group of pages that are stored on the wiki in a numbered sequence.</li>
          </ol>
          </p>
          <p>
          Choose which type of import you intend to use, and enter all of the information below.
          </p>
          <p>
          If the page you want to import points to a redirect on the wiki, enter the destination of the redirect.  The importer will not
          follow a redirect automatically.
          </p>
          <p>  
          For imports of numbered sequences, an example URL is shown just below the data entry boxes and 
          is updated as you type.  This URL should match the URL of the first page on the wiki that you intend to import.
          </p>
          
          <p>If the imported section is composed of either more than one numbered sequence or more
          than one page, you may insert additional pages by pressing the + button.  
          Additional pages may be deleted by pressing -, and their order changed using the 
          &#9650; and &#9660; buttons.</p>
          
          {wikigui:imports-gui('imports','control-imports')}
          <p>The next step loads the data from the wiki.  It may take some time.</p>
          <xf:submit submission="submit-import">
            <xf:label>Next &gt;&gt;</xf:label>
          </xf:submit>
        </xf:case>
        <xf:case id="step2">
          <h2>Step 2: Bibliographic source selection</h2>
          {bibgui:bib-ui('corrections','control-bibliography-ui')}
          <xf:trigger>
            <xf:label>&lt;&lt; Prev</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="step1"/>
            </xf:action>
          </xf:trigger>
          <xf:trigger ref="instance('corrections')/bibliography">
            <xf:label>Next &gt;&gt;</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="step3"/>
            </xf:action>
          </xf:trigger>
        </xf:case>
        <xf:case id="step3">
          <!-- step 3: scan source selection -->
          <h2>Step 3: Scan source selection</h2>
          {scangui:scan-ui('corrections','control-scan-selection','step4')}

          <xf:trigger>
            <xf:label>&lt;&lt; Prev</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="step2"/>
            </xf:action>
          </xf:trigger>
          <xf:trigger ref="instance('corrections')/facsimile[. != '']">
          	<!--  -->
            <xf:label>Next &gt;&gt;</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="step4"/>
            </xf:action>
          </xf:trigger>
        </xf:case>
        <xf:case id="step4">
          <h2>Step 4: Index name and title</h2>
          {namegui:name-ui('corrections','control-name')}

          <xf:trigger>
            <xf:label>&lt;&lt; Prev</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="step3"/>
            </xf:action>
          </xf:trigger>
          <xf:trigger>
            <xf:label>Next &gt;&gt;</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="step5"/>
            </xf:action>
          </xf:trigger>         
        </xf:case>
        <xf:case id="step5">
          <h2>Step 5: Text language</h2>
          <h2>Language selection</h2>
          <p>Select the text's primary language.</p>
          {controls:language-selector-ui(
            'control-corrections-language', 
            "Primary text language: ",
            "instance('corrections')/language")}
          <br/>
          <xf:trigger>
            <xf:label>&lt;&lt; Prev</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="step4"/>
            </xf:action>
          </xf:trigger>
          <xf:trigger>
            <xf:label>Next &gt;&gt;</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="step6"/>
            </xf:action>
          </xf:trigger>
        </xf:case>
        <xf:case id="step6">
          <h2>Step 6: License selection</h2>
          {licensegui:license-ui('corrections','control-license')}

          <xf:trigger>
            <xf:label>&lt;&lt; Prev</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="step5"/>
            </xf:action>
          </xf:trigger>
          <xf:trigger ref="instance('corrections')/license[. != '']">
            <xf:label>Next &gt;&gt;</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="step7"/>
            </xf:action>
          </xf:trigger>
        </xf:case>
        <xf:case id="step7">
          <h2>Step 7: Split files and correct text</h2>
          {corrgui:correction-ui('corrections','control-corrections')}

          <p>The next step converts the STML to JLPTEI XML.  This may take some time.</p>
          <xf:trigger>
            <xf:label>&lt;&lt; Prev</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="step6"/>
            </xf:action>
          </xf:trigger>
          <xf:submit submission="submit-corrections">
            <xf:label>Next &gt;&gt;</xf:label>
          </xf:submit>
        </xf:case>
				<xf:case id="step8">
          <h2>Step 7: Verify files and update the contributors list</h2>
          {contribgui:contrib-gui('contributors', 'control-contributors')}
          
          <xf:trigger>
            <xf:label>&lt;&lt; Prev</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="step7"/>
            </xf:action>
          </xf:trigger>
          <xf:submit submission="submit-contributors">
            <xf:label>Next &gt;&gt;</xf:label>
          </xf:submit>
        </xf:case>
				<xf:case id="step9">
          <h2>Step 9: Categorize the transcription</h2>
          
          {catgui:cat-gui('categorize','control-categorize')}
          <xf:trigger>
            <xf:label>&lt;&lt; Prev</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="step8"/>
            </xf:action>
          </xf:trigger>
          <xf:submit submission="submit-categorize">
            <xf:label>Next &gt;&gt;</xf:label>
          </xf:submit>
        </xf:case>
        <xf:case id="step10">
          <h2>Import complete</h2>
          
          <p>Thank you for importing data into the Open Siddur!</p>
          <xf:trigger>
            <xf:label>Import again</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="step1"/>
            </xf:action>
          </xf:trigger>
        </xf:case>				
			</xf:switch>
		</body>
	</html>
return
	($paths:xslt-pi, $paths:debug-pi, $form) 