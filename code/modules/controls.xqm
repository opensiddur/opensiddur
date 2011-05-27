(: XForms common controls library
 :
 : Open Siddur Project
 : Copyright 2010-2011 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Released under the GNU Lesser General Public License, ver 3 or later
 : $Id: controls.xqm 772 2011-04-29 05:34:57Z efraim.feinstein $
 :)
xquery version "1.0";
module namespace controls="http://jewishliturgy.org/modules/controls";

import module namespace app="http://jewishliturgy.org/modules/app" 
	at "app.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "paths.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace html="http://www.w3.org/1999/xhtml"; 
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace xrx="http://jewishliturgy.org/ns/xrx";
declare namespace err="http://jewishliturgy.org/errors";

declare variable $controls:code-tables-path := '/code/modules/code-tables';

(:~ error control for handling errors that come from fn:error() 
 : This should be placed inside an xf:action that handles the error :)
declare function controls:submit-error-handler-action() 
	as element(xf:message) {
	<xf:message level="modal">
An error occurred while submitting.  Check that all required values are entered.
Type: <xf:output value="event('error-type')"/> HTTP status code: (<xf:output value="event('response-status-code')"/>)
Error message: <xf:output value="event('response-reason-phrase')"/>
	</xf:message> 
};

(:~ output a language selector instance :)
declare function controls:language-selector-instance(
	$instance-id as xs:string
	) as element()+ {
	<xf:instance id="{$instance-id}" 
		src="{app:concat-path($controls:code-tables-path, 'languages.xml')}"/>
};

(:~ Language selector control
 : @param $control-id File-unique control identifier
 : @param $code-table-instance-id id of language-selector-instance()
 : @param $label Text to show to user
 : @param $ref XPath to instance needing language selection (relative to current group) 
 : @param $bind If true(), the $ref is a bind, otherwise, it's a ref
 :)
declare function controls:language-selector-ui(
	$control-id as xs:string,
	$code-table-instance-id as xs:string,
	$label as item()?,
	$ref as xs:string, 
	$bind as xs:boolean) 
	as element() {
	<div class="language-selector control">
		<xf:select1 id="{$control-id}" incremental="true">
			{
				attribute {if ($bind) then 'bind' else 'ref'}{$ref}
			}
			{
			if ($label)
			then
				<xf:label>{$label}</xf:label>
			else ()
			}
			<xf:itemset nodeset="{controls:instance-to-ref($code-table-instance-id,'language')}">
      	<xf:value ref="code" />
        <xf:label ref="desc" />
    	</xf:itemset>
		</xf:select1>
	</div>
};

(:~ string input with language selector
 : @param $label Label for the control
 : @param $lang-label Label for language entry
 : @param $lang-bind if this parameter is nonempty, both $ref and $lang-bind are
 : 	interpreted as binds instead of refs, otherwise the language is assumed to be $ref/@xml:lang
 :)
declare function controls:string-input-with-language-ui(
	$control-id as xs:string,
	$language-code-table-instance-id as xs:string,
	$label as item()?,
	$lang-label as item()?,
	$ref as xs:string,
	$lang-bind as xs:string?
	) as element()+ {
	<div class="string-input-with-language control">
		<xf:group id="{$control-id}">
			{
			if ($label)
			then
				<xf:label>{$label}</xf:label>
			else (),
			controls:language-selector-ui(
				concat($control-id,'-language-selector'),
				$language-code-table-instance-id,
				$lang-label,
				($lang-bind, concat($ref, '/@xml:lang'))[1],
				exists($lang-bind) )}
			<xf:input id="{$control-id}-input" incremental="true">{
				attribute { if (exists($lang-bind)) then 'bind' else 'ref' }{$ref}
			}</xf:input>
		</xf:group>
	</div>
};

(: ordered list control with +/-/up/down buttons :)
(:~ This function goes in the xf:model section for each control and generates a prototype 
 : instance
 : @param $instance-id instance that holds the actual list content
 : @param $instance-container container element of the prototype
 :)
declare function controls:ordered-list-instance(
	$instance-id as xs:string,
	$instance-container as element()) 
	as element()+ {
	(
	<xf:instance id="{$instance-id}-prototype">
		{$instance-container}
	</xf:instance>
	)
};

(:~ insert actions to insert a new item from a prototype into an empty ordered list
 : @param $instance-id the instance given to ordered-list-instance()
 : @param $ref reference to containing element of ordered list (same level as the prototype)
 :)
declare function controls:ordered-list-insert-empty(
	$instance-id as xs:string,
	$ref as xs:string
	) as element()+ {
	<xf:insert 
		origin="instance('{$instance-id}-prototype')" 
		nodeset="{$ref}" at="1" position="before"/>,
	<xf:delete nodeset="{$ref}" at="last()"/>
};

declare function controls:ordered-list-ui(
	$instance-id as xs:string,
	$control-id as xs:string,
	$legend as xs:string,
	$ref as xs:string,
	$individual-ui as item()+) as 
	element(fieldset) {
	controls:ordered-list-ui($instance-id, $control-id, $legend, $ref, 
		$individual-ui, (), (), ())
};

declare function controls:ordered-list-ui(
	$instance-id as xs:string,
	$control-id as xs:string,
	$legend as xs:string,
	$ref as xs:string,
	$individual-ui as item()+,
	$self-ref as xs:string?)
	as element() {
	controls:ordered-list-ui($instance-id, $control-id, $legend, $ref, 
		$individual-ui, $self-ref, (), ())
};

(:~ return the repeat id of a given ordered list control :)
declare function controls:ordered-list-repeat-id(
	$control-id as xs:string
	) as xs:string {
	concat($control-id, '-repeat')
};


