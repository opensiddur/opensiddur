xquery version "1.0";
(: api to check for user existence or list available profile resources
 : 
 : Method: GET
 : Return: 
 :		200 + menu (list available data types)
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
import module namespace response="http://exist-db.org/xquery/response";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare namespace err="http://jewishliturgy.org/errors";

declare option exist:serialize "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes 
        doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
        doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd";

declare function local:get(
	) as element() {
	let $base := '/code/api/data'
	let $list := 
		<ul class="common">
			<li><a href="{$base}/contributors">Contributor lists</a></li>
			<li><a href="{$base}/original">Original texts</a></li>
			<li><a href="{$base}/parallel">Parallel text tables</a></li>
			<li><a href="{$base}/sources">Bibliographic data</a></li>
			<li><a href="{$base}/translation">Translation texts</a></li>
			<li><a href="{$base}/transliteration">Transliteration tables</a></li>
			<li><a href="{$base}/output">Generated output</a></li>
		</ul>
	return
		api:list(
			<title>Open Siddur Data API</title>,
			$list,
			0 (: the list here is a common menu, not results, so the number of results = 0 :)
		)
}; 

if (api:allowed-method('GET'))
then
	(: $user-name the user name in the request URI :)
	local:get()
else
	(: disallowed method :) 
	()
