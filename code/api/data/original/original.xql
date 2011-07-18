xquery version "1.0";
(: api for listing original data, if a resource is not given
 : 
 : Parameters:
 : 	share-type = user|group|()
 :	owner = name of owner to limit listing to|()
 :	If share-type is (), all accessible shares are shown
 :	If owner is (), all accessible shares with the given share-type are shown
 : 
 : Method: GET
 : Return: 
 :		200 + menu (menu of available functions), 
 :		204 user exists but you are not logged in
 :		401 (you are not logged in and requested a resource that requires login)
 :		403 (you are logged in, but you can't access the resource), 
 :		404 share type, group or user does not exist
 :
 : Method: POST
 : Input: Password
 : Create a new XML resource in the given collection 
 : Return:
 :		201 Resource created, location header set
 :		401 Access to the resource requires authorization
 :		403 You are logged in, but you can't access the resource
 :		404 Share-type, user or group does not exist
 :		
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 : $Id: original.xql 769 2011-04-29 00:02:54Z efraim.feinstein $
 :)
import module namespace response="http://exist-db.org/xquery/response";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace collab="http://jewishliturgy.org/modules/collab"
	at "/code/modules/collab.xqm";
import module namespace scache="http://jewishliturgy.org/modules/scache"
	at "/code/api/modules/scache.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
	at "/code/api/modules/data.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/code/modules/paths.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace err="http://jewishliturgy.org/errors";

declare option exist:serialize "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes 
        doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
        doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd";

(:~ POST, may return errors :)
declare function local:post(
	$share-type as xs:string?,
	$owner as xs:string?
	) as element()? {
	if (exists($share-type) and exists($owner))
	then 
		let $collection := app:concat-path(
			data:top-collection($share-type, $owner), 'original')
		let $name := concat(util:uuid(), '.xml')
		let $data := request:get-data()[tei:TEI]
		let $store-data := 
			($data, doc('/code/api/data/resources/template.xml'))[1] 
		return 
			if (
				(($share-type = 'group') and (api:require-authentication-as-group($owner, true())))
				or
				(($share-type = 'user') and (api:require-authentication-as($owner, true())))
			)
			then
				let $path := collab:store-path(app:concat-path($collection, $name), $store-data)
				return
					if ($path)
					then (
						response:set-status-code(201),
						response:set-header('Location', 
							concat('/code/api/data/original/', $share-type, '/', $owner, '/', replace($name, '.xml', '')))
					)
					else
						api:error(500, "Error storing your data.")
			else
				api:error-message(concat("Proper ", $share-type, " authentication required"))
	else (
		(: POST is not allowed when both share-type and owner are not present:)
		api:error(405, "Method not allowed"),
		response:set-header('Allow', 'GET')
	)
};

declare function local:get(
	$share-type as xs:string?,
	$owner as xs:string?
	) as element() {
	let $uri := request:get-uri()
	let $collections := data:top-collection($share-type, $owner)
	let $ignore-collections := '(/trash/)|(/cache/)'
	let $list :=
	(
		<ul class="common">{
			if (not($share-type))
			then (
				api:list-item('Group', '/code/api/data/original/group', "GET", api:html-content-type(), ())
			)
			else if (not($owner))
			then (
				let $user := app:auth-user()
				return
					if ($user)
					then (
						for $group in xmldb:get-user-groups($user)
						return
							api:list-item($group, concat('/code/api/data/original/group/', $group), "GET", api:html-content-type(), ())
					)
					else ( (:do not display data about not logged in users :) )
			)
			else 
				( (: share type and owner present:) )
		}</ul>,
		if (scache:is-up-to-date($uri, '', $collections))
		then scache:get-request($uri, '')
		else scache:store($uri, '', 
			<ul class="results">{
				for $collection in $collections
				return
					for $title in collection($collection)//tei:title[@type='main' or not(@type)]
					let $doc-uri := document-uri(root($title))
					let $doc-name-no-ext := replace(util:document-name($doc-uri), '\.xml$', '')
					let $collection-name := replace(util:collection-name($title), '^(/db)?/', '')
					let $share-type-owner := 
            string-join(subsequence(tokenize($collection-name, '/'), 1, 2), '/')
					let $link := 
						concat('/code/api/data/original/', $share-type-owner, '/',
							$doc-name-no-ext)
					let $title-string := normalize-space($title)
					let $lang := $title/@xml:lang
					where contains($doc-uri,'/original/') and not(matches($doc-uri, $ignore-collections))
					order by $title-string
					return 
							api:list-item(
								<span>{
									$lang, 
									if ($lang) then attribute lang {string($lang)} else (),
									if ($title)
									then $title-string
									else $doc-name-no-ext
								}</span>,
								$link, "GET",
                (api:tei-content-type()),
                (),
								("db", replace($doc-uri, '^/db', ''))
							)
			}</ul>
		)
	)
	let $n-results := count(scache:get($uri, '')/li)
	return (
		if ($paths:debug)
		then
			util:log-system-out(('GET ', $uri, ': $n-results=', $n-results))
		else (),
		api:list(
			<title>Open Siddur Original Data API</title>,
			$list,
			$n-results,
      true(),
      ("GET", "POST"),
      api:html-content-type(),
      api:tei-content-type()
		)
	)
};

if (api:allowed-method(('GET', 'POST')))
then
	let $auth := api:request-authentication() or true()
	(: $user-name the user name in the request URI :)
	let $share-type := request:get-parameter('share-type', ())
	let $owner := request:get-parameter('owner', ())
	let $method := api:get-method()
	return
		if (data:is-valid-share-type($share-type))
		then 
			if (data:is-valid-owner($share-type, $owner))
			then 
				if ($method = 'GET')
				then local:get($share-type, $owner)
				else local:post($share-type, $owner)
			else
				api:error(404, concat("Invalid owner for the given share type ", $share-type), $owner)
		else
			api:error(404, "Invalid share type. Acceptable values are 'group'", $share-type) 
else
	(: disallowed method :) 
	()
