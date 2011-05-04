xquery version "1.0";
(: Contributors list UI controls
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: contributors.xqm 709 2011-02-24 06:37:44Z efraim.feinstein $
 :)
module namespace contributors="http://jewishliturgy.org/apps/lib/contributors"; 

import module namespace paths="http://jewishliturgy.org/apps/lib/paths" 
	at "../lib/paths.xqm";
import module namespace controls="http://jewishliturgy.org/apps/lib/controls" 
	at "../lib/controls.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema"; 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xrx="http://jewishliturgy.org/ns/xrx";
declare option exist:serialize "method=xhtml media-type=text/xml indent=yes process-xsl-pi=no";

declare variable $contributors:prototype :=
	<tei:item xml:id="">
		<tei:name/>
		<tei:orgName/>
		<tei:email/>
		<tei:ptr type='url' target=""/>
		<tei:affiliation>
			<tei:ptr target=""/>
		</tei:affiliation>
	</tei:item>;
declare variable $contributors:loader :=	concat($paths:prefix, $paths:apps, '/contributors/load.xql');
declare variable $contributors:collection := '/group/everyone/contributors';
declare variable $contributors:resource := 'contributors.xml';
declare variable $contributors:list := concat($contributors:collection, '/', $contributors:resource);

declare function contributors:individual-entry-instance(
	$instance-id as xs:string,
	$list-instance-id as xs:string?,
	$id as xs:string?)
	as element()+ {
	(
	<xf:instance xmlns="" 
		src="{$contributors:loader}{if ($id) then concat('?id=', $id) else ()}" 
		id="{$instance-id}">
	</xf:instance>,
	<xf:instance id="{$instance-id}-empty-affiliation" xmlns="">
		<empty-affiliation>
			<tei:item xrx:idref="" xml:id="">
				<tei:orgName>None</tei:orgName>
			</tei:item>
		</empty-affiliation>
	</xf:instance>,
	contributors:bindings($instance-id, ($list-instance-id, $instance-id)[1], $id)
	)
};

declare function contributors:list-instance(
	$instance-id as xs:string) 
	as element()+ {
	(
	<xf:instance xmlns="" 
		src="{$contributors:loader}" 
		id="{$instance-id}">
	</xf:instance>,
	<xf:instance id="{$instance-id}-empty-affiliation" xmlns="">
		<empty-affiliation>
			<tei:item xrx:idref="" xml:id="">
				<tei:orgName>None</tei:orgName>
			</tei:item>
		</empty-affiliation>
	</xf:instance>,
	<xf:instance id="{$instance-id}-prototype" xmlns="">
		<prototype>
			{$contributors:prototype}
		</prototype>
	</xf:instance>,
	controls:ordered-list-instance('{$instance-id}-list', $contributors:prototype),
	contributors:bindings($instance-id, $instance-id, ())
	)
};

declare function contributors:bindings(
	$instance-id as xs:string,
	$list-instance-id as xs:string,
	$id as xs:string?) 
	as element(xf:bind)+ {
	(
	<xf:bind nodeset="instance('{$instance-id}')/tei:item/@xml:id" 
		type="xf:NCName"
		constraint="(. != '') and count(instance('{$list-instance-id}')/tei:item[@xml:id = current()])=1">{
		if ($id)
		then attribute readonly {"true()"}
		else ()
	}</xf:bind>,
	<xf:bind nodeset="instance('{$instance-id}')/tei:item/tei:email" required="true()"/>,
	<xf:bind nodeset="instance('{$instance-id}')/tei:item/tei:orgName" relevant="../tei:name = ''" required="../tei:name = ''"/>,
	<xf:bind nodeset="instance('{$instance-id}')/tei:item/tei:name" relevant="../tei:orgName = ''" required="../tei:orgName = ''"/>,
	<xf:bind nodeset="tei:item/tei:affiliation" relevant="../tei:name"/>
	)
};

(:~ User interface for a single contributor entry.
 : @param $instance-id Instance that holds contributor list
 : @param $control-id Identifier of this control
 : @param $ref reference (defaults to instance('{$instance-id}'))
 : @param $id Identifier of contributor that the entry identifies (optional) :)
declare function contributors:individual-entry-ui(
	$instance-id as xs:string,
	$list-instance-id as xs:string,
	$control-id as xs:string,
	$ref as xs:string?,
	$id as xs:string?) 
	as element()+ {
	<xf:group id="{$control-id}">
		{attribute ref {($ref, concat("instance('",$instance-id,"')"))[1]}}
		{if ($id)
		then 
			<xf:output ref="@xml:id">
				<xf:label>Login ID:</xf:label>
			</xf:output>
		else
			<xf:input ref="@xml:id" incremental="true">
				<xf:label>Login ID:</xf:label>
			</xf:input>
		}
		<br/>
		<xf:input ref="tei:name" incremental="true">
			<xf:label>Real name or pseudonym (for a person; include relevant titles and full name): </xf:label>
		</xf:input>
		<br/>
		<xf:input ref="tei:orgName" incremental="true">
			<xf:label>Organization name (for a company, non-profit, etc.): </xf:label>
		</xf:input>
		<br/>
		<xf:input ref="tei:ptr[@type='url']/@target">
			<xf:label>Website address (URL): </xf:label>
		</xf:input>
		<br/>
		<xf:input ref="tei:email" incremental="true">
			<xf:label>Public email address:</xf:label>
		</xf:input>
		<br/>
		<xf:select1 ref="tei:affiliation/tei:ptr/@target" incremental="true">
			<xf:label>Organizational affiliation:</xf:label>
			<xf:itemset nodeset="instance('{$instance-id}-empty-affiliation')/tei:item|instance('{$list-instance-id}')/tei:item[tei:orgName]">
				<xf:label ref="tei:orgName"/>
				<xf:value ref="@xrx:idref"/>
			</xf:itemset>
		</xf:select1>
		<br/>
	</xf:group>
};

declare function contributors:list-ui(
	$list-instance-id as xs:string,
	$control-id as xs:string)
	as element()+ {
	( 
		<xf:group ref="instance('{$list-instance-id}')" id="{$control-id}">
			<xf:repeat id="{$control-id}-contributors-list" nodeset="tei:item">
				<hr/>
				{controls:collapsible(
					concat($control-id, 'collapsible'),
					<xf:output ref="@xml:id"/>,
					(
						<xf:trigger ref="self::node()[count(../*) &gt; 1]">
							<xf:label>Delete contributor</xf:label>
							<xf:action ev:event="DOMActivate">
								<xf:delete nodeset="."/>
							</xf:action>
						</xf:trigger>,
						contributors:individual-entry-ui(
							$list-instance-id,
							$list-instance-id,
							concat($control-id,'-individual'),
							'.', ()
						)
					)
				)}
			</xf:repeat>
			
			<h2>Add new record</h2>
			<!-- TODO: NEED A DIFFERENT ADD RECORD FOR EMPTY LISTS -->
			<xf:trigger id="{$control-id}-add-record">
				<xf:label>Add contributor</xf:label>
				<xf:action ev:event="DOMActivate">
					<xf:insert origin="instance('{$list-instance-id}-prototype')/tei:item"
						nodeset="instance('{$list-instance-id}')/tei:item"
						at="last()"
						position="after"
						/>
					<xf:setvalue ref="instance('{$list-instance-id}')/tei:item[last()]/@xml:id">* NEW CONTRIBUTOR</xf:setvalue>
				</xf:action>
			</xf:trigger>
			<hr/>
		</xf:group>
	)
};
