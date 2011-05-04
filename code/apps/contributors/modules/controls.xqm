xquery version "1.0";

(:~ contributor list related controls 
 : 
 : The Open Siddur Project
 : Copyright 2010 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: controls.xqm 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)

module namespace contributors="http://jewishliturgy.org/apps/contributors/controls";

import module namespace common="http://jewishliturgy.org/apps/contributors/common"
	at "common.xqm";
import module namespace controls="http://jewishliturgy.org/modules/controls" 
	at "../../../modules/controls.xqm";
import module namespace login="http://jewishliturgy.org/apps/user" 
	at "../../user/modules/login.xqm";
	
(: only used for a kluge :)
import module namespace paths="http://jewishliturgy.org/modules/paths" 
	at "../../../modules/paths.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema"; 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xrx="http://jewishliturgy.org/ns/xrx";
declare namespace html="http://www.w3.org/1999/xhtml";

(:~ whether to use a real table or fake table in the output 
 : depends on support for xf:repeat-*, which is currently not good in XSLTForms and betterFORM
 :)
declare variable $contributors:use-real-table := false();

(:~ sidebar for the contributors :)
declare function contributors:sidebar() 
  as element() {
  <html:div id="contributor-sidebar">
    <html:h3>Contributors list</html:h3>
    <html:ul>
      <html:li><html:a href="{$paths:apps}/contributors/views/list-items.xql">View</html:a></html:li>
      <html:li><html:a href="{$paths:apps}/contributors/edit/edit.xql">Edit (requires login)</html:a></html:li>
      <html:li><html:a href="{$paths:apps}/contributors/search/search.xql">Search</html:a></html:li>
    </html:ul>
  </html:div>
};

(:~ css link for contributors :)
declare function contributors:css()
  as element() {
  <html:link rel="stylesheet" type="text/css" href="{$paths:apps}/contributors/styles/contributors.css"/>
};

(:~ instance for an individual contributor list entry
 : required to use individual-entry-ui()
 :
 : @param $instance-id Instance id of single contributor list entry
 : @param $list-instance-id Instance id of contributor list
 : @param $id Identifier of entry
 : @param $new Contains text if the entry is new
 : @param $event-target Where to send xforms-submit-done and xforms-submit-error
 :)
declare function contributors:individual-entry-instance(
	$instance-id as xs:string,
	$list-instance-id as xs:string,
	$id as xs:string?,
	$new as xs:string?,
	$event-target as xs:string?) 
	as element()+ {
	contributors:individual-entry-instance(
		$instance-id, $list-instance-id, $id, $new, $event-target, false(), ()
	)
};  
 
(:~ 
 : @param $writable If false(), makes the instance read-only
 : @param $login-instance-id Instance Id where login information is held; required if $writable is true()
 :)
