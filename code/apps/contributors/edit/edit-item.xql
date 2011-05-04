xquery version "1.0";
(: Contributors list UI
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: edit-item.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema"; 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace html="http://www.w3.org/1999/xhtml";
declare option exist:serialize "method=xhtml media-type=text/xml indent=yes process-xsl-pi=no";

import module namespace controls="http://jewishliturgy.org/modules/controls" 
	at "../../../modules/controls.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths" 
	at "../../../modules/paths.xqm";
import module namespace site="http://jewishliturgy.org/modules/site" 
	at "../../../modules/site.xqm";
		
import module namespace login="http://jewishliturgy.org/apps/user" 
	at "../../user/modules/login.xqm";
import module namespace contributors="http://jewishliturgy.org/apps/contributors/controls"
	at "../modules/controls.xqm";

let $id := request:get-parameter('id','')
let $data-source := 
	if ($id)
	then concat('load.xql?id=', $id)
	else 'load.xql'
let $new := request:get-parameter('new','')
return
site:form(
	<xf:model>{
		(:login:login-instance('login'),:)
		contributors:list-instance('contributorlist'),
		contributors:individual-entry-instance('contributor', 'contributorlist', 
			$id, $new, 'reporter')
	}</xf:model>,
	<html:title>Contributor list item editor</html:title>,
	<html:div class="editor">{
		(:login:login-ui('login','control-login'),:)
		contributors:individual-entry-ui('contributor','contributorlist',
			'control-contributor', $id),
		(: this section reports success or failure :)
		<html:div>{
			controls:reporter(
				"reporter",
				<html:p class="success-report">
					Item {$id} {if ($new) then 'added' else 'updated'} successfully.
				</html:p>,
				<html:p class="error-report">
					An error occurred {if ($new) then 'adding' else 'updating'} {$id}.
				</html:p>
			)
		}</html:div>
	}</html:div>
)