(:~ This function is called in place of the UI
 : @param $instance-id Identifier of instance the control is a list of (same as in ordered-list-instance)
 : @param $control-id Unique identifier of the control
 : @param $legend UI-visible title of the control (empty for none)
 : @param $ref [relative] XPath to the elements the control represents
 : @param $individual-ui UI elements that make up each control 
 : @param $self-ref XPath that defines the nodes in the node set relative
 : 	to themselves; only needed when the nodeset is not in its own instance
 : @param $allow-remove-last if true(), allow the last element of the nodeset to be removed
 :	(default is false)
 : @param $event-target Target for up, down, plus, and minus events, which occur when the 
 :	buttons are pressed. If given, the default actions do not occur.
 :)
declare function controls:ordered-list-ui(
	$instance-id as xs:string,
	$control-id as xs:string,
	$legend as xs:string,
	$ref as xs:string,
	$individual-ui as item()+,
	$self-ref as xs:string?,
	$allow-remove-last as xs:boolean?,
	$event-target as xs:string*
	) as element(fieldset) {
	
	let $self-ref-string :=
		if ($self-ref)
		then concat('[', $self-ref, ']')
		else ''
	return
	<fieldset id="{$control-id}">
		{if ($legend)
		then <legend>{$legend}</legend>
		else ()}
		<xf:repeat id="{controls:ordered-list-repeat-id($control-id)}" number="5" nodeset="{$ref}">
			<fieldset>
				<div class="repeat-individual-ui">
					{$individual-ui}
				</div>
				<div class="repeat-buttons">
					<div class="repeat-button">
						<xf:trigger id="{$control-id}-insert">
		      		<xf:label>+</xf:label>
		      		<xf:action ev:event="DOMActivate">
		      			{
		      			if (exists($event-target))
		      			then
		      				for $et in $event-target
		      				return <xf:dispatch name="plus" targetid="{$et}"/>
		      			else
		      				<xf:insert origin="instance('{$instance-id}-prototype')/container"
		        			nodeset="."
		          		at="1"
		          		position="after"/>
		      			}
		      		</xf:action>
		    		</xf:trigger>
		    	</div>
		    	<div class="repeat-button">
						<xf:trigger id="{$control-id}-remove" 
							ref="self::node(){ if ($allow-remove-last) then () else '[count(../*{$self-ref-string}) &gt; 1]'}">
				    	<xf:label>-</xf:label>
				    	<xf:action ev:event="DOMActivate" ><!--if="count({$ref}) &gt; 1"-->
				    		{
				    		if (exists($event-target))
		      			then
		      				for $et in $event-target
		      				return <xf:dispatch name="minus" targetid="{$et}"/>
		      			else
		      				<xf:delete nodeset="." />
		      			}
				   		</xf:action>
				    </xf:trigger>
				  </div>
				  <div class="repeat-button">
						<xf:trigger id="{$control-id}-up" 
							ref="preceding-sibling::*[1]{$self-ref-string}">
				    	<xf:label>&#9650;</xf:label>
				     	<xf:action ev:event="DOMActivate">
				     		{
				     		if (exists($event-target))
		      			then
		      				for $et in $event-target
		      				return <xf:dispatch name="up" targetid="{$et}"/>
		      			else (
		      				<xf:insert
				      			origin="." 
				      			nodeset="following-sibling::*[1]"
				      			at="1"
				      			position="after"/>,
				      		<xf:delete nodeset="."/>
		      			)
		      			}
				     	</xf:action>
				    </xf:trigger>
				  </div>
				  <div class="repeat-button">
				    <xf:trigger id="{$control-id}-down" 
				    	ref="following-sibling::*[1]{$self-ref-string}">
				    	<xf:label>&#9660;</xf:label>
				     	<xf:action ev:event="DOMActivate">
				     		{
		      			if (exists($event-target))
		      			then
		      				for $et in $event-target
		      				return <xf:dispatch name="down" targetid="{$et}"/>
		      			else (
		      				<xf:insert
				      			origin="." 
				      			nodeset="preceding-sibling::*[1]"
				      			at="1"
				      			position="before"/>,
				      		<xf:delete nodeset="."/>
				      	)
		      			}
							</xf:action>
				  	</xf:trigger>
				  </div>
				</div>
			</fieldset>
		</xf:repeat>
	</fieldset>
};


(:~ make a control collapsible
 : @param $control-id The control's name
 : @param $case-if-deselected Control content when closed/collapsed
 : @param $case-if-selected Control content when opened
 :)
declare function controls:collapsible(
	$control-id as xs:string,
	$case-if-deselected as item()+,
	$case-if-selected as item()+
	) as element(xf:switch) {
	<xf:switch id="{$control-id}">
		<xf:case id="{$control-id}-closed">
			<xf:trigger id="{$control-id}-toggle-open">
				<xf:label>Expand &gt;&gt;</xf:label>
				<xf:action ev:event="DOMActivate">
					<xf:toggle case="{$control-id}-open"/>
				</xf:action>
			</xf:trigger>
			{$case-if-deselected}
		</xf:case>
		<xf:case  id="{$control-id}-open">
			<xf:trigger id="{$control-id}-close-top">
				<xf:label>&lt;&lt; Collapse</xf:label>
				<xf:action ev:event="DOMActivate">
					<xf:toggle case="{$control-id}-closed"/>
				</xf:action>
			</xf:trigger>
			{$case-if-selected}
			<xf:trigger id="{$control-id}-close-bottom">
				<xf:label>&lt;&lt; Collapse</xf:label>
				<xf:action ev:event="DOMActivate">
					<xf:toggle case="{$control-id}-closed"/>
				</xf:action>
			</xf:trigger>
			
		</xf:case>
	</xf:switch>
}; 

