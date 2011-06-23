xquery version "1.0";
(: api login action
 : 
 : Method: GET
 : Return: 200: current logged in user, 204: not logged in
 :
 : Method: PUT
 : Input: password (string content)
 : Return: 204: user is logged in, 400: wrong username or password
 :
 : on error: <result><error/></result>
 : Method: DELETE
 : Return: 204, log out current user
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 : $Id: login.xql 769 2011-04-29 00:02:54Z efraim.feinstein $
 :)
import module namespace request="http://exist-db.org/xquery/request";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/code/modules/paths.xqm";
	
declare namespace err="http://jewishliturgy.org/errors";

if (api:allowed-method(('GET', 'PUT', 'DELETE')))
then
	let $method := api:get-method() 
	let $user-name := request:get-parameter('user-name', ())
	return 
		if ($method = 'GET')
		then 
			(: this is a request to find out who is logged in:)
			(app:auth-user(), response:set-status-code(204))[1]
		else if ($method = 'PUT')
		then
			(: this is a request to log in :)
			let $password := string(api:get-data())
			return
				if (xmldb:authenticate('/db', $user-name, $password))
				then (
					if ($paths:debug)
					then
						util:log-system-out(('Logging in ', $user-name, ':', $password))
					else (),
					response:set-status-code(204),
					app:login-credentials($user-name, $password)
				)
				else (
					api:error(400,'Wrong username or password')
				)
		else (
			(: method must be DELETE :)
			app:logout-credentials(),
			response:set-status-code(204)
		)
else ()
