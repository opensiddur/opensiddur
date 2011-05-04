xquery version "1.0";

(:~ contributors list search interface 
 : with no parameters: display a search interface
 : q=term : return search term results as tei:list
 :
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 : $Id: search.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)

import module namespace contributors="http://jewishliturgy.org/apps/contributors/controls"
	at "../modules/controls.xqm";
import module namespace common="http://jewishliturgy.org/apps/contributors/common"
	at "../modules/common.xqm";
import module namespace controls="http://jewishliturgy.org/modules/controls"
	at "../../../modules/controls.xqm";
import module namespace site="http://jewishliturgy.org/modules/site"
	at "../../../modules/site.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare option exist:serialize "method=xhtml media-type=text/xml indent=yes process-xsl-pi=no";

(:~ return a list instance containing the results of the query :)
declare function local:do-search(
	$query as xs:string) 
	as element(tei:list) {
	<tei:list>{
		let $doc :=	doc($common:list)
		return
			$doc//tei:item[ft:query(., $query) or ft:query(@xml:id, $query) or 
				(
					let $context := .
					let $org-target := $context/tei:affiliation/tei:ptr/@target
					return
						ft:query($doc//id(substring-after(string($org-target),'#'))/tei:orgName, $query) or
						ft:query($org-target, $query)
				)]
	}</tei:list>
};

declare function local:show-interface() 
	as element()+ {
	site:form(
		<xf:model>{
			contributors:search-instance('search', 'results', 'reporter')
		}</xf:model>,
		(<html:title>Contributor search interface</html:title>),
		(
			<html:h2>Contributor search</html:h2>,
			contributors:search-ui('search','results','control-search'),
			controls:reporter('reporter',
				<html:p>Search completed successfully.</html:p>,
				<html:p>An error occurred during search.</html:p>)
		),
    (site:css(), contributors:css()),
    site:header(),
    (site:sidebar(), contributors:sidebar()),
    site:footer()
	)
};

(: This can be called either by POST or GET.  If GET, the parameter is a string, if POST, it's a nodeset :)
let $query-string as xs:string? := 
  if (lower-case(request:get-method()) = 'get') 
  then request:get-parameter('q','') 
  else if (lower-case(request:get-method()) = 'post')
  then string(request:get-data()/q)
  else ()
return
	if ($query-string)
	then local:do-search($query-string)
	else local:show-interface()
