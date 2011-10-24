xquery version "1.0";
(:~ Selection:
 :
 : Available formats: [empty], xml, txt
 : 
 : Method: GET
 : Return: Content of selection or menu of ids
 : Subsubresources: /id selection pointer with the given id
 : Status: 
 :	200 OK
 :	401, 403 Authentication
 :	404 Bad format 
 : 
 : Method: POST
 : Subsubresource: /id; if the xml:id exists, the original is removed and the ptr with
 : 	the given xml:id is moved to a new position
 : No subresource: Post tei:ptr to the beginning of the selection
 : Return:
 : Status: 
 :	201 Created
 :	401, 403 Authentication
 :	400 Bad format
 : 
 : Method: PUT
 : Status:
 :	204 Success
 :	401, 403 Authentication
 :	404 Bad format
 :
 : Method: DELETE
 : Status:
 :	204 Deleted
 :	401, 403 Authentication
 :	405 Not supported unless subresource is given
 :
 : Open Siddur Project 
 : Copyright 2011 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";

import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
	at "/code/api/modules/data.xqm";
import module namespace resp="http://jewishliturgy.org/modules/resp"
  at "/code/modules/resp.xqm";
import module namespace scache="http://jewishliturgy.org/modules/scache"
	at "/code/api/modules/scache.xqm";
	
declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

declare variable $local:valid-formats := ('xhtml', 'html', 'xml', 'txt');

declare function local:get-menu(
	$selection as element(j:selection),
	$index as xs:string?
	) as element() {
	let $uri := request:get-uri()
	let $indexed-node := $selection/id($index) 
	let $list :=
		if (exists($index))
		then
			(: index given :)
			if ($indexed-node)
			then
			  <ul class="results">{ 
					let $id := string($indexed-node/@xml:id)
					let $db-link := resolve-uri(string($indexed-node/@target), base-uri($indexed-node))
					let $api-link := data:db-path-to-api($db-link)
					return 
						api:list-item($id, $api-link, 
              ("GET", "POST", "PUT", "DELETE"), 
              (api:tei-content-type("tei:ptr"), "text/plain"), 
              (api:tei-content-type("tei:ptr"), "text/plain"), 
              ("db", $db-link))
			  }</ul>
			else
				api:error(404, "Index not found", $index)
		else
			(: no index. show a list of available indexes :)
			if (scache:is-up-to-date($uri, '', util:document-name(root($selection))))
			then scache:get-request($uri, '')
			else 
				scache:store($uri, '', 
					<ul class="results">{
						for $ptr in $selection/tei:ptr
						let $id := xs:string($ptr/@xml:id)
						let $db-link := resolve-uri(string($ptr/@target), base-uri($ptr))
						let $api-link := data:db-path-to-api($db-link)
						return
							api:list-item(
								$id,
								$api-link, 
                ("GET", "PUT", "POST", "DELETE"), 
                (api:tei-content-type("tei:ptr"), "text/plain"),
                (api:tei-content-type("tei:ptr"), "text/plain"),
                ("db", $db-link)
							)
					}</ul>
				)
	return
		if ($list/.[local-name(.) = 'error'])
		then
			$list/*
		else (
			api:serialize-as('xhtml'),
			api:list(
				<title>Selection for {
					replace($uri, '^/code/api', '')
				}</title>,
				$list,
				count(scache:get($uri, '')/li),
        false(),
        ("GET", "PUT", "POST", "DELETE"),
        api:html-content-type(),
        (api:tei-content-type("tei:ptr"), "text/plain")
			)
		)
};

declare function local:get(
	$selection as element(j:selection),
	$index as xs:string?,
	$format as xs:string?
	) as item() {
	let $node := 	
		if (exists($index))
		then $selection/id($index)
		else $selection
	return
		if (empty($node))
		then
			api:error(404, "Not found")
		else if ($format = 'xml')
		then (
			api:serialize-as('xml'),
			$node
		)
		else (
			(: txt format :)
			api:serialize-as('txt'),
			if ($index)
			then string($node/@target)
			else string-join($node/tei:ptr/@target, '&#x0a;')
		)
};

declare function local:put(
	$selection as element(j:selection),
	$index as xs:string?,
	$format as xs:string?
	) as element()? {
	let $data := api:get-data()
	let $node := 
		if (exists($index))
		then $selection/id($index)
		else $selection
	return 
		if (empty($node))
		then 
			api:error(404, "Not found")
		else
			if (node-name($data) = node-name($node))
			then 
			  let $doc := root($node)
			  return
  			(
  				response:set-status-code(204),
  				resp:remove($node),
  				update replace $node with $data,
  				resp:add($doc//id($data/@xml:id), "editor", app:auth-user(), "location value")
  			)
			else
				api:error(400, "Input data must be the right type")
};

declare function local:post(
	$selection as element(j:selection),
	$index as xs:string?,
	$format as xs:string?
	) as element()? {
	let $uri := request:get-uri()
	let $node := 
		if ($index)
		then $selection/id($index)
		else $selection
	let $data := api:get-data()
	let $doc := root($node)
	let $id := 
		(: assign an xml:id if one does not already exist in the node :)
		if (not(string($data/@xml:id)))
		then concat('se_', util:uuid())
		else string($data/@xml:id)
	let $ptr-with-xmlid := 
		element tei:ptr {
			$data/(@* except @xml:id),
			attribute xml:id { $id 	},
			if ($format = 'txt')
			then attribute target { $data }
			else ()
		}
	let $old-id := $selection/id(string($data/@xml:id))
	let $status :=
		if ($format = 'xml' and not($data instance of element(tei:ptr)))
		then
			api:error(400, "Only tei:ptr can be posted here.")
		else ( 
			(: the POST is requesting a move of the xml:id, the old one should be deleted :)
			if (exists($old-id))
			then (
			  resp:remove($old-id),
			  update delete $old-id
			) 
			else (), 
			if ($node instance of element(j:selection))
			then (
				(: POST into selection = POST at beginning of selection :)
				if (empty($selection/tei:ptr))
				then update insert $ptr-with-xmlid into $selection
				else update insert $ptr-with-xmlid preceding $selection/tei:ptr[1],
				resp:add($doc//id($id), "editor", app:auth-user(), "location value")
			)
			else if ($node instance of element(tei:ptr))
			then (
				(: POST to ptr = POST after pointer :)
				update insert $ptr-with-xmlid following $node,
				resp:add($doc//id($id), "editor", app:auth-user(), "location value")
			)
			else 
				api:error(404, "ID not found", $index)
		)
	return
		if (local-name($status) = 'error')
		then $status
		else (
			response:set-status-code(if (exists($old-id)) then 204 else 201),
			response:set-header('Location', 
				let $u := tokenize($uri, '/')
				return string-join((
					subsequence($u, 1, count($u) - 1),
					if (not($index)) then 'selection' else (),
					$id), '/')
			) 
		) 
			
		
};

declare function local:delete(
	$selection as element(j:selection),
	$index as xs:string?,
	$format as xs:string?
	) as element()? {
	if (exists($index))
	then
		let $node := $selection/id($index)
		return
			if ($node)
			then (
				(: TODO: check for references! :)
				response:set-status-code(204),
				resp:remove($node),
				update delete $node
			)
			else
				api:error(404, "ID does not exist", $index)
	else
		api:error(405, "Method not supported with an empty or zero index.") 
		
};

if (api:allowed-method(('GET', 'POST', 'PUT', 'DELETE')))
then
	let $auth := api:request-authentication() or true()
	(: $user-name the user name in the request URI :)
	let $purpose := request:get-parameter('purpose', ())
	let $share-type := request:get-parameter('share-type', ())
	let $owner := request:get-parameter('owner', ())
	let $resource := request:get-parameter('resource', ())
	let $subresource := request:get-parameter('subresource', ())
	let $subsubresource := request:get-parameter('subsubresource', ())[.]
	let $format := request:get-parameter('format', 'xhtml')
	let $doc := data:doc($purpose, $share-type, $owner, $resource, 'xml', $local:valid-formats)
	let $method := api:get-method()
	return (
		if ($doc instance of document-node())
		then
			(: subsubresource does not exist, just get the whole thing :)
			let $selection := $doc//j:selection
			return
				if ($method = 'GET')
				then 
					if (not($format) or $format = ('xhtml', 'html')) 
					then local:get-menu($selection, $subsubresource)
					else local:get($selection, $subsubresource, $format)
				else 
					if ($format = ('xhtml', 'html'))
					then api:error(405, "Method not allowed with this format", $format)
					else
						if ($method = 'PUT')
						then local:put($selection, $subsubresource, $format)
						else if ($method = 'POST')
						then local:post($selection, $subsubresource, $format)
						else local:delete($selection, $subsubresource, $format)
		else 
			(: an error occurred and is in $doc :)
			$doc
	)
else 
	(:disallowed method:)
	api:error-message("Method not allowed")