(:~ Instance to hold the input value for an open selection :)
declare function controls:open-selection-instance(
	$instance-id as xs:string,
	$ref as xs:string,
	$required as xs:boolean, 
	$relevant as xs:string?)
	as element()+ {
	let $relevant-attribute :=
		if ($relevant) then attribute relevant {$relevant} else ()
	return
	(
	<xf:instance id="{$instance-id}" xmlns="">{
		element {$instance-id}{}
	}</xf:instance>,
	if ($required)
	then (
		<xf:bind nodeset="instance('{$instance-id}')" required="{$ref} = ''">{
			$relevant-attribute
		}</xf:bind>,
		<xf:bind nodeset="{$ref}" required="instance('{$instance-id}') = ''">{
			$relevant-attribute
		}</xf:bind>
	)
	else ()
	)
};

(:~ open selection control, useful until XSLTForms supports 
 : xf:select1/@selection='open'
 : @param $instance-id Identifier of temporary instance used to hold the input value 
 : @param $control-id Identifier of the control
 : @param $ref Reference to what element the control fills in, relative
 :	to the current context.
 : @param $label Global label
 : @param $label-if-new Label for the input entry
 : @param $label-if-listed Label for the selection entry 
 : @param $selection-items xf:item or xf:itemset of items for the selection
 :)
declare function controls:open-selection-ui(
	$instance-id as xs:string,
	$control-id as xs:string,
	$ref as xs:string,
	$label as xs:string,
	$label-if-new as item()+,
	$label-if-listed as item()+,
	$selection-items as node()+
	) as element(xf:group) {
	<xf:group id="{$control-id}">
		<fieldset>
			<legend>{$label}</legend>
			<xf:select1 ref="{$ref}" incremental="true" id="{$control-id}-selection"
				selection="open">
				<xf:label>{$label-if-listed}</xf:label>
				{$selection-items}
				<xf:action ev:event="xforms-value-changed">
					<xf:setvalue ref="instance('{$instance-id}')" value="{$ref}"/>
				</xf:action>
			</xf:select1>
			<xf:input ref="instance('{$instance-id}')" 
				id="{$control-id}-input"
				incremental="true">
				<xf:label>{$label-if-new}</xf:label>
				<xf:action ev:event="DOMFocusOut">
					<xf:setvalue ref="{$ref}" value="instance('{$instance-id}')"/>
				</xf:action>
			</xf:input>
		</fieldset>
	</xf:group>
};

(:~ Create a wizard.  Each item contains one step in 
 : the wizard.
 : @param $control-id Identifier of wizard
 : @param $steps Content of each step, in order of appearance.
 : @param $step-actions Additional actions to do on pressing Next or Finish.
 : 	Use a blank <null/> as a placeholder. 
 : @param $step-next-refs references for the relative to the context of the wizard.
 :	Use a blank string as a placeholder 
 : @param $step-ids Identifiers of the steps.  
 : 	If a given identifier is not present or an empty string, {$control-id}-stepN is used, where
 :  N is a one-based integer.
 : @param $start-step First step to show.  Defaults to step1
 :)
declare function controls:wizard(
	$control-id as xs:string,
	$steps as element()+,
	$step-actions as element()*,
	$step-next-refs as xs:string*,
	$step-ids as xs:string*,
	$start-step as xs:string?) 
	as element()+ {
	(
	let $control-step-ids :=
		for $step at $pos in $steps
		return
			if ($step-ids[$pos]) (: catch both empty string and empty sequence :)
			then $step-ids[$pos] 
			else concat($control-id, '-', 'step', string($pos))
	return 
	<xf:switch id="{$control-id}">{
		for $step at $pos in $steps
		return
			<xf:case 
				id="{$control-step-ids[$pos]}">{
				if ($start-step eq $control-step-ids[$pos])
				then attribute selected {'true'}
				else (),
				$step,
				<br/>,
				if ($pos gt 1)
				then
					<xf:trigger id="{$control-id}-step{$pos}-prev">
						<xf:label>&lt;&lt; Prev</xf:label>
						<xf:action ev:event="DOMActivate">
							<xf:toggle case="{($control-step-ids[$pos - 1])}"/>
						</xf:action>
					</xf:trigger>
				else (),
				<xf:trigger id="{$control-id}-step{$pos}-next">{
					if ($step-next-refs[$pos])
					then attribute ref {$step-next-refs[$pos]}
					else ()}
					<xf:label>{
					if ($pos eq count($steps))
					then 'Finish'
					else 'Next &gt;&gt;'
					}</xf:label>
					<xf:action ev:event="DOMActivate">
						{if ($step-actions[$pos] and not($step-actions[$pos][self::null])) 
						then $step-actions[$pos]
						else (),
						if ($pos eq count($steps))
						then ()
						else
							<xf:toggle case="{($control-step-ids[$pos + 1])}"/>
					}
					</xf:action>
				</xf:trigger>
			}</xf:case>
	}</xf:switch>
	)
};

(:~ generate reporter section to report submission errors 
 : @param $control-id Identifier of control, used as $event-target in 
 : instances
 : @param $if-success XML to show if successful
 : @param $if-fail XML to show if failed  
 :) 
declare function controls:reporter(
	$control-id as xs:string,
	$if-success as item()+,
	$if-fail as item()+
	) as element(xf:group) {
	<xf:group id="reporter">
		<xf:toggle ev:event="xforms-submit-error" case="{$control-id}-error"/>
		<xf:toggle ev:event="xforms-submit-done" case="{$control-id}-success"/>
		<xf:switch> 
			<xf:case id="{$control-id}-none"/>
			<xf:case id="{$control-id}-success">{$if-success}</xf:case>
			<xf:case id="{$control-id}-error">{$if-fail}</xf:case>
		</xf:switch>
	</xf:group>
};

