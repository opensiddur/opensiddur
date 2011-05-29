xquery version "1.0";
(: common controls for builder applications 
 :
 : Copyright 2011 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License version 3 or later
 :)
module namespace builder="http://jewishliturgy.org/apps/builder/controls";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace app="http://jewishliturgy.org/modules/app" 
 	at "/code/modules/app.xqm";
import module namespace controls="http://jewishliturgy.org/modules/controls" 
 	at "/code/modules/controls.xqm"; 	
import module namespace login="http://jewishliturgy.org/apps/user/login" 
 	at "/code/apps/user/modules/login.xqm"; 	
import module namespace site="http://jewishliturgy.org/modules/site" 
 	at "/code/modules/site.xqm"; 	

declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace ev="http://www.w3.org/2001/xml-events";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace xrx="http://jewishliturgy.org/xrx";
declare namespace xf="http://www.w3.org/2002/xforms";

declare variable $builder:app-location := '/code/apps/builder';

(:~ output login-dependent sidebar for builder
 : login dependence requires sending login actions here 
 :)
declare function builder:sidebar(
	) as element(xf:group) {
	<xf:group id="builder-sidebar">
		<xf:toggle ev:event="login" case="builder-sidebar-login"/>
		<xf:toggle ev:event="logout" case="builder-sidebar-logout"/>
		<xf:switch>
			<xf:case id="builder-sidebar-login">
				<ul>
					<li><a href="{$builder:app-location}/edit-metadata.xql?new=true">Start new siddur</a></li>
          <li><a href="{$builder:app-location}/search.xql">Full text search</a></li>
				</ul>
			</xf:case>
			<xf:case id="builder-sidebar-logout"/>
		</xf:switch>
	</xf:group>
};

(:~ login action id for builder sidebar :)
declare function builder:sidebar-login-actions-id(
	) as xs:string {
	'builder-sidebar'
};

declare function builder:app-header(
	$builder-instance-id as xs:string,
	$control-id as xs:string,
	$save-button-control as element()?
	) {
	builder:app-header($builder-instance-id, $control-id,	$save-button-control, ())
};

(:~ builder application header 
 : @param $builder-instance-id base instance id of builder information
 : @param $control-id control id of the application header
 : @param $save-button-control Save button control. Use controls:save-status-ui() for the default.
 : @param $resource-instance-id Idenitifier of instance that holds /resource, the resource being edited
 :)
declare function builder:app-header(
	$builder-instance-id as xs:string,
	$control-id as xs:string,
	$save-button-control as element()?,
	$resource-instance-id as xs:string?
	) as element()+ {
	let $uri := string(request:get-uri())
	let $active-tab-id := replace(substring-after($uri, concat(util:collection-name($uri), '/')), '.xql$', '')
	let $resource-param := 
		if ($resource-instance-id)
		then concat("'?item=',", controls:instance-to-ref($resource-instance-id, '/item'))
		else "''"
	let $resource-ref :=
		if ($resource-instance-id)
		then attribute ref {controls:instance-to-ref($resource-instance-id, "/item[. != '']")}
		else ()
	return 
	<xf:group id="{$control-id}">
		<div class="nav-header">
			<div class="nav-buttons">
				<ul>
					<li>
						{
						if ($active-tab-id = 'my-siddurim')
						then attribute class {'nav-active'}
						else ()
						}
						<xf:trigger appearance="minimal">
							<xf:label>My siddurim</xf:label>
							<xf:action ev:event="DOMActivate">
								<xf:load resource="{$builder:app-location}/my-siddurim.xql" show="replace"/>
							</xf:action>
						</xf:trigger>
					</li>
					<li>
						{
						if ($active-tab-id = 'edit-metadata')
						then attribute class {'nav-active'}
						else ()
						}
						<xf:trigger appearance="minimal">
							<xf:label>About this Siddur</xf:label>
							<xf:action ev:event="DOMActivate">
								<xf:load show="replace">
									<xf:resource value="concat('{$builder:app-location}/edit-metadata.xql', {$resource-param})"/> 
								</xf:load>
							</xf:action>
						</xf:trigger>
					</li>
					<li>
						{
						if ($active-tab-id = 'edit-content')
						then attribute class {'nav-active'}
						else ()
						}
						<xf:trigger appearance="minimal">
							{$resource-ref}
							<xf:label>Edit Content</xf:label>
							<xf:action ev:event="DOMActivate">
								<xf:load show="replace">
									<xf:resource value="concat('{$builder:app-location}/edit-content.xql', {$resource-param})"/>
								</xf:load>
							</xf:action>
						</xf:trigger></li>
					<li>
						{
						if ($active-tab-id = 'edit-style')
						then attribute class {'nav-active'}
						else ()
						}
						<xf:trigger appearance="minimal">
							{$resource-ref}
							<xf:label>Edit style</xf:label>
							<xf:action ev:event="DOMActivate">
								<xf:load show="replace">
									<xf:resource value="concat('{$builder:app-location}/edit-style.xql', {$resource-param})"/>
								</xf:load>
							</xf:action>
						</xf:trigger>
					</li>
					<li>
						{
						if ($active-tab-id = 'compile')
						then attribute class {'nav-active'}
						else ()
						}
						<xf:trigger appearance="minimal">
							{$resource-ref}
							<xf:label>Compile</xf:label>
							<xf:action ev:event="DOMActivate">
								<xf:load show="replace">
									<xf:resource value="concat('{$builder:app-location}/compile.xql', {$resource-param})"/>
								</xf:load>
							</xf:action>
						</xf:trigger>
					</li>
				</ul>
			</div>
			<div class="save-status">{
				$save-button-control
			}</div>
		</div>
	</xf:group>
};

