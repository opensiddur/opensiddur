xquery version "1.0";
(:~ controller.xql
 : Copyright 2010 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3
 : 
 : This controller is used this to redirect or forward paths, by default, it directs no
 : resource to index.xql
 :)
declare namespace ex="http://exist.sourceforge.net/NS/exist";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

if ($exist:path = ("/","")) then
	<ex:dispatch>
		<ex:redirect url="index.xql"/>
	</ex:dispatch>
(:
else if (starts-with($exist:path, "/edit"))
then
	<ex:dispatch>
		<ex:forward url="edit/edit.xql"/>
	</ex:dispatch>
else if (starts-with($exist:path, "/view"))
then
	<ex:dispatch>
		<ex:forward url="views/list-items.xql"/>
	</ex:dispatch>
else if (starts-with($exist:path, "/search"))
then
	<ex:dispatch>
		<ex:forward url="search/search.xql"/>
	</ex:dispatch>
:)
else
	<ex:ignore>
		<ex:cache-control cache="yes"/>
	</ex:ignore>