(:~ insert declaration that checks for returned errors in a submission
 : @param $instance-id reply instance from the submission
 : @param $error-actions actions that should be done on error return
 : @param $success-actions actions that should be done on successful return
 :)
declare function controls:return-action(
	$instance-id as xs:string,
	$error-actions as element()*,
	$success-actions as element()*
	) as element()+ {
	if (exists($error-actions))
	then
		<xf:action ev:event="xforms-submit-done" if="count(instance('{$instance-id}')/exception) &gt;= 1">
			{$error-actions}
		</xf:action>
	else (),
	if (exists($success-actions)) 
	then
		(: need an xpath 1.0 compatible way to say exists() :)
		<xf:action ev:event="xforms-submit-done" if="count(instance('{$instance-id}')/exception)=0">
			{$success-actions}
		</xf:action>
	else ()
}; 

(:~ add the CSS code for a fake table being used in the given control 
 : fake tables code based on http://css-lab.com/demos/4col/4col-table.html  
 : @param $control-id Identifier of the control where the table is
 : @param $width-pct total width of the table in percent of the available area
 : @param $number-of-columns number of columns in the table 
 :)
declare function controls:faketable-style(
  $control-id as xs:string,
  $width-pct as xs:integer,
  $number-of-columns as xs:integer) 
  as element(style) {
  <style type="text/css">{
  string-join(("",
    concat(".", $control-id, "-table .xfRepeatItem {"),
    "padding:0;",
    "}",
    concat(".", $control-id, "-table {"),
    concat("width:", string($width-pct) ,"%;"),
    "};",
    concat(".",$control-id,"-header {"),
    "font-weight:bold;",
    "}",
    concat(".",$control-id,"-row {"),
  	concat("width:", string($width-pct), "%;"),
  	"color:#000;",
	  "border:1px solid #000;",
  	(:"border-bottom:none;",:)
  	"margin-top: 0;",
    "margin-bottom: 0;",
    "padding-top: 0;",
    "padding-bottom: 0;",
	  (:"padding:5px 0;",:)
  	"overflow:hidden;",
  	"position:relative;",
    "}",
    concat(".", $control-id, "-column {"),
  	concat("width:", string(floor($width-pct div $number-of-columns) - 2),"%;"), 
  	"float:left;",
	  "padding:1%;",
  	"position:relative;",
  	(:"z-index:2;",:)
    "}"),'&#x0a;')
  }</style>
};

declare function controls:error-instance(
	$instance-id as xs:string
	) as element()+ {
	controls:error-instance($instance-id, ())
};

(:~ instance intended to accept error reports 
 : @param $instance-id The instance id of the error
 : @param $invalid-error What to do when the data is invalid. If not specified, a default
 :	message is used.
 :)
declare function controls:error-instance(
  $instance-id as xs:string, 
  $invalid-error as element(exception)?
  ) as element()+ {
  (
  <xf:instance id="{$instance-id}">
    <error xmlns=""/>
  </xf:instance>,
  <xf:instance id="{$instance-id}-generic">
    <error xmlns="">
    	<type/>
    	<uri/>
    	<code/>
    	<phrase/>
    	<path/>
    	<body>
    		<content>An unknown error occurred during submission. Most likely a bug.</content>
    	</body>
    </error>
  </xf:instance>,
  <xf:instance id="{$instance-id}-invalid">
		<error xmlns="">{
			($invalid-error, 
			<exception>Some form data is invalid. Make sure all required elements are filled out and there are no error hints shown.</exception>
			)[1]
		}</error>
	</xf:instance>
  )
};

(:~ convert an instance and path into a reference string
 : @param $instance-id instance id
 : @param $ref Reference within the instance
 :) 
declare function controls:instance-to-ref(
	$instance-id as xs:string,
	$ref as xs:string?
	) as xs:string {
	let $instance-path := concat("instance('", $instance-id, "')")
	return
		concat($instance-path, 
			if (not($ref) or starts-with($ref, '/')) 
			then '' 
			else '/',
			$ref
			) 
};

declare function controls:instance-to-ref(
	$instance-id as xs:string
	) as xs:string {
	controls:instance-to-ref($instance-id, ())
};


(:~ action to clear an error instance :)
declare function controls:clear-error(
  $error-instance-id as xs:string
  ) as element() {
  <xf:delete nodeset="instance('{$error-instance-id}')/*" />
};

(:~ common responses to a submissions.  
 : Check for errors.  If an error occurred, move it to $error-instance-id, and convert the form response  
 : @param $error-instance-id Instance id of instance that holds errors
 : @param $event-target Id(s) of target that should receive events
 : @param $success-actions Additional actions that should be done on success
 :)