declare function builder:css(
	) as element(link)+ {
	<link rel="stylesheet" type="text/css" href="{$builder:app-location}/styles/builder.css"/>,
  builder:keyboard-css()
}; 

(:~ output CSS and js links for virtual keyboard :)
declare function builder:keyboard-css(
  ) as element()+ {
  <script type="text/javascript" src="{$builder:app-location}/scripts/keyboard.js" charset="UTF-8"></script>,
  <link rel="stylesheet" type="text/css" href="{$builder:app-location}/styles/keyboard.css"/>
};

(:~ output login actions id from builder:login-actions
 : WARNING: do not use!
 :)
declare function builder:login-actions-id(
	$instance-id as xs:string
	) as xs:string {
	concat($instance-id, '-login-actions')
};

(:~ output a logout action element that resets the page to the welcome page 
 : NOTE: this is intended to go in the model, and in XSLTForms, the action
 : will not be referenced properly by id. Use the model's id as the referencing id,
 : not builder:login-actions-id
 :)
declare function builder:login-actions(
	$instance-id as xs:string
	) as element() {
	<xf:action id="{builder:login-actions-id($instance-id)}" ev:event="logout">
		<xf:load show="replace" resource="{$builder:app-location}/welcome.xql"/>
	</xf:action>
};

declare function builder:document-chooser-instance(
	$instance-id as xs:string
	) as element()+ {
	builder:document-chooser-instance($instance-id, true(), (), ())
};

declare function builder:document-chooser-instance(
	$instance-id as xs:string,
	$allow-change-share-group as xs:boolean, 
	$default-share-group as xs:string?
	) as element()+ {
	builder:document-chooser-instance($instance-id, $allow-change-share-group, $default-share-group, ())
};

declare function builder:document-chooser-instance(
	$instance-id as xs:string,
	$allow-change-share-group as xs:boolean, 
	$default-share-group as xs:string?,
	$resource-instance-id as xs:string?
	) as element()+ {
  builder:document-chooser-instance(
    $instance-id, $allow-change-share-group, 
    $default-share-group, $resource-instance-id, ())
};

(:~ document chooser instance.
 : offers a number of options, including making the share group changable or unchangable
 : if a $resource-instance-id is given, the current document listed in it is not shown in the UI.
 :)
