xquery version "1.0";
(:~ Metadata editing 
 :  Metadata includes resource name, all information on the title page, primary license
 : 
 : ?new=true
 : ?resource=resource-path
 : 
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :) 
import module namespace request="http://exist-db.org/xquery/request";
 
import module namespace app="http://jewishliturgy.org/modules/app" 
 	at "/code/modules/app.xqm";
import module namespace builder="http://jewishliturgy.org/apps/builder/controls" 
	at "/code/apps/builder/modules/builder.xqm";
import module namespace collab="http://jewishliturgy.org/modules/collab" 
 	at "/code/modules/collab.xqm"; 	
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
declare namespace xrx="http://jewishliturgy.org/xrx";

declare option exist:serialize "method=xhtml media-type=text/xml indent=yes omit-xml-declaration=no
	process-xsl-pi=no
	doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
	doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"; 

let $authenticated := app:authenticate()
let $resource := request:get-parameter('item', ())
let $new := 
	request:get-parameter('new', 
		if (exists($resource))
		then 'false'
		else 'true')
let $login-instance-id := 'login'
let $builder-instance-id := 'builder'
let $save-flag-instance-id := concat($builder-instance-id, '-save-flag')
let $error-instance-id := 'error'
let $language-selector-instance-id := 'language-selector'
let $license-chooser-id := 'license-chooser'
let $control-id := 'builder-control'
let $share-options-instance-id := 'share-options'
return
	site:form(
		<xf:model id="model">{
			login:login-instance($login-instance-id, 
				(site:sidebar-login-actions-id(), 'model')
			),
			controls:language-selector-instance($language-selector-instance-id),
			controls:license-chooser-instance($license-chooser-id, true()),
			builder:share-options-instance($share-options-instance-id),
			controls:save-flag-instance($save-flag-instance-id),
			<xf:instance id="metadata">
				<metadata xmlns="">
					<tei:title type="main" xml:lang="en"/>
					<tei:title type="sub" xml:lang="en"/>
					<tei:front>
						<tei:titlePage>
	        		<tei:docTitle>
	          		<tei:titlePart type="main" xml:lang="en"></tei:titlePart>
	          		<tei:titlePart type="sub" xml:lang="en"></tei:titlePart>
	        		</tei:docTitle>
	        		<tei:docAuthor></tei:docAuthor>
	        		<tei:docImprint>
	          		<tei:publisher>The Open Siddur Project</tei:publisher>          
	        		</tei:docImprint>
	        		<tei:docDate/>
	        		<!-- TODO: add front page graphic tei:graphic url=""/-->
	      		</tei:titlePage>
      		</tei:front>
      		<lang>en</lang>
				</metadata>
			</xf:instance>,
			<xf:bind id="lang"
				nodeset="instance('metadata')/lang"
				type="xf:string"/>,
			<xf:bind id="title"
				nodeset="instance('metadata')/tei:title"
				type="xf:string"
				required="true()"/>,
			<xf:bind id="title-lang"
				nodeset="instance('metadata')/tei:title/@xml:lang"
				type="xf:string"
				required="true()"/>,
			<xf:bind id="subtitle"
				nodeset="instance('metadata')/tei:title[@type='sub']"
				type="xf:string"/>,
			<xf:bind id="subtitle-lang"
				nodeset="instance('metadata')/tei:title[@type='sub']/@xml:lang"
				type="xf:string"/>,
			<xf:bind id="front"
				nodeset="instance('metadata')/tei:front"/>,
			<xf:bind id="author"
				nodeset="instance('metadata')//tei:docAuthor"
				type="xf:string"/>,
			<xf:bind id="publisher"
				nodeset="instance('metadata')//tei:publisher"
				type="xf:string"/>,
			<xf:bind id="date"
				nodeset="instance('metadata')//tei:docDate"
				type="xf:date"/>,
			<xf:bind  
				nodeset="instance('metadata')//tei:titlePart[@type='main']"
				calculate="instance('metadata')/tei:title[@type='main']"/>,
			<xf:bind 
				nodeset="instance('metadata')//tei:titlePart[@type='main']/@xml:lang"
				calculate="instance('metadata')/tei:title[@type='main']/@xml:lang"/>,
			<xf:bind  
				nodeset="instance('metadata')//tei:titlePart[@type='sub']"
				calculate="instance('metadata')/tei:title[@type='sub']"/>,
			<xf:bind 
				nodeset="instance('metadata')//tei:titlePart[@type='sub']/@xml:lang"
				calculate="instance('metadata')/tei:title[@type='sub']/@xml:lang"/>,
			builder:login-actions($builder-instance-id),
			controls:error-instance($error-instance-id),
			<xf:instance id="blank">
				<blank xmlns=""/>
			</xf:instance>,
			<xf:instance id="resource">
				<instance xmlns="">
					<item>{
						$resource
					}</item>
				</instance>
			</xf:instance>,
			<xf:submission id="new-submit" method="post" ref="instance('blank')"
				replace="none">
				<xf:resource value="concat('/code/api/data/original/group/', instance('{$share-options-instance-id}')/owner)"/>
				{
				controls:submission-response(
					$error-instance-id, (),
					(:success actions = submit all the individual parts :) 
					(
						<xf:setvalue ref="instance('resource')/item" 
							value="event('response-headers')/self::header[name='Location']/value" />,
						<xf:send>{
							attribute submission { controls:rt-submission-set("title") }
						}</xf:send>,
						<xf:send>{
							attribute submission { controls:rt-submission-set("subtitle") }
						}</xf:send>,
						<xf:send>{
							attribute submission { controls:rt-submission-set("front") }
						}</xf:send>,
						<xf:send>{
							attribute submission { controls:rt-submission-set("lang") }
						}</xf:send>,
						<xf:send>{
							attribute submission { controls:rt-submission-set("license") }
						}</xf:send>,
						controls:set-save-flag($save-flag-instance-id, true())
					)
				)
				}
			</xf:submission>,
			controls:rt-submission(
				attribute bind { "title" },	
				<xf:resource value="concat(instance('resource')/item, '/title.xml')"/>,
				<xf:resource value="concat(instance('resource')/item, '/title.xml?_method=PUT')"/>,
				attribute replace { 'instance' },
				attribute targetref { "instance('metadata')/tei:title[@type='main']" }, 
				$error-instance-id,
				attribute if { "instance('resource')/item != ''" }
			),
			controls:rt-submission(
				attribute bind { "subtitle" },	
				<xf:resource value="concat(instance('resource')/item, '/subtitle.xml')"/>,
				<xf:resource value="concat(instance('resource')/item, '/subtitle.xml?_method=PUT')"/>,
				attribute replace { 'instance' },
				attribute targetref { "instance('metadata')/tei:title[@type='sub']" }, 
				$error-instance-id,
				attribute if { "instance('resource')/item != ''" }
			),
			controls:rt-submission(
				attribute bind { "front" },	
				<xf:resource value="concat(instance('resource')/item, '/front.xml')"/>,
				<xf:resource value="concat(instance('resource')/item, '/front.xml?_method=PUT')"/>,
				attribute replace { 'instance' },
				attribute targetref { "instance('metadata')/tei:front" }, 
				$error-instance-id,
				attribute if { "instance('resource')/item != ''" }
			),
			controls:rt-submission(
				attribute bind { "lang" },	
				<xf:resource value="concat(instance('resource')/item, '/lang.xml')"/>,
				<xf:resource value="concat(instance('resource')/item, '/lang.xml?_method=PUT')"/>,
				attribute replace { 'text' },
				attribute targetref { "instance('metadata')/lang" }, 
				$error-instance-id,
				attribute if { "instance('resource')/item != ''" }
			),
			controls:rt-submission(
				attribute ref { controls:instance-to-ref($license-chooser-id) },	
				<xf:resource value="concat(instance('resource'), '/license.xml')"/>,
				<xf:resource value="concat(instance('resource'), '/license.xml?_method=PUT')"/>,
				attribute replace { 'instance' },
				attribute targetref { controls:instance-to-ref($license-chooser-id) }, 
				$error-instance-id,
				attribute if { "instance('resource')/item != ''" }
			)
		}</xf:model>,
		<title>Open Siddur Builder</title>,
		<fieldset>
			<div class="block-form">
				<xf:group id="{$control-id}">
					{
					controls:error-report($error-instance-id),
					controls:language-selector-ui(
						concat($control-id, '-lang-input'),
						$language-selector-instance-id,
						'Primary document language',
						"lang",
						true()
					),
					controls:rt-control(
						concat($control-id, '-lang-input'),
						controls:rt-submission-id('lang'),
						controls:set-save-flag($save-flag-instance-id, true()),
						controls:unsave-save-flag($save-flag-instance-id, concat($control-id, '-lang-input')),
						"instance('resource')/item != ''"
					),
					controls:string-input-with-language-ui(
						concat($control-id,'-title-input'),
						$language-selector-instance-id,
						'Title', (),
						'title',
						'title-lang'),
					controls:rt-control(
						concat($control-id, '-title-input'),
						controls:rt-submission-id('title'),
						controls:set-save-flag($save-flag-instance-id, true()),
						controls:unsave-save-flag($save-flag-instance-id, concat($control-id, '-title-input')),
						"instance('resource')/item != ''"
					),
					controls:string-input-with-language-ui(
						concat($control-id,'-subtitle-input'),
						$language-selector-instance-id,
						'Subtitle', (),
						'subtitle',
						'subtitle-lang'),
					controls:rt-control(
						concat($control-id, '-subtitle-input'),
						controls:rt-submission-id('subtitle'),
						controls:set-save-flag($save-flag-instance-id, true()),
						controls:unsave-save-flag($save-flag-instance-id, concat($control-id, '-subtitle-input')),
						"instance('resource')/item != ''"
					)
					}
					<xf:input id="{$control-id}-author" bind="author">
						<xf:label>Byline</xf:label>
						<xf:hint>Optional byline for the siddur, which is not necessarily your name.</xf:hint>
					</xf:input>
					{
					controls:rt-control(
						concat($control-id, '-author'),
						controls:rt-submission-id('front'),
						controls:set-save-flag($save-flag-instance-id, true()),
						controls:unsave-save-flag($save-flag-instance-id, concat($control-id, '-author')),
						"instance('resource')/item != ''"
					)
					}
					<xf:group id="{$control-id}-sharing-options" appearance="minimal">
						<xf:label>Sharing options</xf:label>
						{
						controls:license-chooser-ui(
							concat($control-id, '-license-chooser'),
							$license-chooser-id,
							concat(
							"Choose a license that will apply to the data in your siddur.  Note ",
							"that your choice only affects the the licensing of the data you contribute, ",
							"not what you use from other sources."),
							'radio', 
							concat($control-id, '-sharing-options'), 
              true()
						),
						controls:rt-control(
							(:concat($control-id, '-license-chooser'):)(),
							controls:rt-submission-id(controls:instance-to-ref($license-chooser-id)), controls:set-save-flag($save-flag-instance-id, true()),
							(),
							"instance('resource')/item != ''"
						),
						builder:share-options-ui(
							$share-options-instance-id,
							concat($control-id, '-share-options'),
							'Share with: '
							),
						<xf:action ev:event="DOMFocusOut" ev:observer="{concat($control-id, '-share-options')}">
							<xf:message>Changing share options not yet implemented.</xf:message>
						</xf:action>
						}
					</xf:group>
					{
					if ($new)
					then
						<xf:trigger ref="instance('resource')/item[.='']">
							<xf:label>Start new siddur</xf:label>
							<xf:action ev:event="DOMActivate" if="instance('metadata')/tei:title[@type='main'] != ''">
								<xf:send submission="new-submit"/>
								<xf:toggle case="has-save-button"/>
								{controls:set-save-flag($save-flag-instance-id, true())}
							</xf:action>
							<xf:action ev:event="DOMActivate" if="instance('metadata')/tei:title[@type='main'] = ''">
								<xf:message>Not all required fields are filled in</xf:message>
							</xf:action>
						</xf:trigger>
					else ()
					}
				</xf:group>
				{controls:debug-show-instance('metadata'),
				controls:debug-show-instance($save-flag-instance-id),
				controls:debug-show-instance($license-chooser-id)}
			</div>
		</fieldset>,
		(site:css(), builder:css()),
		site:header(),
		(site:sidebar-with-login($login-instance-id),
		builder:sidebar()),
		site:footer(),
		builder:app-header($builder-instance-id, 'app-header', 
			<xf:switch>
				<xf:case id="has-save-button">
				{
					controls:save-status-ui(
						$save-flag-instance-id,
						concat($control-id, '-status'),
						( (: DOMFocusout will result in the save, so, no additional action is necessary :) )
					)
				}
				</xf:case>
				<xf:case id="no-save-button" selected="{string($new)}">
					<span>Unsaved</span>
				</xf:case>
			</xf:switch>,
			'resource'
		)
	)
