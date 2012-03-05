xquery version "1.0";
(:~ Represents the URI of the license
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
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "/code/modules/debug.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $local:valid-formats := ('xml', 'txt');

declare function local:get(
	$node as element(),
	$format as xs:string?
	) as item() {
	let $lic-uri := string($node//tei:ref[@type='license']/@target)
	return
		if ($format = 'xml')
		then (
			api:serialize-as('xml'),
			<tei:ptr target="{$lic-uri}"/>
		)
		else ( 
			api:serialize-as('txt'),
			text { $lic-uri }
		)
};

(: TODO: check if changing the license is allowed! :)
declare function local:put(
	$node as node(),
	$format as xs:string?
	) as element()? {
	let $license-templates := doc('/code/modules/code-tables/licenses.xml')/code-table
	let $data := api:get-data()
	let $new-lic := 
		if ($format = 'txt')
		then string($data)
		else string(($data/self::tei:ptr/@target, $data)[1])
	let $boilerplate :=
		$license-templates/license[id=$new-lic]/tei:availability
	let $doc := root($node)
	return 
		if (exists($boilerplate))
		then (
			response:set-status-code(204),
			debug:debug($debug:detail, "license.xql", "before resp:remove()"),
			resp:remove($node),
			update replace $node with $boilerplate,
			debug:debug($debug:detail, "license.xql", (
			  "document boilerplate id: ", $boilerplate/@xml:id/string(), " in context: ", 
			  $doc//id($boilerplate/@xml:id))),
			resp:add($doc//id($boilerplate/@xml:id), "editor", app:auth-user(), "value")
		)
		else 
			api:error(400, "The given license URI is not allowed.", $new-lic) 
	
};

if (api:allowed-method(('GET', 'PUT')))
then
	let $auth := api:request-authentication() or true()
	(: $user-name the user name in the request URI :)
	let $null :=       util:log-system-out("HERE")
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
			let $node := $doc//tei:availability
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
