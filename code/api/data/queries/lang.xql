xquery version "1.0";
(:~ get/put a primary language for a resource
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
  at "/code/modules/resp.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $local:valid-formats := ('xml', 'txt');

declare function local:get(
	$node as attribute(),
	$format as xs:string?
	) as item() {
	if ($format = 'xml')
	then (
		api:serialize-as('xml'),
		<result xmlns="">{string($node)}</result>
	)
	else (
		api:serialize-as('txt'),
		text {string($node)}
	)
};

declare function local:put(
	$node as attribute(),
	$format as xs:string?
	) as empty() {
	response:set-status-code(204),
	update replace $node with attribute xml:lang {string(api:get-data())},
	resp:add-attribute($node, "editor", app:auth-user(), "value")
};

if (api:allowed-method(('GET', 'PUT')))
then
	let $auth := api:request-authentication() or true()
	(: $user-name the user name in the request URI :)
	let $purpose := request:get-parameter('purpose', ())
	let $share-type := request:get-parameter('share-type', ())
	let $owner := request:get-parameter('owner', ())
	let $resource := request:get-parameter('resource', ())
	let $format := request:get-parameter('format', 'txt')
	let $doc := data:doc($purpose, $share-type, $owner, $resource, 'xml', $local:valid-formats)
	let $method := api:get-method()
	return
		if ($doc instance of document-node())
		then
			let $node := $doc/tei:TEI/@xml:lang
			return
				if ($method = 'GET')
				then local:get($node, $format)
				else local:put($node, $format)
		else 
			(: an error occurred and is in $doc :)
			$doc
else 
	(:disallowed method:)
	api:error-message("Method not allowed")
