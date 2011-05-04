xquery version "1.0";
(:~ index for the whole API
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 : $Id: index.xql 716 2011-03-16 04:06:44Z efraim.feinstein $
 :)

import module namespace api="http://jewishliturgy.org/modules/api" at "modules/api.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare option exist:serialize "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes 
        doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
        doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd";

if (api:allowed-method('GET'))
then
	let $base := '/code/api'
	let $list-body := 
		<ul>
	  	<li><a href="{$base}/user">User management</a></li>
	  	<li><a href="{$base}/data">Data</a></li>
	  </ul>
	return
		api:list(
			<title>Open Siddur API</title>,
	  	$list-body,
	  	count($list-body/li)
		)
else ()