declare function builder:document-chooser-instance(
	$instance-id as xs:string,
	$allow-change-share-group as xs:boolean, 
	$default-share-group as xs:string?,
	$resource-instance-id as xs:string?,
  $default-purpose as xs:string?
	) as element()+ {
	let $error-instance-id := concat($instance-id, '-error')
	let $share-options-id := concat($instance-id, '-share')
	return (
		builder:share-options-instance($share-options-id, not($allow-change-share-group), $default-share-group),
		<xf:instance id="{$instance-id}">
			<html:html/>
		</xf:instance>,
		<xf:instance id="{$instance-id}-search">
			<options xmlns="">
				<q/>
				<start>1</start>
				<max-results>50</max-results>
			</options>
		</xf:instance>,
		<xf:instance id="{$instance-id}-exclude">
			<exclude xmlns="">
				<item/>
			</exclude>
		</xf:instance>,
		if ($resource-instance-id)
		then
			(: exclude the current document :)
			<xf:bind nodeset="instance('{$instance-id}-exclude')/item"
				type="xf:string"
				calculate="instance('{$resource-instance-id}')/item"/>
		else (),
		<xf:instance id="{$instance-id}-action">
			<action xmlns="">
				<data-type>{($default-purpose, 'original')[1]}</data-type>
				<share-type>group</share-type>
				<owner></owner>
        <scope/>
			</action>
		</xf:instance>,
		<xf:bind nodeset="instance('{$instance-id}-action')/owner" 
			calculate="instance('{$share-options-id}')/owner"/>,
    (: set the search scope using a checkbox :)
    <xf:instance id="{$instance-id}-search-options">
      <search-options xmlns="">
        <titles-only>false</titles-only>
      </search-options>
    </xf:instance>,
    <xf:bind nodeset="instance('{$instance-id}-search-options')/titles-only" type="xf:boolean"/>,
    <xf:bind nodeset="instance('{$instance-id}-action')/scope"
      calculate="choose(boolean-from-string(instance('{$instance-id}-search-options')/titles-only),'title','')"/>,
		<xf:instance id="{$instance-id}-max-results-chooser">
			<max-results xmlns="">
				<max-result>25</max-result>
				<max-result>50</max-result>
				<max-result>100</max-result>
				<max-result>250</max-result>
				<max-result>500</max-result>
				<max-result>1000</max-result>
			</max-results>
		</xf:instance>,
		<xf:instance id="{$instance-id}-range">
			<range xmlns="">
				<first>
					<start>
						<n-results/>
						<value>1</value>
					</start>
					<end>
						<max-results/>
						<n-results/>
					</end>
				</first>
				<previous>
					<start>
						<n-start-minus-max-results/>
						<value>1</value>
					</start>
					<end>
						<prev-start-plus-max-results/>
						<n-results/>
					</end>
				</previous>
				<next>
					<start>
						<n-end-plus-one/>
						<n-results/>
					</start>
					<end>
						<n-end-plus-max-results/>
						<n-results/>
					</end>
				</next>
				<last>
					<start>
						<value>1</value>
						<n-results-minus-max-results/>
					</start>
					<end>
						<n-results/>
					</end>
				</last>
			</range>
		</xf:instance>,
		<xf:bind nodeset="instance('{$instance-id}-range')//max-results" 
			calculate="instance('{$instance-id}-search')/max-results"/>,
		<xf:bind nodeset="instance('{$instance-id}-range')//n-results" 
			calculate="instance('{$instance-id}')//html:meta[@name='results']/@content"/>,
		<xf:bind nodeset="instance('{$instance-id}-range')//n-start-minus-max-results" 
			calculate="instance('{$instance-id}')//html:meta[@name='start']/@content - instance('{$instance-id}-search')/max-results"/>,
		<xf:bind nodeset="instance('{$instance-id}-range')//prev-start-plus-max-results" 
			calculate="max(instance('{$instance-id}-range')/previous/start/*) + instance('{$instance-id}-search')/max-results - 1"/>,
		<xf:bind nodeset="instance('{$instance-id}-range')//n-start-minus-one" 
			calculate="instance('{$instance-id}')//html:meta[@name='start']/@content - 1"/>,
		<xf:bind nodeset="instance('{$instance-id}-range')//n-end-plus-one" 
			calculate="instance('{$instance-id}')//html:meta[@name='end']/@content + 1"/>,
		<xf:bind nodeset="instance('{$instance-id}-range')//n-end-plus-max-results" 
			calculate="instance('{$instance-id}')//html:meta[@name='end']/@content + instance('{$instance-id}-search')/max-results"/>,
		<xf:bind nodeset="instance('{$instance-id}-range')//n-results-minus-max-results" 
			calculate="instance('{$instance-id}')//html:meta[@name='results']/@content - instance('{$instance-id}-search')/max-results"/>,
		controls:error-instance($error-instance-id),
		<xf:action ev:event="xforms-ready">
			<xf:send submission="{$instance-id}-submit"/>
		</xf:action>,
		<xf:submission id="{$instance-id}-submit"
			ref="instance('{$instance-id}-search')"
			method="get"
			replace="instance"
			instance="{$instance-id}"
			includenamespaceprefixes="">
			<xf:resource value="
			concat('/code/api/data/', 
				instance('{$instance-id}-action')/data-type,
				choose(instance('{$instance-id}-action')/share-type != '', concat('/', instance('{$instance-id}-action')/share-type), ''),
				choose(instance('{$instance-id}-action')/owner != '', concat('/', instance('{$instance-id}-action')/owner), ''),
        choose(instance('{$instance-id}-action')/scope != '', concat('/.../', instance('{$instance-id}-action')/scope), '')
				)"/>
			{
			controls:submission-response(
  			$error-instance-id,
  			(), 
  			()
  		)
		}</xf:submission>
	)
};

