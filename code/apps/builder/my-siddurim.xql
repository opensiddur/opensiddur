xquery version "1.0";
(:~ Builder front page
 : 
 : ?new=true&amp;item=username (make a new user called username)
 : ?item=username (edit the profile of the existing user called username)
 : 
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :) 
import module namespace request="http://exist-db.org/xquery/request";
 
import module namespace app="http://jewishliturgy.org/modules/app" 
 	at "/code/modules/app.xqm";
import module namespace builder="http://jewishliturgy.org/apps/builder/controls"
	at "modules/builder.xqm";
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
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace xrx="http://jewishliturgy.org/xrx";

declare option exist:serialize "method=xhtml media-type=text/xml indent=yes omit-xml-declaration=no
	process-xsl-pi=no
	doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
	doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"; 


(: delay between updates to (reloads of) the document instances :)
declare variable $local:update-delay-ms := 30000;

(:~ instance for the confirm delete dialog 
 : the instance holds the resource that will be deleted
 :
 : to submit, submit instance($instance-id)/instance
 :)
declare function local:confirm-delete-instance(
	$instance-id as xs:string,
	$control-id as xs:string
	) as element()+ {
	let $error-instance-id := concat($instance-id, '-error')
	return (
		<xf:instance id="{$instance-id}">
			<instance xmlns="">
				<resource/>
			</instance>
		</xf:instance>,
		<xf:instance id="{$instance-id}-blank">
			<blank xmlns=""/>
		</xf:instance>,
		controls:error-instance($error-instance-id),
		<xf:submission id="{$instance-id}-submit"
			method="post"
			ref="instance('{$instance-id}-blank')"
			replace="none"
			validate="false"
			includenamespaceprefixes="">
			<xf:resource value="concat(instance('{$instance-id}')/*, '?_method=DELETE')"/>
			{
			controls:submission-response(
	  		$error-instance-id,
	  		(),
	  		(
	  			<xf:dispatch name="hide" targetid="{$control-id}"/>
	  		)
	  	)
		}</xf:submission>
	)
};

(:~ delete button. 
 : @param $ref reference to resource that will be deleted
 : @param $ref-to-resource-name human-readable name reference to string that can be used to reference the resource
 : @param $ref-to-uri reference to URI of resource to be deleted
 :)
declare function local:confirm-delete-dialog(
	$control-id as xs:string,
	$instance-id as xs:string,
	$ref as xs:string,
	$ref-to-resource-name as xs:string,
	$ref-to-uri as xs:string,
	$event-target as xs:string*
	) as element()+ {
	(: TODO: this really should be an xf:dialog :)
	controls:ok-cancel-dialog-ui(
		$control-id,
		(<div>Confirm deletion of <xf:output ref="{$ref-to-resource-name}"/>?</div>,
		controls:error-report(concat($instance-id,'-error')))
		,
		concat($control-id, '-action-handler')),
	<xf:group id="{$control-id}-action-handler">
		<xf:action ev:event="ok">
			{controls:clear-error(concat($instance-id,'-error'))}
			<xf:setvalue  
				ref="instance('{$instance-id}')/resource"
				value="context()/{$ref-to-uri}"/>			
			<xf:send submission="{$instance-id}-submit"/>
			<xf:delete nodeset="{$ref}" />
			{
				for $et in $event-target
				return <xf:dispatch name="ok" targetid="{$et}"/>
			}
		</xf:action>
		<xf:action ev:event="cancel">
		{
			controls:clear-error(concat($instance-id,'-error')),
			for $et in $event-target
			return <xf:dispatch name="cancel" targetid="{$et}" />
		}</xf:action>
	</xf:group>
};

declare function local:copy-metadata-to-builder(
	$builder-instance-id as xs:string
	) as element()+ {
	<xf:insert origin="." 
		nodeset="instance('{$builder-instance-id}-metadata')"
		at="1"
		position="before"/>
};

