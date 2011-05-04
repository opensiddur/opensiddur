xquery version "1.0";

(:~ Viewable list of contributor list items
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3
 : $Id: list-items.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
import module namespace app="http://jewishliturgy.org/modules/app" 
	at "../../../modules/app.xqm";
import module namespace common="http://jewishliturgy.org/apps/contributors/common"
	at "../modules/common.xqm";
import module namespace contributors="http://jewishliturgy.org/apps/contributors/controls"
	at "../modules/controls.xqm";
import module namespace site="http://jewishliturgy.org/modules/site"
	at "../../../modules/site.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema"; 
declare namespace h="http://www.w3.org/1999/xhtml";

declare option exist:serialize "method=xhtml media-type=text/xml";

site:form(
	<xf:model>{
		contributors:list-instance('contributors')
	}</xf:model>,
	(<h:title>Contributors List</h:title>),
	(<h:h2>Contributors list</h:h2>,
	contributors:list-table-ui('contributors','control-contributors')
	),
  (site:css(), contributors:css()),
  site:header(),
  (site:sidebar(), contributors:sidebar()),
  site:footer()
)