(:~ return the id of the repeat control in the document chooser,
 : given its control id :)
declare function builder:document-chooser-ui-repeat(
	$control-id as xs:string
	) as xs:string {
	concat($control-id, '-repeat')
};

declare function builder:document-chooser-ui(
	$instance-id as xs:string,
	$control-id as xs:string,
	$actions as element()+) {
	builder:document-chooser-ui($instance-id, $control-id, $actions, false())
};

declare function builder:document-chooser-ui(
	$instance-id as xs:string,
	$control-id as xs:string,
	$actions as element()+,
	$allow-change-sharing as xs:boolean
	) as element()+ {
	builder:document-chooser-ui($instance-id, $control-id, $actions, false(), false(), 'Status', 'N/A')
};

(:~ 
 : in the style section, you need to add a faketable control style for this control.
 : the table's control id is {$control-id}-table, and it has 4 columns
 : @param $actions actions that can be done with each document
 : @param $allow-change-sharing Allow the sharing parameters to be changed by the user (default false)
 : @param $allow-search Whether to have a search box
 : @param $results-column-title title of middle column
 : @param $results-column-content content of middle column
 :)
declare function builder:document-chooser-ui(
	$instance-id as xs:string,
	$control-id as xs:string,
	$actions as element()+,
	$allow-change-sharing as xs:boolean,
  $allow-search as xs:boolean,
  $results-column-title as item()+, 
  $results-column-content as item()+
	) as element()+ {
	<xf:group id="{$control-id}" ref="instance('{$instance-id}')">
		<xf:group>
			<div class="inline-control document-chooser-header">
				<xf:trigger id="{$control-id}-first" ref="//html:link[@rel='first']" appearance="minimal">
					<xf:label>|&lt;&lt; <xf:output value="min(instance('{$instance-id}-range')/first/start/*)"/>-<xf:output value="min(instance('{$instance-id}-range')/first/end/*)"/></xf:label>
					<xf:action ev:event="DOMActivate">
						<xf:setvalue ref="instance('{$instance-id}-search')/start" 
							value="substring-before(substring-after(context()/@href, 'start='), '&amp;')"/>
						<xf:send submission="{$instance-id}-submit"/>
					</xf:action>
				</xf:trigger> 
				<xf:trigger id="{$control-id}-previous" ref="//html:link[@rel='previous']" appearance="minimal">
					<xf:label>&lt; 
							<xf:output value="max(instance('{$instance-id}-range')/previous/start/*)"/>-<xf:output value="min(instance('{$instance-id}-range')/previous/end/*)"/>
					</xf:label>
					<xf:action ev:event="DOMActivate">
						<xf:setvalue ref="instance('{$instance-id}-search')/start" 
							value="substring-before(substring-after(context()/@href, 'start='), '&amp;')"/>
						<xf:send submission="{$instance-id}-submit"/>
					</xf:action>
				</xf:trigger>
				<xf:trigger id="{$control-id}-current" appearance="minimal">
					<xf:label>
						[<xf:output ref="//html:meta[@name='start']/@content"/>-<xf:output ref="//html:meta[@name='end']/@content"/>]
					</xf:label>
				</xf:trigger>
				<xf:output ref="//html:link[@rel='previous']" value="'&#xa0;'"/>
				<xf:trigger id="{$control-id}-next" ref="//html:link[@rel='next']" appearance="minimal">
					<xf:label>
						<xf:output value="min(instance('{$instance-id}-range')/next/start/*)"/>-<xf:output value="min(instance('{$instance-id}-range')/next/end/*)"/>
					&gt;</xf:label>
					<xf:action ev:event="DOMActivate">
						<xf:setvalue ref="instance('{$instance-id}-search')/start" 
							value="substring-before(substring-after(context()/@href, 'start='), '&amp;')"/>
						<xf:send submission="{$instance-id}-submit"/>
					</xf:action>
				</xf:trigger>
				<xf:trigger id="{$control-id}-last" ref="//html:link[@rel='last']" appearance="minimal">
					<xf:label>
						<xf:output value="max(instance('{$instance-id}-range')/last/start/*)"/>-<xf:output value="max(instance('{$instance-id}-range')/last/end/*)"/>
					  &gt;&gt;|</xf:label>
					<xf:action ev:event="DOMActivate">
						<xf:setvalue ref="instance('{$instance-id}-search')/start" 
							value="substring-before(substring-after(context()/@href, 'start='), '&amp;')"/>
						<xf:send submission="{$instance-id}-submit"/>
					</xf:action>
				</xf:trigger> 
        {
        (: search box :)
        if ($allow-search)
        then 
          <div class="search-box">
            <span class="keyboardInput">
              <xf:input ref="instance('{$instance-id}-search')/q"/>
            </span>
            <xf:input ref="instance('{$instance-id}-search-options')/titles-only">
              <xf:label>Titles only</xf:label>
            </xf:input>
            <xf:submit submission="{$instance-id}-submit">
              <xf:label>Search</xf:label>
              <xf:setvalue ev:event="DOMActivate" ref="instance('{$instance-id}-search')/start" 
                value="substring-before(substring-after(context()/@href, 'start='), '&amp;')"/>
            </xf:submit>
            <xf:submit submission="{$instance-id}-submit">
              <xf:label>Reset</xf:label>
              <xf:action ev:event="DOMActivate">
                <xf:setvalue ref="instance('{$instance-id}-search')/start" value="1"/>
                <xf:setvalue ref="instance('{$instance-id}-search')/q" value=""/>
              </xf:action>
            </xf:submit>
          </div>
        else ()
        }
				<xf:select1 ref="instance('{$instance-id}-search')/max-results">
					<xf:label>Display up to:</xf:label>
					<xf:itemset nodeset="instance('{$instance-id}-max-results-chooser')/max-result">
						<xf:label ref="."/>
						<xf:value ref="."/>
					</xf:itemset>
					<xf:action ev:event="xforms-value-changed">	
						<xf:send submission="{$instance-id}-submit"/>
					</xf:action>
				</xf:select1>
				{
				if ($allow-change-sharing)
				then 
					let $share-control := concat($control-id, '-share')
					return 
						<xf:group>{
							builder:share-options-ui(
								concat($instance-id, '-share'), 
								$share-control,
								'Available sharing groups:'
							)}
							<xf:action ev:event="xforms-value-changed">
								<xf:setvalue ref="instance('{$instance-id}-action')/owner" value="instance('{$instance-id}-share')/owner"/>
								<xf:setvalue ref="instance('{$instance-id}-search')/start" value="1"/>
								<xf:send submission="{$instance-id}-submit"/>
							</xf:action>
						</xf:group>
				else ()
				}
			</div>
		</xf:group>
		<div class="{$control-id}-table table">
			<div class="{$control-id}-header {$control-id}-row table-header table-row">
  			<div class="{$control-id}-column table-column">Document</div>
  			<div class="{$control-id}-column table-column">{$results-column-title}</div>
  			<div class="{$control-id}-column table-column">Actions</div>
  		</div>
  		<xf:repeat id="{builder:document-chooser-ui-repeat($control-id)}" 
  			nodeset="/html:html/html:body/html:ul[@class='results']/html:li[not(html:a/@href=instance('{$instance-id}-exclude')/item)]">
	  		<div class="{$control-id}-row table-row">
	    		<div class="{$control-id}-column table-column">
	      		<xf:output ref="./html:a/html:span"/>
	    		</div>
	        <div class="{$control-id}-column table-column">
	        	{$results-column-content}
	        </div>
	        <div class="{$control-id}-column table-column">
	        	<div class="actions-row">
		          {$actions}
		  			</div>
	       	</div>
       	</div>
	    </xf:repeat>
	  </div>
	</xf:group>
}; 

