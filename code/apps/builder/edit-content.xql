xquery version "1.0";
(:~ Content editing 
 : Editing of selection
 : Assumes you're authenticated (if not, the controller should push the user back to the auth page)
 : 
 : Parameters:
 :	item=<path to resource> (required)
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
import module namespace controls="http://jewishliturgy.org/modules/controls" 
 	at "/code/modules/controls.xqm"; 	
import module namespace collab="http://jewishliturgy.org/modules/collab" 
 	at "/code/modules/collab.xqm"; 	
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
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace xrx="http://jewishliturgy.org/xrx";

declare option exist:serialize "method=xhtml media-type=text/xml indent=yes omit-xml-declaration=no
	process-xsl-pi=no
	doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
	doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"; 

let $authenticated := app:authenticate()
let $login-instance-id := 'login'
let $builder-instance-id := 'selection'
let $submit-ref := "instance('selection')"
let $error-instance-id := 'error'
let $save-flag-instance-id := 'save-flag'
let $document-chooser-id := 'document-chooser'
let $control-id := 'builder-control'
let $resource := request:get-parameter('item', ())
return
	site:form(
		<xf:model id="model">{
			login:login-instance($login-instance-id, 
				(site:sidebar-login-actions-id(), 'model')
			),
			controls:error-instance($error-instance-id),
			controls:save-flag-instance($save-flag-instance-id),
			builder:login-actions($builder-instance-id),
			<xf:instance id="blank">	
				<blank xmlns=""/>
			</xf:instance>,
			(: get around Firefox bugs :)
			<xf:instance id="garbage">
				<junk tei:junk="1" j:junk="2" html:junk="3" />
			</xf:instance>,
			(: resource that's being edited :)
			<xf:instance id="resource">
				<instance xmlns="">
					<item>{
						$resource
					}</item>
				</instance>
			</xf:instance>,
			(: selection of resource that's being edited :)
			<xf:instance id="selection">
				<html:html/>
			</xf:instance>,
			(: placeholder :)
			<xf:instance id="placeholder">
				<span class="placeholder">The next insert will be here</span>
			</xf:instance>,			
			(: document chooser :)
			builder:document-chooser-instance($document-chooser-id, true(), 'everyone', 'resource'),
			(: initial load :)
			<xf:submission id="selection-submit-get"
				ref="instance('blank')"
				method="get"
				replace="instance"
				instance="selection"
				>
				<xf:resource value="concat(instance('resource')/item, '/selection')"/>
				{
				controls:submission-response($error-instance-id, (),
					(
					<xf:dispatch name="load-all" targetid="model"/>
					)
				)
			}</xf:submission>,
			(: title load: supports 2 modes:
			 : (1) dispatch load-all to model so all the titles can be reloaded
			 : (2) set title-index/index to the item whose title should be loaded, dispatch load-one 
			 :)
			<xf:instance id="title-index">
				<instance xmlns="">
					<index/>
				</instance>
			</xf:instance>,
			<xf:bind nodeset="instance('title-index')/index" type="xf:integer"/>,
			<xf:instance id="current-title">
				<current xmlns="">
					<item/>
				</current>
			</xf:instance>,
			<xf:instance id="current-title-result">
				<result xmlns=""/>
			</xf:instance>,
			<xf:action ev:event="load-all">
				{ ( (: entry point for loading all titles in a loop :) )}
				<xf:setvalue ref="instance('title-index')/index" value="1"/>
				<xf:dispatch name="load-title-event" targetid="model"/>
			</xf:action>,
			<xf:action ev:event="load-one">
				{ ( (: load the title of title-index/index :) )}
				<xf:setvalue ref="instance('current-title')/item" 
					value="substring-before(instance('selection')//html:ul[@class='results']/html:li[number(instance('title-index')/index)]/html:a[not(@class)]/@href, '/id')"/>
				<xf:send submission="selection-title-get"/>
			</xf:action>,
			<xf:action ev:event="load-title-event" 
				while="instance('title-index')/index &lt;= count(instance('selection')//html:ul[@class='results']/html:li)">
				{ ( (: load all titles in a loop :) )}
				<xf:dispatch name="load-one" targetid="model"/>
				<xf:setvalue ref="instance('title-index')/index" value=". + 1" />
			</xf:action>,
			<xf:submission id="selection-title-get"
				ref="instance('blank')"
				method="get"
				replace="instance"
				instance="current-title-result"
				>
				<xf:resource value="concat(instance('current-title')/item, '/title.xml')"/>
				{
				controls:submission-response($error-instance-id, (), (
					<xf:insert origin="instance('current-title-result')"
						nodeset="instance('selection')//html:ul[@class='results']/html:li[number(instance('title-index')/index)]/*"
						at="last()"
						position="after"/>
				))
			}</xf:submission>,
			(: selection submit to get one item :)
			<xf:instance id="selection-get-position">
				<instance xmlns="">
					<position/>
				</instance>
			</xf:instance>,
			<xf:instance id="selection-get-result">
				<result xmlns=""/>
			</xf:instance>,
			<xf:submission id="selection-submit-get-one"
				ref="instance('blank')"
				method="get"
				replace="instance"
				instance="selection-get-result">
				<xf:resource value="concat(instance('resource')/item, '/selection/', instance('selection-get-position')/position)"/>
				{
					controls:submission-response($error-instance-id, (), ())
				}
			</xf:submission>,
			(: selection post position holds the position where the next item should be added 
			 : or empty if top
			 :)
			<xf:instance id="selection-post-position">
				<instance xmlns="">
					<position/>
				</instance>
			</xf:instance>,
			<xf:instance id="selection-post-content">
				<tei:ptr target="">{attribute xml:id {''}}</tei:ptr>
			</xf:instance>,
			(: selection item post holds the item that should be inserted :)
			<xf:submission id="selection-item-post"
				ref="instance('selection-post-content')"
				method="post"
				replace="none">
				<xf:resource value="concat(instance('resource')/item, '/selection', choose(instance('selection-post-position')/position = '', '', concat('/', instance('selection-post-position')/position)), '.xml')"/>
				{
				controls:submission-response($error-instance-id, (), (
				 	(: read the new item and insert it :) 
				 	<xf:setvalue 
				 		ref="instance('selection-get-position')/position" 
				 		value="substring-after(event('response-headers')/self::header[name='Location']/value, '/selection/')"/>,
				 	<xf:send submission="selection-submit-get-one"/>,
				 	(: if post was to the beginning of the selection... :)
				 	<xf:insert if="instance('selection-post-position')/position = ''"
				 		origin="instance('selection-get-result')//html:ul[@class='results']/html:li"
				 		context="instance('selection')//html:ul[@class='results']"
				 		nodeset="html:li"
				 		at="1"
				 		position="before"
				 		/>,
				 	<xf:setvalue if="instance('selection-post-position')/position = ''" ref="instance('title-index')/index" value="1"/>,
				 	(: if post was to somewhere inside the selection... :)
				 	<xf:insert if="instance('selection-post-position')/position != ''"
				 		origin="instance('selection-get-result')//html:ul[@class='results']/html:li"
				 		nodeset="instance('selection')//html:ul[@class='results']/html:li"
				 		at="count(instance('selection')//html:ul[@class='results']/html:li[html:a = instance('selection-post-position')/position]/preceding-sibling::html:li) + 1"
				 		position="after"
				 		/>,
				 	(: the new one's index does not appear, so I'm using the old index + 2 :)
				 	<xf:setvalue if="instance('selection-post-position')/position != ''" ref="instance('title-index')/index" value="count(instance('selection')//html:ul[@class='results']/html:li[html:a = instance('selection-post-position')/position]/preceding-sibling::html:li) + 2"/>,
					<xf:dispatch name="load-one" targetid="model"/>,
					controls:set-save-flag($save-flag-instance-id, true())
				 	)
				)
				}
			</xf:submission>,
			(: deletion item is the id of the selection item up for deletion :)
			<xf:instance id="deletion">
				<instance xmlns="">
					<item/>
				</instance>
			</xf:instance>,
			<xf:submission id="selection-item-delete"
				ref="instance('blank')"
				method="post"
				replace="none"
				>
				<xf:resource value="concat(instance('resource')/item, '/selection/', instance('deletion')/item, '?_method=DELETE')"/>{
				controls:submission-response($error-instance-id, (), 
					controls:set-save-flag($save-flag-instance-id, true()))
				}
			</xf:submission>,
			<xf:action ev:event="xforms-ready">
				<xf:send submission="selection-submit-get"/>
			</xf:action>
		}</xf:model>,
		<title>Open Siddur Builder</title>,
		<fieldset>
			<div class="block-form">
				<xf:group id="{$control-id}">
					{
					controls:error-report($error-instance-id),
					controls:ordered-list-ui(
						$builder-instance-id,
						concat($control-id, '-list'),
						'',
						controls:instance-to-ref($builder-instance-id, "//html:ul[@class='results']/html:li"),
						(
						<xf:output ref="./tei:title">
							<xf:label>Include from: </xf:label>
						</xf:output>,
						<xf:output ref="./html:span[@class='placeholder']"/>
						)
						,
						(), true(),
						concat($control-id,'-list-target')
					)
					}
					<xf:group id="{$control-id}-list-target">
						<xf:action ev:event="up">
							{controls:unsave-save-flag($save-flag-instance-id)}
							<xf:delete nodeset="instance('selection')//html:span[@class='placeholder']"/>
							<xf:setvalue ref="instance('selection-post-position')/position"
								value="instance('selection')//html:ul[@class='results']/html:li[index('{controls:ordered-list-repeat-id(concat($control-id, '-list'))}')]/preceding-sibling::html:li[2]/html:a[not(@class)]"/>
							<xf:setvalue ref="instance('selection-post-content')/self::tei:ptr/@xml:id"
								value="instance('selection')//html:ul[@class='results']/html:li[index('{controls:ordered-list-repeat-id(concat($control-id, '-list'))}')]/html:a[not(@class)]"/>
							<xf:setvalue ref="instance('selection-post-content')/self::tei:ptr/@target"
								value="instance('selection')//html:ul[@class='results']/html:li[index('{controls:ordered-list-repeat-id(concat($control-id, '-list'))}')]/html:a[@class='alt']/@href"/>
							<xf:send submission="selection-item-post"/>
				      <xf:delete nodeset="instance('selection')//html:ul[@class='results']/html:li[html:a[not(@class)] = instance('selection-post-content')/self::tei:ptr/@xml:id][2]"/>
						</xf:action>
						<xf:action ev:event="down">
							{controls:unsave-save-flag($save-flag-instance-id)}
							<xf:delete nodeset="instance('selection')//html:span[@class='placeholder']"/>
							<xf:setvalue ref="instance('selection-post-position')/position"
								value="instance('selection')//html:ul[@class='results']/html:li[index('{controls:ordered-list-repeat-id(concat($control-id, '-list'))}')]/following-sibling::html:li[1]/html:a[not(@class)]"/>
							<xf:setvalue ref="instance('selection-post-content')/self::tei:ptr/@xml:id"
								value="instance('selection')//html:ul[@class='results']/html:li[index('{controls:ordered-list-repeat-id(concat($control-id, '-list'))}')]/html:a[not(@class)]"/>
							<xf:setvalue ref="instance('selection-post-content')/self::tei:ptr/@target"
								value="instance('selection')//html:ul[@class='results']/html:li[index('{controls:ordered-list-repeat-id(concat($control-id, '-list'))}')]/html:a[@class='alt']/@href"/>
							<xf:send submission="selection-item-post"/>
				      <xf:delete nodeset="instance('selection')//html:ul[@class='results']/html:li[html:a[not(@class)] = instance('selection-post-content')/self::tei:ptr/@xml:id][1]"/>
						</xf:action>
						<xf:action ev:event="plus">
							{controls:unsave-save-flag($save-flag-instance-id)}
							<xf:delete nodeset="instance('selection')//html:span[@class='placeholder']"/>
							<xf:insert 
								context="instance('selection')//html:ul[@class='results']/html:li[index('{controls:ordered-list-repeat-id(concat($control-id, '-list'))}')]"
								origin="instance('placeholder')"
								/>
							<!--xf:setfocus control="control-{$document-chooser-id}"/-->
						</xf:action>
						<xf:action ev:event="minus">
							{controls:unsave-save-flag($save-flag-instance-id)}
							<xf:delete nodeset="instance('selection')//html:span[@class='placeholder']"/>
							<xf:setvalue ref="instance('deletion')/item" 
								value="instance('selection')//html:ul[@class='results']/html:li[index('{controls:ordered-list-repeat-id(concat($control-id, '-list'))}')]/html:a[not(class)]"/>
							<xf:send submission="selection-item-delete"/>
							<xf:delete nodeset="instance('selection')//html:ul[@class='results']/html:li[index('{controls:ordered-list-repeat-id(concat($control-id, '-list'))}')]"/>
						</xf:action>
					</xf:group>
					<div class="content-list-control">{
						builder:document-chooser-ui(
							$document-chooser-id,
							concat('control-', $document-chooser-id),
							let $trigger-id :=
								concat('control-', $document-chooser-id, '-add')
							return 
								<xf:trigger id="{$trigger-id}">
									<xf:label>Add</xf:label>
									<xf:action ev:event="DOMActivate" 
										if="count(instance('selection')//html:ul[@class='results']/html:li) &gt; 0">
										<xf:setvalue ref="instance('selection-post-position')/position" 
										value="choose(count(instance('selection')//html:span[@class='placeholder']) &gt; 0, instance('selection')//html:ul[@class='results']/html:li[html:span[@class='placeholder']]/html:a[not(@class)], instance('selection')//html:ul[@class='results']/html:li[last()]/html:a[not(@class)])"/>
										<xf:dispatch name="continue-insert" targetid="{$trigger-id}"/>
									</xf:action>
									<xf:action ev:event="DOMActivate" 
										if="count(instance('selection')//html:ul[@class='results']/html:li) = 0">
										<xf:setvalue ref="instance('selection-post-position')/position" value=""/>
										<xf:dispatch name="continue-insert" targetid="{$trigger-id}"/>
									</xf:action>
									<xf:action ev:event="continue-insert">
										{(: by the time you get here, the selection-post-position has been selected
										:)
										controls:unsave-save-flag($save-flag-instance-id)
										}
										<xf:setvalue 
										 	ref="instance('selection-post-content')/self::tei:ptr/@target" 
										 	value="concat(context()/html:a[@class='alt']/@href, '#main')"
										 	/>
										<xf:send submission="selection-item-post"/>
										<xf:delete nodeset="instance('selection')//html:span[@class='placeholder']"/>
									</xf:action>
								</xf:trigger>,
							true(), true(), 'Search result',
              <xf:repeat id="search-result" nodeset="./html:a/html:p">{
                builder:search-results-block()
              }</xf:repeat>
            )
					}</div>
					
				</xf:group>
				{
				controls:debug-show-instance('selection'),
				controls:debug-show-instance('document-chooser-action')
				}
			</div>
		</fieldset>,
		(site:css(), builder:css(),
		controls:faketable-style(
			concat('control-', $document-chooser-id), 
			100, 
			3)
		),
		site:header(),
		(site:sidebar-with-login($login-instance-id),
		builder:sidebar()),
		site:footer(),
		builder:app-header($builder-instance-id, 'app-header', 
			controls:save-status-ui($save-flag-instance-id, 'control-save-status', <xf:delete nodeset="instance('selection')//html:span[@class='placeholder']"/>), 
			'resource')
	)