declare function contributors:individual-entry-instance(
	$instance-id as xs:string,
	$list-instance-id as xs:string,
	$id as xs:string?,
	$new as xs:string?,
	$event-target as xs:string?,
	$writable as xs:boolean,
  $login-instance-id as xs:string?)
	as element()+ {
	(
	<xf:instance id="null">
		<null xmlns=""/>
	</xf:instance>,
	<xf:instance xmlns="" 
		src="{
				string-join(($common:loader, '?id=', 
					if ($id) 
					then $id 
					else 'new')
					,'')
		}" 
		id="{$instance-id}">
	</xf:instance>,
	<xf:instance id="{$instance-id}-empty-affiliation">
		<empty-affiliation xmlns="">
			<tei:item>
				<!-- this has a nonexistent xml:id -->
				<tei:orgName>None</tei:orgName>
			</tei:item>
		</empty-affiliation>
	</xf:instance>,
  <xf:instance id="{$instance-id}-validation-error">
    <error xmlns="">
      <exception>Please check that all required (bold) fields are filled in and that all fields have the correct information.</exception>
    </error>
  </xf:instance>,
	<xf:instance id="{$instance-id}-ui">
		<ui xmlns="">
			{
			if ($writable)
			then <writable/>
			else <readonly/>
			}
			<!-- id that is to be deleted -->
			<delete>
				<id/>
			</delete>
			<!-- ids that are being edited -->
			<editing>
				<is-new/>
				<original-id/>
				<current-id/>
				<unique/>
			</editing>
		</ui>
	</xf:instance>,
  controls:error-instance(concat($instance-id, '-error')),
  (: save submission :)
	<xf:submission id="{$instance-id}-save"
		method="post"
		ref="instance('{$instance-id}')"
		replace="instance"
		instance="{$instance-id}"
		>
    {(: if this save replaces a pre-existing element, use save.xql?id=original-id :)()}
    <xf:resource value="concat('{$common:saver}', choose(instance('{$instance-id}-ui')/editing/is-new != 'true', concat('?id=', instance('{$instance-id}-ui')/editing/original-id), ''))"/>
    {if ($writable) then login:login-headers($login-instance-id) else (),
    controls:submission-response(
      $instance-id, 
      concat($instance-id, '-error'), 
      concat($instance-id, '-validation-error'), 
      concat("instance('",$instance-id,"')"), 
      $event-target, (
      (: if an item is old, place it right after the item with its original id :)
      <xf:insert 
        origin="instance('{$instance-id}')/tei:item" 
        nodeset="instance('{$list-instance-id}')/tei:item[@xml:id = instance('{$instance-id}-ui')/editing/original-id]"
        position="after" 
        at="1"
        if="instance('{$instance-id}-ui')/editing/is-new = 'false'"/>,
      <xf:delete nodeset="instance('{$list-instance-id}')/tei:item[@xml:id = instance('{$instance-id}-ui')/editing/original-id][1]"
        if="instance('{$instance-id}-ui')/editing/is-new = 'false'"/>,
      (: if an item is new, insert it at the end of the list :)
      <xf:insert 
        origin="instance('{$instance-id}')/tei:item" 
        nodeset="instance('{$list-instance-id}')/tei:item"
        position="after" 
        at="last()"
        if="instance('{$instance-id}-ui')/editing/is-new = 'true' and count(instance('{$list-instance-id}')) &gt; 0"/>,
      (: if the list instance is empty ... :)
      <xf:insert 
        origin="instance('{$instance-id}')" 
        nodeset="instance('{$list-instance-id}')"
        if="count(instance('{$list-instance-id}')/tei:item)=0"/>,
      <xf:send submission="{$list-instance-id}-load-idrefs"/>
      )) }
	</xf:submission>, 
  (: delete :)
	<xf:submission id="{$instance-id}-delete"
		method="get"
		ref="instance('{$instance-id}-ui')/delete/id"
		resource="{$common:deleter}"
		replace="instance"
		instance="null">
    {if ($writable) then login:login-headers($login-instance-id) else (),
    controls:submission-response(
      $instance-id, 
      concat($instance-id, '-error'), 
      concat($instance-id, '-validation-error'), 
      "instance('null')", 
      $event-target, (
      (: delete the item on success :)
      <xf:delete nodeset="instance('{$list-instance-id}')/tei:item[@xml:id = instance('{$instance-id}-ui')/delete/id]"/>,
      (: reload idrefs :)
      <xf:send submission="{$list-instance-id}-load-idrefs"/>
      )) }
	</xf:submission>,
	<xf:submission id="{$instance-id}-check-unique"
		method="post"
		ref="instance('{$instance-id}-ui')/editing"
		resource="{$paths:rest-prefix}{$paths:apps}/contributors/edit/unique-id.xql"
		mode="asynchronous"
		replace="instance"
		targetref="instance('{$instance-id}-ui')/editing/unique"
		>
	</xf:submission>,
	contributors:bindings($instance-id, ($list-instance-id, $instance-id)[1], $id, $writable)
	)
	
};

(:~ instance which holds all of the entries in the contributor list 
 :)
