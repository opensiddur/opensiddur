xquery version "1.0";
(:~ index for the user API
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace api="http://jewishliturgy.org/modules/api" 
	at "/code/api/modules/api.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare option exist:serialize "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes 
        doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
        doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd";

if (api:allowed-method('GET'))
then
	let $user-name := request:get-parameter('user-name', ())
	let $base := '/code/api/user'
	let $list-body := (
		<ul class="common">
			<li><a href="{$base}/login">Session-based login</a></li>
			<li><a href="{$base}/logout">Session-based logout</a></li>
		</ul>,
		if ($user-name)
		then
			<ul class="results">
	  		<li><a href="{$base}/{$user-name}">{$user-name}</a></li>
	  	</ul>
	  else ()
	)
	return
		api:list(
			<title>Open Siddur User API</title>,
	  	$list-body,
	  	count($list-body/self::ul[@class="results"]/li) 
		)
else ()