declare function builder:share-options-instance(
	$instance-id as xs:string
	) {
	builder:share-options-instance($instance-id, true(), ())
};

declare function local:direction-by-lang(
  $lang as xs:string?
  ) as xs:string {
  if ($lang = ('he','arc' (: TODO: add other rtl languages here :) ))
  then 'rtl'
  else 'ltr'
};

(: search results block by language 
 : there should be a better way to do this. :)
declare function local:search-result-lang(
  $lang as xs:string
  ) {
  <xf:group ref="self::html:p[@lang='{$lang}']">
    <span xml:lang="{$lang}" lang="{$lang}">
      {
      let $dir := local:direction-by-lang($lang)
      where $dir = 'rtl'
      return attribute dir {$dir}
      }
      <xf:output ref="html:span[@class='previous']"/>
      <span class="search-match">
        <xf:output ref="html:span[@class='hi']"/>
      </span>
      <xf:output ref="html:span[@class='following']"/>
    </span>
  </xf:group>
};

(:~ block of search results to appear in the context of a repeat on 
 : html:a/html:p :)
declare function builder:search-results-block(
  ) {
  for $lang in ('en','he')
  return
    local:search-result-lang($lang)
};

declare function builder:share-options-instance(
	$instance-id as xs:string,
	$disable-share-types as xs:boolean?) {
	builder:share-options-instance($instance-id, $disable-share-types, ())
};