declare function controls:submission-response(
  $error-instance-id as xs:string,
  $event-target as xs:string*,
  $success-actions as element()*
  ) as element()+ {
  (
  (: delete any errors before submitting :)
  <xf:delete ev:event="xforms-submit" nodeset="instance('{$error-instance-id}')/*" />,
  (: no errors. clear error reporting instance, do success actions, and dispatch to the event target :)
  <xf:action ev:event="xforms-submit-done">
    <xf:delete nodeset="instance('{$error-instance-id}')/*" />
    {$success-actions,
    for $e-target in $event-target
    return <xf:dispatch name="xforms-submit-done" targetid="{$e-target}"/>
    }
  </xf:action>,
  (: validation error, if treated separately :)
  <xf:action ev:event="xforms-submit-error" if="event('error-type')='validation-error'">
    <xf:delete nodeset="instance('{$error-instance-id}')/*" />
    <xf:insert nodeset="instance('{$error-instance-id}')" 
			origin="instance('{$error-instance-id}-invalid')" />
    {
    for $e-target in $event-target
    return <xf:dispatch name="xforms-submit-error" targetid="{$e-target}"/>
    }
  </xf:action>
  ,
  (: other submission error :)
  <xf:action ev:event="xforms-submit-error" if="not(event('error-type')='validation-error')">
    <xf:delete nodeset="instance('{$error-instance-id}')/*" />
    <xf:insert origin="instance('{$error-instance-id}-generic')" 
    	nodeset="instance('{$error-instance-id}')"/>
    <xf:setvalue ref="instance('{$error-instance-id}')/type" value="event('error-type')"/>
    <xf:setvalue ref="instance('{$error-instance-id}')/uri" value="event('resource-uri')"/>
    <xf:setvalue ref="instance('{$error-instance-id}')/code" value="event('response-status-code')"/>
    <xf:setvalue ref="instance('{$error-instance-id}')/phrase" value="event('response-reason-phrase')"/>
    <xf:setvalue ref="instance('{$error-instance-id}')/*/path" 
    	value="event('response-body')/path"/>
    <xf:setvalue ref="instance('{$error-instance-id}')/body" 
    	value="event('response-body')/*/message"/>
    {
    for $e-target in $event-target
    return <xf:dispatch name="xforms-submit-error" targetid="{$e-target}"/>
    }
  </xf:action>
  )
};

(:~ error display from an error instance :)
declare function controls:error-report(
  $error-instance-id as xs:string
  ) as element() {
  <xf:group ref="instance('{$error-instance-id}')/uri[not(.='')]/..">
    <span class="error-report">
    	<xf:output ref="uri"/>: <xf:output ref="phrase"/> (<xf:output ref="type"/>:<xf:output ref="code"/>)
      <xf:output ref="body"/>
    </span>
  </xf:group>
}; 

declare function controls:validator-instance-id(
	$control-id as xs:string
	) as xs:string {
	concat($control-id, '-validator')
};

(:~ validator instance with no target :)
declare function controls:validator-instance(
	$control-id as xs:string,
	$instance-ref as xs:string,
	$validator-url as xs:anyURI
	) as element()+ {
	controls:validator-instance($control-id, $instance-ref, $validator-url, ())
};

(:~ make a validator instance for a given control 
 : @param $control-id Control that is being validated
 : @param $instance-ref Reference to instance that is being validated
 : @param $validator-url Path to the query that checks validity
 : @param $event-target identifier(s) of the control that receives the event
 :
 : The control dispatches the following events: validator-ok, validator-warning, 
 : 	validator-error, xforms-submit-error (eg, error in path or XQuery) 
 :)
declare function controls:validator-instance(
	$control-id as xs:string,
	$instance-ref as xs:string,
	$validator-url as xs:anyURI,
	$event-target as xs:string*
	) as element()+ {
	(: the validator instance holds the result of the validation: 
	 : according to the validator protocol, it may be:
	 : <ok/>
	 : <warn type="">warning text</warn>
	 : <error type="">error text</error>
	 :)
	let $validator-instance := controls:validator-instance-id($control-id)
	let $validator-result := concat($validator-instance, '-result')
	let $validator-input := concat($validator-instance, '-input')
	return (
		<xf:instance id="{$validator-result}">
			<ok xmlns=""/>
		</xf:instance>,
		<xf:instance id="{$validator-instance}">
			<flag xmlns="">
				<valid>true</valid>
			</flag>
		</xf:instance>,
		<xf:submission id="{$validator-instance}-submit"
			ref="{$instance-ref}"
			replace="instance"
			instance="{$validator-result}"
			method="post"
			action="{$validator-url}"
			validate="false">
			<xf:action ev:event="xforms-submit-error">
				<xf:setvalue ref="instance('{$validator-instance}')/valid" value="'false'"/>
				{
				for $e-target in $event-target
				return
					<xf:dispatch name="xforms-submit-error" targetid="{$e-target}"/>
				}
			</xf:action>
			<xf:action ev:event="xforms-submit-done" if="instance('{$validator-result}')/ok">
				<xf:setvalue ref="instance('{$validator-instance}')/valid" value="'true'"/>
				{
				for $e-target in $event-target
				return
					<xf:dispatch name="validator-ok" targetid="{$e-target}"/>
				}
			</xf:action>
			<xf:action ev:event="xforms-submit-done" if="instance('{$validator-result}')/warn">
				<xf:setvalue ref="instance('{$validator-instance}')/valid" value="'true'"/>
				{
				for $e-target in $event-target
				return
					<xf:dispatch name="validator-warning" targetid="{$e-target}"/>
				}
			</xf:action>
			<xf:action ev:event="xforms-submit-done" if="instance('{$validator-result}')/error">
				<xf:setvalue ref="instance('{$validator-instance}')/valid" value="'false'"/>
				{
				for $e-target in $event-target
				return
					<xf:dispatch name="validator-error" targetid="{$e-target}"/>
				}
			</xf:action>
		</xf:submission>
	)
};

(:~ constraint attribute for binding 
 :)
declare function controls:validator-constraint(
	$control-id as xs:string
	) as attribute() {
	attribute {'constraint'}{ concat('instance("', $control-id, '-validator-flag")/valid = "true"') }
};

(:~ make a validator instance for a given control that uses GET which either returns
 : 2?? or 4?? 
 : @param $control-id Control that is being validated
 : @param $instance-ref Reference to instance that is being validated
 : @param $validator-action Action that checks validitity (@action, xf:resource)
 : @param $validation-direction If true() then, 4?? indicates error and 2?? indicates success. if false(), the opposite
 : @param $event-target identifier(s) of the control that receives the event
 :
 : The control dispatches the following events: validator-ok, validator-warning, 
 : 	validator-error, xforms-submit-error (eg, error in path or XQuery) 
 :)
