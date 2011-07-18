xquery version "1.0";
(:~ index for the whole API
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)

import module namespace api="http://jewishliturgy.org/modules/api" 
  at "/code/api/modules/api.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 

if (api:allowed-method('GET'))
then 
	let $base := '/code/api'
	let $list-body := 
		<ul class="common">{
      api:list-item(
        "User management",
        concat($base, "/user"),
        "GET",
        api:html-content-type(), ()
      ),
      api:list-item(
        "Data",
        concat($base, "/data"),
        "GET",
        api:html-content-type(), ()
      )
	  }</ul>
	return (
    api:serialize-as('xhtml'),
		api:list(
			<title>Open Siddur API</title>,
	  	$list-body,
	  	0,
      false(),
      "GET",
      api:html-content-type(), ()
		)
  )
else ()
