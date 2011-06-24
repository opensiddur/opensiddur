xquery version "1.0";
(: api to check for user existence or list available profile resources
 : 
 : Method: GET
 : Return: 
 :		200 + menu (user exists and is logged in), 
 :		204 user exists but you are not logged in
 :		403 (user exists but you are logged in as someone else), 
 :		404 (user does not exist) 
 :
 : Method: PUT
 : Input: Password
 : Create a new user or set password for the current user
 : Return:
 :		201 User created
 :		403 User exists and is not logged in
 :		500 Error creating user
 :		
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
import module namespace user="http://jewishliturgy.org/modules/user" 
  at "/code/modules/user.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare namespace err="http://jewishliturgy.org/errors";

declare option exist:serialize "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes 
        doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
        doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd";

declare function local:show-user-menu(
	$user-name as xs:string
	) {
	let $base := concat('/code/api/user/', $user-name)
	let $list-body := 
		<ul>
			{
			api:list-item('Name', concat($base, '/name'), ('xml', 'txt')),
			api:list-item('Organizational affiliation', concat($base, '/orgname'), ('xml', 'txt')),
			api:list-item('Email address', concat($base, '/email'), ('xml', 'txt'))
			}
		</ul>
	return
		api:list(
			<title>User API for {$user-name}</title>,
			$list-body,
			count($list-body/li)
		)
};

(:~ what to do with a get request :)
declare function local:get(
	$user-name as xs:string
	) {
	if (xmldb:exists-user($user-name))
	then
		(: user exists :)
		if (api:require-authentication())
		then
			(: ... and we are authenticated :)
			if (api:require-authentication-as($user-name, true()))
			then
				(: ... and we are authenticated as the right user :)
				local:show-user-menu($user-name)
			else (
				(: ... but we are not authenticated as the user :)
				api:error(403, 'You are not logged in as the right user')
			)
		else
			(: not authenticated: the call was asking if the user exists :)
			response:set-status-code(204)
	else (
		(: user does not exist, return 404 :)
		api:error(404, concat('User ', $user-name , ' does not exist'))
	)
};

declare function local:put(
	$user-name as xs:string
	) {
	let $password := string(api:get-data())
	return
		if (xmldb:exists-user($user-name))
		then
			(: this is a request to change password :)
			if (api:require-authentication-as($user-name, true()))
			then (
				(: same user requests, so we change it :)
				xmldb:change-user($user-name, $password, (), ())
			)
			else 
				(: change password for a different user: that's an error :)
				()
		else
			(: this is a request for a new user :)
			if (user:create($user-name, $password))
      then (
      	(: user created :)
      	app:login-credentials($user-name, $password),
      	response:set-status-code(201)
      )
      else (
      	(: error :)
      	api:error(500, concat('Could not create the user ', $user-name, '.'))
      )
};

if (api:allowed-method(('GET', 'PUT')))
then
	(: $user-name the user name in the request URI :)
	let $method := api:get-method()
	let $user-name := request:get-parameter('user-name', ())
	return
		if ($method = 'GET')
		then local:get($user-name)
		else local:put($user-name)
else
	(: disallowed method :) 
	()