declare function controls:validator-instance-get(
	$control-id as xs:string,
	$instance-ref as xs:string,
	$validator-action as node(),
	$validation-direction as xs:boolean,
	$event-target as xs:string*
	) as element()+ {
	(: the validator instance may hold an error 
	 :)
	let $validator-instance := controls:validator-instance-id($control-id)
	let $validator-result := concat($validator-instance, '-result')
	let $validator-input := concat($validator-instance, '-input')
	let $positive-validation :=
		attribute ev:event { 'xforms-submit-done' }
	let $negative-validation := (
		attribute ev:event { 'xforms-submit-error'},
		attribute { 'if' }{ "number(event('response-status-code')) &gt;= 400 and number(event('response-status-code')) &lt; 500"}
	)
	return (
		<xf:instance id="{$validator-result}">
			<ok xmlns=""/>
		</xf:instance>,
		<xf:instance id="{$validator-instance}">
			<flag xmlns="">
				<valid>true</valid>
			</flag>
		</xf:instance>,
		<xf:submission id="{$validator-instance}-submit"
			ref="{$instance-ref}"
			replace="instance"
			instance="{$validator-result}"
			method="get"
			validate="false">
			{$validator-action}
			<xf:action ev:event="xforms-submit-error" if="number(event('response-status-code')) &gt;= 500">
				<xf:setvalue ref="instance('{$validator-instance}')/valid" value="'false'"/>
				{
				for $e-target in $event-target
				return
					<xf:dispatch name="xforms-submit-error" targetid="{$e-target}"/>
				}
			</xf:action>
			<xf:action>
				{
					if ($validation-direction)
					then $positive-validation
					else $negative-validation
				}
				<xf:setvalue ref="instance('{$validator-instance}')/valid" value="'true'"/>
				{
				for $e-target in $event-target
				return
					<xf:dispatch name="validator-ok" targetid="{$e-target}"/>
				}
			</xf:action>
			<xf:action>
				{
					if ($validation-direction)
					then $negative-validation
					else $positive-validation
				}
				<xf:setvalue ref="instance('{$validator-instance}')/valid" value="'false'"/>
				{
				for $e-target in $event-target
				return
					<xf:dispatch name="validator-error" targetid="{$e-target}"/>
				}
			</xf:action>
		</xf:submission>
	)
};

declare function controls:validator-instance-get(
	$control-id as xs:string,
	$instance-ref as xs:string,
	$validator-action as node(),
	$validation-direction as xs:boolean
	) {
	controls:validator-instance-get($control-id, $instance-ref, $validator-action, 
		$validation-direction, ())
};

(:~ Allow server side validation of a control
 : @param $control-id Control that is being validated
 : @param $instance-ref Reference into the instance that is being validated
 : @param $incremental true() if control is incremental=true
 :)
declare function controls:validate-action(
	$control-id as xs:string,
	$instance-ref as xs:string,
	$incremental as xs:boolean
	) as element()+ {
	if ($incremental)
	then
		<xf:action 
			ev:event="xforms-value-changed"
			if="string-length({$instance-ref}) &gt; 0">
			<xf:send submission="{$control-id}-validator-submit"/>
		</xf:action>
	else (),
	<xf:action 
		ev:event="DOMFocusOut"
		if="string-length({$instance-ref}) &gt; 0">
		<xf:send submission="{$control-id}-validator-submit"/>
	</xf:action>
};

(:~ license chooser instance
 : @param $required true() if the license selection is required
 :)
