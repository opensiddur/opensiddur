xquery version "1.0";
(: Contributors list id reference loader
 : only needed for a kluge to work aroun broken xf:value in betterFORM and XSLTForms
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: load-idref-instance.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "../../modules/paths.xqm";
import module namespace common="http://jewishliturgy.org/apps/contributors/common"
	at "modules/common.xqm";

let $contrib-org-items := 
	if (doc-available($common:list))
	then doc($common:list)//tei:div[@type='contributors']/tei:list/tei:item[tei:orgName]
	else ()
return 
	<idrefs xmlns="">{
		<idref id="" idref=""/>,
		for $item in $contrib-org-items
		return
			<idref xmlns="" id="{string($item/@xml:id)}" idref="#{string($item/@xml:id)}"/>
	}</idrefs>
