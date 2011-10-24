xquery version "1.0";
(:~ Elements that are literally copied
 :
 : Available formats: xml, txt
 : Method: GET
 : Status:
 :	200 OK
 :	401, 403 Authentication
 :	404 Bad format 
 : 
 : Method: PUT
 : Status:
 :	204 Success
 :	401, 403 Authentication
 :	404 Bad format 
 :
 : Open Siddur Project 
 : Copyright 2011 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "/code/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
	at "/code/api/modules/data.xqm";
import module namespace resp="http://jewishliturgy.org/modules/resp"
  at "/code/api/modules/resp.xqm";
  
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

declare variable $local:valid-formats := ('xml');

declare function local:get(
	$node as node(),
	$format as xs:string?
	) as item() {
	api:serialize-as('xml'),
	$node
};

declare function local:put(
	$node as node(),
	$format as xs:string?
	) as element()? {
	let $data := api:get-data()
	return 
		if (node-name($data) = node-name($node))
		then (
			response:set-status-code(204),
			let $doc := root($node)
			return (
			  resp:remove($node),
			  update replace $node with $data,
			  if ($data/@xml:id)
			  then
			    resp:add($doc//id($data/@xml:id), "editor", app:auth-user())
			  else ()
			)
		)
		else
			api:error(400, "Input data must be the right type")
};

if (api:allowed-method(('GET', 'PUT')))
then
	let $auth := api:request-authentication() or true()
	(: $user-name the user name in the request URI :)
	let $purpose := request:get-parameter('purpose', ())
	let $share-type := request:get-parameter('share-type', ())
	let $owner := request:get-parameter('owner', ())
	let $resource := request:get-parameter('resource', ())
	let $subresource := request:get-parameter('subresource', ())
	let $format := request:get-parameter('format', 'xml')
	let $doc := data:doc($purpose, $share-type, $owner, $resource, 'xml', $local:valid-formats)
	let $method := api:get-method()
	return (
		if ($doc instance of document-node())
		then
			if ($subresource = ('repository', 'selection', 'front'))
			then
				let $node := 
					if ($subresource = 'repository')
					then $doc//j:repository
					else if ($subresource = 'selection')
					then $doc//j:selection
					else $doc//tei:front
				return (
					if ($method = 'GET')
					then local:get($node, $format)
					else local:put($node, $format)
				)
			else
				api:error(404, 'Resource not found', $resource)
		else 
			(: an error occurred and is in $doc :)
			$doc
	)
else 
	(:disallowed method:)
	api:error-message("Method not allowed")