declare function controls:license-chooser-instance(
	$instance-id as xs:string,
	$required as xs:boolean
	) as element()+ {
	<xf:instance id="{$instance-id}-licenses" 
		src="{app:concat-path($controls:code-tables-path, 'licenses.xml')}"/>,
	(: XSLTForms doesn't support xf:copy correctly, so we have to use a workaround :)
	<xf:instance id="{$instance-id}">
		<tei:ptr type="license" target="http://www.creativecommons.org/publicdomain/zero/1.0"/>
	</xf:instance>,
	<xf:bind 
		id="{$instance-id}-bind"
		nodeset="instance('{$instance-id}')/@target"
		type="xf:string"
		required="{string($required)}()"/>
}; 

declare function controls:license-chooser-ui(
	$control-id as xs:string,
	$chooser-instance-id as xs:string,
	$label as xs:string,
	$appearance as xs:string?
	) as element()+ {
	controls:license-chooser-ui(
		$control-id, $chooser-instance-id, $label, $appearance, ()
	)
};

declare function controls:license-chooser-ui(
	$control-id as xs:string,
	$chooser-instance-id as xs:string,
	$label as xs:string,
	$appearance as xs:string?,
	$event-target as xs:string?
	) as element()+ {
  controls:license-chooser-ui($control-id, $chooser-instance-id, $label, $appearance, $event-target, false())
};

(:~ license chooser UI 
 : @param $label Label text
 : @param $appearance 'droplist' (drop down list, default),
 :		 'list' (list that shows all), 'radio' (radio buttons), '' 
 : @param $event-target target for xforms-value-changed events, to work around a bug in XSLTForms r501
 : @param $changed-value-save value changed event is the equivalent of focus out (both save)
 :)
declare function controls:license-chooser-ui(
	$control-id as xs:string,
	$chooser-instance-id as xs:string,
	$label as xs:string,
	$appearance as xs:string?,
	$event-target as xs:string?,
  $changed-value-save as xs:boolean?
	) as element()+ {
	<div class="license-chooser">
		<xf:select1 id="{$control-id}" incremental="true">
			{
			attribute {'ref'}{controls:instance-to-ref($chooser-instance-id,'@target')},
			(:attribute {if ($bind) then 'bind' else 'ref'}{$ref}:)
			attribute {'appearance'}{
				if ($appearance = 'list')
				then 'compact'
				else if ($appearance = 'radio')
				then 'full'
				else 'minimal'
				}
			}
			<xf:label>{$label}</xf:label>
			<xf:itemset nodeset="instance('{$chooser-instance-id}-licenses')/license">
				<xf:label ref="desc"/>
				<xf:value ref="id"/>
			</xf:itemset>
			{
			for $et in $event-target
			return (
				<xf:dispatch ev:event="xforms-value-changed" name="{if ($changed-value-save) then 'DOMFocusOut' else 'xforms-value-changed'}" targetid="{$et}" 
					bubbles="true"/>,
				<xf:dispatch ev:event="DOMFocusOut" name="DOMFocusOut" targetid="{$et}" 
					bubbles="true"/>
			)
			}
		</xf:select1>
	</div>
};

(:~ set a value on the license chooser from an existing value
 : @param $instance-id instance id of license chooser
 : @param $ref reference to parent of tei:availability that contains the license
 :)
declare function controls:set-license-chooser-value(
	$instance-id as xs:string,
	$ref as xs:string) 
	as element()+ {
	<xf:setvalue ref="instance('{$instance-id}')/@target"
		value="{$ref}//tei:ref[@type='license']/@target"/>
};

(:~ ok/cancel dialog. sends ok and cancel events to event-target,
 : send the control the show event to show the dialog, send it hide to hide it.
 : note: the ok button won't hide the dialog automatically
 :)
declare function controls:ok-cancel-dialog-ui(
	$control-id as xs:string,
	$content as element()+,
	$event-target as xs:string*
	) as element()+ {
	<xf:group id="{$control-id}">
		<xf:toggle ev:event="show" case="{$control-id}-show"/>
		<xf:toggle ev:event="hide" case="{$control-id}-hide"/>
		<xf:switch>
			<xf:case id="{$control-id}-show">
				<div class="dialog">
					<div class="dialog-content">
						{$content}
					</div>
					<div class="dialog-buttons">
						<xf:trigger id="{$control-id}-ok">
							<xf:label>OK</xf:label>
							<xf:action ev:event="DOMActivate">
								{
								for $et in $event-target
								return <xf:dispatch name="ok" targetid="{$et}"/>
								}
							</xf:action>
						</xf:trigger>
						<xf:trigger id="{$control-id}-cancel">
							<xf:label>Cancel</xf:label>
							<xf:action ev:event="DOMActivate">
								<xf:toggle case="{$control-id}-hide"/>
								{
								for $et in $event-target
								return <xf:dispatch name="cancel" targetid="{$et}"/>
								}
							</xf:action>
						</xf:trigger>
					</div>
				</div>
			</xf:case>
			<xf:case id="{$control-id}-hide" selected="true">
			</xf:case>
		</xf:switch>
	</xf:group>
};

(:~ return a submission id based on a binding :)
declare function controls:rt-submission-id(
	$binding as xs:string
	) as xs:string {
	concat('rt-', util:hash($binding,'md5'), '-submit')
};

declare function controls:rt-submission-get(
	$binding as xs:string
	) as xs:string {
	concat(controls:rt-submission-id($binding), '-get')
};

declare function controls:rt-submission-set(
	$binding as xs:string
	) as xs:string {
	concat(controls:rt-submission-id($binding), '-set')
};

declare function local:simulate-targetref(
	$result-instance-id as xs:string,
	$replace as xs:string,
	$targetref as xs:string
	) as node()+ {
	<xf:action ev:event="xforms-submit-done">{
		if ($replace = 'text')
		then (
			<xf:setvalue ref="{$targetref}" value="instance('{$result-instance-id}')"/>
		)
		else if ($replace = 'instance')
		then (
			<xf:insert origin="instance('{$result-instance-id}')"
				nodeset="{$targetref}" at="1" position="before" if="count({$targetref}) &gt; 0"/>,
			<xf:insert origin="instance('{$result-instance-id}')"
				context="{$targetref}" if="count({$targetref})=0"/>,
			<xf:delete nodeset="{$targetref}" at="2" if="count({$targetref}) &gt; 1"/>
		)
		else ()
	}</xf:action>
};


declare function controls:rt-submission(
	$binding as attribute(),	
	$get-action as node(),
	$put-action as node()?,
	$replace as attribute()?,
	$targetref as attribute()?, 
	$error-instance-id as xs:string?
	) {
	controls:rt-submission(
		$binding,	
		$get-action,
		$put-action,
		$replace,
		$targetref, 
		$error-instance-id, 
		()
	)
};	

(:~ 
 : submissions for real-time data
 : creates a get and set submission with ids {$binding}-submit-{get|set}
 :
 : @param $binding data that is transferred. May be @ref or @bind
 : @param $get-action may be @action, @resource or xf:resource
 : @param $put-action may be @action, @resource or xf:resource (if empty, get-action is used)
 : @param $replace replace 'all', 'instance', 'text', or 'none'
 : @param $targetref may be @targetref or @instance
 : @param $error-instance-id where to put submission errors
 : @param $rt-condition XPath expression that evaluates true() if should get on xforms-ready, false() if not.
 :)
declare function controls:rt-submission(
	$binding as attribute(),	
	$get-action as node(),
	$put-action as node()?,
	$replace as attribute()?,
	$targetref as attribute()?, 
	$error-instance-id as xs:string?,
	$rt-condition as xs:string?
	) as element()+ {
	let $submission-id := controls:rt-submission-id(string($binding))
	let $result-instance-id := concat($submission-id, '-result')
	return (
		controls:error-instance($error-instance-id), 
		<xf:instance id="{$submission-id}-blank">
			<blank xmlns=""/>
		</xf:instance>,
		<xf:instance id="{$result-instance-id}">
			<result xmlns=""/>
		</xf:instance>,
		<xf:submission id="{$submission-id}-get"
			method="get"
			ref="instance('{$submission-id}-blank')"
			replace="instance"
			instance="{$result-instance-id}"
			>{
			$get-action,
			local:simulate-targetref($result-instance-id, string($replace), string($targetref))
		}</xf:submission>,
		<xf:send ev:event="xforms-ready" submission="{$submission-id}-get">{
			if ($rt-condition)
			then 
				attribute if {$rt-condition}
			else ()
		}</xf:send>,
		<xf:submission 
			id="{$submission-id}-set"
			method="post"
			replace="instance"
			instance="{$result-instance-id}">
			{
			$binding,
			($put-action, $get-action)[1],
			controls:submission-response(
			  $error-instance-id,
  			(), ()
  		)			
			}
		</xf:submission>
	)
};
 
declare function controls:rt-control(
	$control-id as xs:string?,
	$submission-id as xs:string
	) as element()+ {
	controls:rt-control($control-id, $submission-id, (), (), ())
};

declare function controls:rt-control(
	$control-id as xs:string?,
	$submission-id as xs:string,
	$set-actions as element()*,
	$other-actions as element()*
	) as element()+ {
	controls:rt-control($control-id, $submission-id, $set-actions, $other-actions, ())
};

(:~ retrofit an existing control to update in real time.
 : The control *must* send DOMFocusOut events
 : @param $control-id control identifier (empty for current control)
 : @param $submission-id Submission identified from controls:rt-submission-id()
 : @param $set-actions additional actions when saving
 : @param $other-actions Other actions associated with the control, such as catching changes for the save flag
 : @param $condition optional XPath condition to determine when to go real-time
 :)
declare function controls:rt-control(
	$control-id as xs:string?,
	$submission-id as xs:string,
	$set-actions as element()*,
	$other-actions as element()*,
	$condition as xs:string?
	) as element()+ {
	<xf:action ev:event="DOMFocusOut">
		{
		if ($control-id)
		then attribute ev:observer { $control-id }
		else (),
		if ($condition)
		then attribute if { $condition }
		else ()
		}
		<xf:send submission="{$submission-id}-set"/>
		{$set-actions}
	</xf:action>,
	$other-actions
};

(:~ button to show the content of a given instance if we're in debug mode :)
declare function controls:debug-show-instance(
	$instance-id as xs:string
	) as element()? {
	if ($paths:debug)
	then
		<xf:trigger>
			<xf:label>DEBUG: Show {$instance-id}</xf:label>
			<xf:message ev:event="DOMActivate">
				<xf:output value="serialize(instance('{$instance-id}'))"/>
			</xf:message>
		</xf:trigger>
	else ()
};

(:~ instance to control a flag that indicates whether the data is saved :)
declare function controls:save-flag-instance(
	$instance-id as xs:string
	) as element()+ {
		(: hold the status, which may have the values: saved, unsaved, unchanged
	 : an additional save flag indicates whether the last event was just a save 
	 :)
	<xf:instance id="{$instance-id}">
		<flag xmlns="">
			<status>unchanged</status>
			<save-flag>0</save-flag>
		</flag>
	</xf:instance>,
	(: control a save button by binding it to here :)
	<xf:bind id="{$instance-id}-status" 
		nodeset="instance('{$instance-id}')/status" 
		readonly="instance('{$instance-id}')/status = 'saved' or instance('{$instance-id}')/status = 'unchanged'"/>
};

(:~ set a saved flag to the saved state 
 : @param $instance-id save flag instance
 : @param $status new flag status: true() = saved, false() = unsaved
 :)
declare function controls:set-save-flag(
	$instance-id as xs:string,
	$status as xs:boolean
	) as element()+ {
	<xf:setvalue ref="instance('{$instance-id}')/status" 
		value="'{if ($status) then 'saved' else 'unsaved'}'"/>,
	if ($status)
	then
		(: last event was a save event :)
		<xf:setvalue ref="instance('{$instance-id}')/save-flag" value="1"/>
	else ()
};

declare function controls:unsave-save-flag(
	$save-flag-instance-id as xs:string
	) as element()+ {
	controls:unsave-save-flag($save-flag-instance-id, ())
};

(:~ set the save flag to unsave in response to the given control 
 : (or current control if $control-id is empty)
 : becoming changed, for this to work, the control must be incremental.
 : @param $control-id Control that affects save status
 : @param $save-flag-instance-id Instance of save flag :)
declare function controls:unsave-save-flag(
	$save-flag-instance-id as xs:string,
	$control-id as xs:string?
	) {
	<xf:action ev:event="xforms-value-changed">
		{
		if ($control-id) 
		then attribute ev:observer { $control-id }
		else (),
		controls:set-save-flag($save-flag-instance-id, false())
		}
	</xf:action>
};

(:~ UI to show save status or a save button 
 : @param $instance-id save-flag-instance
 : @param $actions What to do when the save button is pressed and the data is unsaved
 :)
declare function controls:save-status-ui(
	$instance-id as xs:string,
	$control-id as xs:string,
	$actions as element()*
	) as element() {
	<xf:group id="{$control-id}">
		<xf:output id="{$control-id}-status" 
			ref="instance('{$instance-id}')/status[.='saved' or .='unchanged']"/>
		<xf:trigger id="{$control-id}-save" 
			ref="instance('{$instance-id}')/status[.='unsaved']">
			<xf:label>Save</xf:label>
			<xf:action ev:event="DOMActivate" 
				if="instance('{$instance-id}')/status = 'unsaved'">
				{$actions}
			</xf:action>
		</xf:trigger>
	</xf:group>
};