declare function builder:share-options-instance(
	$instance-id as xs:string,
	$disable-share-types as xs:boolean?,
	$default-share-group as xs:string?
	) as element()+ {
	let $user := app:auth-user()
	return (
		<xf:instance id="{$instance-id}-groups">
			<groups xmlns="">{
				for $group in xmldb:get-user-groups($user)
				return <group>{$group}</group>	
			}</groups>
		</xf:instance>,
		<xf:instance id="{$instance-id}">
			<privacy xmlns="">
				<private>group</private>
				<owner>{($default-share-group, app:auth-user())[1]}</owner>
			</privacy>
		</xf:instance>,
		(: temporarily set to readonly because it's not implemented! :)
		<xf:bind id="{$instance-id}-group" 
			nodeset="instance('{$instance-id}')/owner" 
			required="true()"
			readonly="{$disable-share-types}()"
			type="xf:string"/>
	)
};

declare function builder:share-options-ui(
	$instance-id as xs:string,
	$control-id as xs:string,
	$label as xs:string
	) as element()+ {
	<xf:group id="{$control-id}" ref="instance('{$instance-id}')">
		<xf:select1 id="{$control-id}-group" incremental="true" ref="owner">
			<xf:label>{$label}</xf:label>
			<xf:itemset nodeset="instance('{$instance-id}-groups')/group">
				<xf:label ref="."/>
				<xf:value ref="."/>
			</xf:itemset>
		</xf:select1>
	</xf:group>
};