declare function contributors:list-instance(
	$instance-id as xs:string) 
	as element()+ {
	(
	<xf:instance xmlns="" 
		src="{$common:loader}" 
		id="{$instance-id}">
	</xf:instance>,
	<xf:instance id="{$instance-id}-prototype"
		src="{$common:prototype-path}">
	</xf:instance>,
	(: cause entire page to reload :)
	<xf:submission id="{$instance-id}-load"
		method="post"
		ref="instance('null')"
		resource="{$common:loader}"
		replace="instance"
		targetref="instance('{$instance-id}')"
		>
		<xf:refresh ev:event="xforms-submit-done"/>
	</xf:submission>,
	(: kluge instance containing idreferences (=#id) for organizational entities :)
	<xf:instance id="{$instance-id}-idref" 
		src="{concat($paths:prefix, $paths:apps, '/contributors/load-idref-instance.xql')}">
	</xf:instance>,
  <xf:submission id="{$instance-id}-load-idrefs" 
    resource="{concat($paths:prefix, $paths:apps, '/contributors/load-idref-instance.xql')}"
    ref="instance('null')"
    method="get"
    instance="{$instance-id}-idref"
    replace="instance">
  </xf:submission>
	)
};

declare function contributors:bindings(
	$instance-id as xs:string,
	$list-instance-id as xs:string,
	$id as xs:string?,
	$writable as xs:boolean) 
	as element(xf:bind)+ {
	let $readonly := 
		if ($writable)
		then ()
		else attribute {'readonly'}{'true()'} 
	return
	(
	<xf:bind 
    id="{$instance-id}-xmlid"
    nodeset="instance('{$instance-id}')/tei:item/@xml:id"
		constraint="instance('{$instance-id}-ui')/editing/unique = 'true'" 
		required="true()"
		type="xf:NCName"
		>{
		if ($id or not($writable))
		then attribute readonly {"true()"}
		else ()
	}</xf:bind>,
	<xf:bind 
    id="{$instance-id}-email"
    nodeset="instance('{$instance-id}')/tei:item/tei:email" 
		type="xf:email" required="true()">{$readonly}</xf:bind>,
	<xf:bind 
    id="{$instance-id}-orgName"
    nodeset="instance('{$instance-id}')/tei:item/tei:orgName" type="xf:string" 
		relevant="../tei:name = ''" required="../tei:name = ''">{
		$readonly
	}</xf:bind>,
	<xf:bind 
    id="{$instance-id}-url"
    nodeset="instance('{$instance-id}')/tei:item/tei:ptr/@target" 
		type="xf:anyURI">{
		$readonly
	}</xf:bind>,
	<xf:bind 
    id="{$instance-id}-name"
    nodeset="instance('{$instance-id}')/tei:item/tei:name" type="xf:string" relevant="../tei:orgName = ''" required="../tei:orgName = ''">{
		$readonly
	}</xf:bind>,
	<xf:bind 
    id="{$instance-id}-affiliation"
    nodeset="instance('{$instance-id}')/tei:item/tei:affiliation/tei:ptr/@target" 
		type="xf:anyURI" relevant="../../../tei:name">{
		$readonly
	}</xf:bind>
	)
};

(:~ search query instance
 : events: xforms-submit-done, xforms-submit-error
 :)
declare function contributors:search-instance(
	$instance-id as xs:string,
	$results-instance-id as xs:string,
	$event-target as xs:string?)
	as element()+ {
	(
	<xf:instance id="{$instance-id}">
		<query xmlns="">
			<q/>
		</query>
	</xf:instance>,
	<xf:instance id="{$results-instance-id}">
		<null xmlns="">
      <null/>
    </null>
	</xf:instance>,
  controls:error-instance(concat($instance-id,'-error')),
	<xf:bind nodeset="instance('{$instance-id}')/q" type="xf:string" required="true()"/>,
	<xf:submission id="{$instance-id}-search"
		method="post"
		ref="instance('{$instance-id}')"
		resource="{$common:searcher}"
		replace="instance"
		instance="{$results-instance-id}"
		>
		{
    controls:submission-response(
      $instance-id, 
      concat($instance-id, '-error'), 
      '', (: I don't think a validation error can happen here :) 
      concat("instance('",$instance-id,"')"), 
      $event-target, ()
    )
		}
	</xf:submission>
	)
};

(:~ User interface for a single contributor entry.
 : Buttons are: {$control-id}-save and {$control-id}-cancel
 : @param $instance-id Instance that holds contributor list
 : @param $control-id Identifier of this control
 : @param $ref reference (defaults to instance('{$instance-id}'))
 : @param $id Identifier of contributor that the entry identifies (optional) 
 :)
declare function contributors:individual-entry-ui(
	$instance-id as xs:string,
	$list-instance-id as xs:string,
	$control-id as xs:string,
	$id as xs:string?) 
	as element()+ {
	<xf:group id="{$control-id}" ref="instance('{$instance-id}')/tei:item">
		{if ($id)
		then 
			<xf:output bind="{$instance-id}-xmlid">
				<xf:label>Login ID:</xf:label>
			</xf:output>
		else (
			<xf:input bind="{$instance-id}-xmlid" incremental="true">
				<xf:label>Login ID:</xf:label>
				<xf:alert>The login ID must begin with a letter.  It may contain numbers, letters, and periods and it must be unique in the contributor list.</xf:alert>
				<xf:action ev:event="xforms-value-changed">
					<xf:setvalue ref="instance('{$instance-id}-ui')/editing/current-id" 
						value="instance('{$instance-id}')/tei:item/@xml:id"/>
					<xf:send submission="{$instance-id}-check-unique"/>
				</xf:action>
			</xf:input>
		)
		}
		<html:br/>
		<xf:input bind="{$instance-id}-name" incremental="true">
			<xf:label>Real name or pseudonym (for a person; include relevant titles and full name): </xf:label>
		</xf:input>
		<html:br/>
		<xf:input bind="{$instance-id}-orgName" incremental="true">
			<xf:label>Organization name (for a company, non-profit, etc.): </xf:label>
		</xf:input>
		<html:br/>
		<xf:input bind="{$instance-id}-url">
			<xf:label>Website address (URL): </xf:label>
		</xf:input>
		<html:br/>
		<xf:input bind="{$instance-id}-email" incremental="true">
			<xf:label>Public email address:</xf:label>
		</xf:input>
		<html:br/>
		<xf:select1 bind="{$instance-id}-affiliation" incremental="true">
			<xf:label>Organizational affiliation:</xf:label>
			<xf:itemset nodeset="instance('{$instance-id}-empty-affiliation')/tei:item|instance('{$list-instance-id}')/tei:item[tei:orgName != '']">
				<xf:label ref="tei:orgName"/>
				<!-- this is a kluge: it should be xf:value value="concat('#', @xml:id)"/ -->
				<xf:value ref="instance('{$list-instance-id}-idref')/idref[@id = current()/@xml:id]/@idref"/>
			</xf:itemset>
		</xf:select1>
		<html:br/>
    <xf:group appearance="minimal">
      <xf:submit ref="instance('{$instance-id}-ui')/writable" 
        submission="{$instance-id}-save"
        id="{$control-id}-save">
        <xf:label>Save</xf:label>
      </xf:submit>
      <xf:trigger id="{$control-id}-cancel">
        <xf:label>Cancel</xf:label>
        {(: By default, the cancel button does nothing! You need to catch its event! :) ()}
      </xf:trigger>
    </xf:group>
    {controls:error-report(concat($instance-id, '-error'))}
	</xf:group>
};

(:~ read-only table UI 
 : @param $list-instance-id Instance id from list-instance()
 : @param $control-id Name of control
 :)
declare function contributors:list-table-ui(
	$list-instance-id as xs:string,
	$control-id as xs:string) 
	as element()+ {
	contributors:list-table-ui($list-instance-id, $control-id, false(), ())
};

(:~ table UI.  
 : @param $editable true() if editing is allowed, false() if not
 : @param $event-target The control that receives events
 :)
declare function contributors:list-table-ui(
	$list-instance-id as xs:string,
	$control-id as xs:string,
	$editable as xs:boolean,
	$event-target as xs:string?) 
	as element()+ {
	(
  <xf:group ref="instance('{$list-instance-id}')">{
    if ($contributors:use-real-table)
    then
      <html:table id="{$control-id}" class="list">
        <html:tr>
          <html:th>Wiki name</html:th>
          <html:th>Real name</html:th>
          <html:th>Affiliation</html:th>
          <html:th>Email</html:th>
          <html:th>Web page</html:th>
          {
          if ($editable)
          then 
            <html:th>Editing</html:th>
          else ()
          }
        </html:tr>
        <html:tbody
          id="{$control-id}-repeat" 
          xf:repeat-nodeset="instance('{$list-instance-id}')/tei:item">
          <html:tr>
            <html:td>
              <xf:output ref="@xml:id"/>
            </html:td>
            <html:td>
              <xf:output ref="tei:orgName"/>
              <xf:output ref="tei:name"/>
            </html:td>
            <html:td>
              <xf:output ref="../tei:item[@xml:id=substring-after(current()/tei:affiliation/tei:ptr/@target, '#')]/tei:orgName"/>
            </html:td>
            <html:td>
              <xf:output ref="tei:email"/>
            </html:td>
            <html:td>
              <xf:output ref="tei:ptr[@type='url']/@target"/>
            </html:td>
            {
            if ($editable and false())
            then ( 
              <html:td>
                <xf:trigger id="{$control-id}-edit">
                  <xf:label>Edit</xf:label>
                  <xf:dispatch ev:event="DOMActivate" name="edit" targetid="{$event-target}"/>
                </xf:trigger>
                <xf:trigger id="{$control-id}-edit">
                  <xf:label>Delete</xf:label>
                  <xf:action ev:event="DOMActivate">
                    <xf:dispatch name="delete" targetid="{$event-target}"/>
                  </xf:action>
                </xf:trigger>
              </html:td>
            )
            else ()
            }
          </html:tr>
        </html:tbody>
      </html:table>
    else (: don't use real table :)
      (
      controls:faketable-style($control-id, 100, if ($editable) then 6 else 5),
      if ($editable)
      then
        <xf:trigger id="{$control-id}-new">
          <xf:label>Add new contributor entry</xf:label>
          <xf:dispatch ev:event="DOMActivate" name="new" targetid="{$event-target}"/>
        </xf:trigger>
      else (),
      <html:div class="{$control-id}-table">
        <html:div class="{$control-id}-header {$control-id}-row">
          <html:div class="{$control-id}-column">Wiki name</html:div>
          <html:div class="{$control-id}-column">Real name</html:div>
          <html:div class="{$control-id}-column">Affiliation</html:div>
          <html:div class="{$control-id}-column">Email</html:div>
          <html:div class="{$control-id}-column">Web page</html:div>
          {
          if ($editable)
          then 
            <html:div class="{$control-id}-column">Editing</html:div>
          else ()
          }
        </html:div>
        <xf:repeat ref="instance('{$list-instance-id}')" 
          id="{$control-id}-repeat" nodeset="instance('{$list-instance-id}')/tei:item">
          <html:div class="{$control-id}-row">
            <html:div class="{$control-id}-column">
              <xf:output ref="@xml:id"/>
            </html:div>
            <html:div class="{$control-id}-column">
              <xf:output ref="tei:orgName"/>
              <xf:output ref="tei:name"/>
            </html:div>
            <html:div class="{$control-id}-column">
              <xf:output ref="../tei:item[@xml:id=substring-after(current()/tei:affiliation/tei:ptr/@target, '#')]/tei:orgName"/>          
            </html:div>
            <html:div class="{$control-id}-column">
              <xf:output ref="tei:email"/>
            </html:div>
            <html:div class="{$control-id}-column">
              <xf:output ref="tei:ptr[@type='url']/@target"/>
            </html:div> 
            {
            if ($editable)
            then 
              <html:div class="{$control-id}-column">
                <xf:group appearance="minimal">
                  <xf:trigger id="{$control-id}-edit">
                    <xf:label>Edit</xf:label>
                    <xf:dispatch ev:event="DOMActivate" name="edit" targetid="{$event-target}"/>
                  </xf:trigger>
                  <xf:trigger id="{$control-id}-delete">
                    <xf:label>Delete</xf:label>
                    <xf:action ev:event="DOMActivate">
                      <xf:dispatch name="delete" targetid="{$event-target}"/>
                    </xf:action>
                   </xf:trigger>
                </xf:group>
              </html:div>
            else ()
            }
          </html:div>
        </xf:repeat>
      </html:div>
      )
  }</xf:group>
  )
};

(:~ editor UI.  
 : Accepts events: new, edit, delete, off, xforms-submit-done, xforms-submit-error 
 : @param $repeat-control-id control that has the repeat that
 : 	determines which id is edited 
 :)
declare function contributors:editor-ui(
	$instance-id as xs:string,
	$list-instance-id as xs:string,
	$control-id as xs:string,
	$repeat-control-id as xs:string) 
	as element(xf:group) {
	<xf:group id="{$control-id}">
		<!-- This group responds to actions triggered -->
		<xf:action ev:event="new">
      {controls:clear-error(concat($instance-id,'-error'))}
			<xf:setvalue ref="instance('{$instance-id}-ui')/editing/is-new">true</xf:setvalue>
			<xf:setvalue ref="instance('{$instance-id}-ui')/editing/current-id">new</xf:setvalue>
			<xf:setvalue ref="instance('{$instance-id}-ui')/editing/original-id">new</xf:setvalue>
			<xf:setvalue ref="instance('{$instance-id}-ui')/editing/unique">false</xf:setvalue>
			<xf:insert origin="instance('{$list-instance-id}-prototype')/tei:item"
				nodeset="instance('{$instance-id}')/tei:item"
				at="1" 
				position="before"/>
			<xf:delete nodeset="instance('{$instance-id}')/tei:item[last()]"/>
			<xf:toggle case="{$control-id}-edit"/>
			<xf:setfocus control="{$control-id}"/>
		</xf:action>

		<xf:action ev:event="edit">
      {controls:clear-error(concat($instance-id,'-error'))}
			<xf:insert origin="instance('{$list-instance-id}')/tei:item[index('{$repeat-control-id}-repeat')]"
				nodeset="instance('{$instance-id}')/tei:item"
				at="1" 
				position="before"/>
			<xf:delete nodeset="instance('{$instance-id}')/tei:item[last()]"/>

			<xf:setvalue ref="instance('{$instance-id}-ui')/editing/is-new">false</xf:setvalue>
			<xf:setvalue ref="instance('{$instance-id}-ui')/editing/current-id"
				value="instance('{$instance-id}')/tei:item/@xml:id"
				/>
			<xf:setvalue ref="instance('{$instance-id}-ui')/editing/original-id"
				value="instance('{$instance-id}')/tei:item/@xml:id"
				/>
			<xf:setvalue ref="instance('{$instance-id}-ui')/editing/unique">true</xf:setvalue>

			<xf:toggle case="{$control-id}-edit"/>
			<xf:setfocus control="{$control-id}-ui"/>
		</xf:action>

		<xf:action ev:event="delete">
      {controls:clear-error(concat($instance-id,'-error'))}
			<xf:setvalue ref="instance('{$instance-id}-ui')/delete/id" 
				value="instance('{$list-instance-id}')/tei:item[index('{$repeat-control-id}-repeat')]/@xml:id"/>
			<xf:toggle case="{$control-id}-delete"/>
			<xf:setfocus control="{$control-id}-ui"/>
		</xf:action>

		<xf:action ev:event="off">
			<xf:toggle case="{$control-id}-off"/>
      {controls:clear-error(concat($instance-id,'-error'))}
		</xf:action>

		<xf:action ev:event="xforms-submit-done">
			<!--xf:send submission="{$list-instance-id}-load"/-->
			<xf:toggle case="{$control-id}-off"/>
      {controls:clear-error(concat($instance-id,'-error'))}
		</xf:action>

		<!--xf:toggle ev:event="xforms-submit-error" case="{$control-id}-failure"/-->
		
		<!-- the UI is here -->
		<xf:switch>
			<xf:case id="{$control-id}-off"/>
			<xf:case id="{$control-id}-edit">
				{
				contributors:individual-entry-ui(
					$instance-id, $list-instance-id,
					concat($control-id,'-ui'), ())
        (: if the cancel button is pressed, turn off the control :)
				}
				<xf:action ev:event="DOMActivate" ev:observer="{$control-id}-ui-cancel">
					<xf:dispatch name="off" targetid="{$control-id}" />
				</xf:action>
			</xf:case>
			<xf:case id="{$control-id}-delete">
        <html:div id="{$control-id}-delete-ui">
          <xf:group ref="instance('{$list-instance-id}')/tei:item[index('{$repeat-control-id}-repeat')]">
            <html:p>Confirm deletion of contributor record for: <xf:output ref="tei:name"/> (<xf:output ref="instance('{$instance-id}-ui')/delete/id"/>)?</html:p>
          </xf:group>
          <xf:submit submission="{$instance-id}-delete">
            <xf:label>Delete</xf:label>
            <!--xf:toggle ev:event="DOMActivate" case="{$control-id}-off"/-->
          </xf:submit>
          <xf:trigger>
            <xf:label>Cancel</xf:label>
            <xf:action ev:event="DOMActivate">
              <xf:toggle case="{$control-id}-off"/>
            </xf:action>
          </xf:trigger>
          {controls:error-report(concat($instance-id, '-error'))}
        </html:div>
			</xf:case>
		</xf:switch>
	</xf:group>
};

(:~ user interface for searching :)
declare function contributors:search-ui(
	$query-instance-id as xs:string,
	$results-instance-id as xs:string,
	$control-id as xs:string) 
	as element(xf:group) {
	<xf:group id="{$control-id}" appearance="compact">
		<xf:group ref="instance('{$query-instance-id}')" appearance="minimal">
			<xf:input ref="q">
				<xf:label>Search term: </xf:label>
			</xf:input>
			<xf:submit submission="{$query-instance-id}-search">
				<xf:label>Search</xf:label>
			</xf:submit>
		</xf:group>
    {controls:error-report(concat($query-instance-id, '-error'))}
		<xf:group ref="instance('{$results-instance-id}')">
			<xf:label>Search results</xf:label>
			{contributors:list-table-ui($results-instance-id, concat($control-id, '-results'))}
		</xf:group>
	</xf:group>
	
};