let $builder-instance-id := 'builder' (: really just a metadata instance :)
let $status-instance-id := 'status'
let $login-instance-id := 'login'
let $document-chooser-id := 'documents'
let $search-chooser-id  := 'search'
let $result-chooser-id := 'search-results'
return
	site:form(
		<xf:model id="model">
			{
			login:login-instance($login-instance-id, (
				site:sidebar-login-actions-id(), 
				'model'
				)
			),
			builder:login-actions('builder'),
			builder:document-chooser-instance(
				$document-chooser-id
			),
      builder:document-chooser-instance(
        $search-chooser-id, true(), xmldb:get-current-user(), (), 'output'
      ),
      builder:status-instance(
        $status-instance-id,
        $document-chooser-id,
        concat($document-chooser-id, "-error")
      ),
			local:confirm-delete-instance('confirm-delete', 'control-confirm-delete')
			}
			<xf:instance id="garbage">
				<!-- workaround for Firefox bug -->
				<tei:TEI j:junk="1" xrx:junk="1" html:junk="1" xml:lang="en"/>
			</xf:instance>
			{((: set up the reset for the document chooser instances every 30s :))}
			<xf:action ev:event="xforms-ready">
			  <xf:dispatch delay="{$local:update-delay-ms}" 
			    targetid="reset" name="reset-document-instances"/>
			</xf:action>
		</xf:model>,
		<title>Open Siddur Builder</title>,
		(
		(: this group serves to reset the document instances :)
		<xf:group id="reset">
		  <xf:action ev:event="reset-document-instances">
  		  <xf:dispatch 
  		    if="count(instance('{$document-chooser-id}')//html:ul[@class='results']/html:li/html:div[@class='status'][not(normalize-space(.)='Compiled')]) &gt; 0"
  		    targetid="reset"
  		    name="do-reset-document-instances"/>
  		  <xf:dispatch delay="{$local:update-delay-ms}" 
  		    targetid="reset" name="reset-document-instances"/>
  		</xf:action>
  		<xf:action ev:event="do-reset-document-instances">
  		  <xf:send submission="{$document-chooser-id}-submit"/>
  		</xf:action>
		</xf:group>,
		<xf:group id="control-my-siddurim">
			<fieldset>
				<h2>My Siddurim</h2>
				<div>
					<a href="{$builder:app-location}/edit-metadata.xql?new=true">Start a new siddur</a>
				</div>
				{
				builder:document-chooser-ui(
					$document-chooser-id,
					concat('control-', $document-chooser-id),
					(
						<xf:trigger appearance="minimal">
							<xf:label>Edit</xf:label>
							<xf:action ev:event="DOMActivate">
								<xf:load show="replace">
									<xf:resource value="concat('{$builder:app-location}/edit-metadata.xql?item=', ./html:a/@href)"/>
								</xf:load>
							</xf:action>
						</xf:trigger>,
						<xf:trigger appearance="minimal">
							<xf:label>Compile</xf:label>
							<xf:action ev:event="DOMActivate">
								<xf:load show="replace">
									<xf:resource value="concat('{$builder:app-location}/compile.xql?item=', ./html:a/@href)"/>
								</xf:load>
							</xf:action>
						</xf:trigger>,
	  				<xf:trigger appearance="minimal">
							<xf:label>Delete</xf:label>
	    				<xf:action ev:event="DOMActivate">
	    					<xf:dispatch name="show" targetid="control-confirm-delete"/>
	    				</xf:action>
	  				</xf:trigger>,
	  				local:confirm-delete-dialog('control-confirm-delete', 'confirm-delete',
	    				'.', 'html:a/html:span', './html:a/@href', ()
	    			)
    			
  				),
  				false(),
  				false(),
  				"Status",
  				<xf:output ref="./html:div[@class='status']"/>
				)
				
				}
        <h3>Search and View My Compiled Siddurim</h3>
        <p>Use the box below to search your <strong>compiled</strong> siddurim:</p>
        {
        builder:document-chooser-ui($search-chooser-id, 
          $result-chooser-id, 
          <xf:trigger appearance="minimal">
            <xf:label>View</xf:label>
            <xf:load ev:event="DOMActivate" show="new">
              <xf:resource value="./html:a/@href"/>
            </xf:load>
          </xf:trigger>,
          true(), true(), "Result",
          <xf:repeat id="search-result" nodeset="./html:a/html:p">
            {builder:search-results-block()}
          </xf:repeat>,
          (: this nodeset restriction removes uncompiled resources :)
          "[html:a[@class='alt'][.='xhtml']]"
        )
        }
			</fieldset>
			{controls:debug-show-instance($document-chooser-id),
			controls:debug-show-instance(concat($status-instance-id, "-result"))}
		</xf:group>
		)
		,
		(
      site:css(), builder:css(),
  		controls:faketable-style(
    		concat('control-', $document-chooser-id),	90,	3
      ),
  		controls:faketable-style(
    		$result-chooser-id,	90,	3
      )
		),
		site:header(),
		(site:sidebar-with-login($login-instance-id),
		builder:sidebar()),
 		site:footer()
	)
