xquery version "1.0";
(:~ view-item.xql 
 : Contributor list editor
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License version 3 or later
 :)
import module namespace controls="http://jewishliturgy.org/modules/controls" 
	at "../../../modules/controls.xqm";
import module namespace contributors="http://jewishliturgy.org/apps/contributors/controls"
	at "../modules/controls.xqm";
import module namespace site="http://jewishliturgy.org/modules/site"
	at "../../../modules/site.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events";
declare namespace html="http://www.w3.org/1999/xhtml";

declare option exist:serialize "method=xhtml media-type=text/xml indent=yes process-xsl-pi=no";

let $id := request:get-parameter('id','')
return
	site:form(
		<xf:model>{
			contributors:list-instance('contributorlist'),
			contributors:individual-entry-instance(
				'contributor',
				'contributorlist',
				$id,
				(), (), false(), ())
		}</xf:model>,
		<html:title>View contributor</html:title>,
		(
		<html:h2>View contributor</html:h2>,
		contributors:individual-entry-ui(
			'contributor', 'contributorlist',
			'control-contributor', $id)
		)
	)
