xquery version "1.0";
(: api for original data, if a resource is given
 : 
 : Parameters:
 : 	share-type = user|group (required)
 :	owner = name of owner to limit listing to (required)
 :  resource = name of resource
 :	subresource = resource part that is requested
 :	format = request format
 : 
 : Method: GET
 : Formats: Blank (menu), XML, TXT (for some subresources)
 : Return: 
 :		200 Return menu of subresources
 :		401 (you are not logged in and requested a resource that requires login)
 :		403 (you are logged in, but you can't access the resource), 
 :		404 Resource, subresource, or format does not exist
 :
 : Method: PUT
 : Input: Content
 : Create or edit an XML resource or subresource at the given position 
 : Return:
 :		204	Edited successfully
 :		401 Access to the resource requires authorization
 :		403 You are logged in, but you can't access the resource
 :		404 Resource, subresource, or format does not exist
 : 
 : Method: DELETE (not available on subresources)
 : Return:
 :		204 Successfully deleted
 :		401 Access to the resource requires authorization
 :		403 You are logged in, but you can't access the resource
 :		404 Resource, subresource, or format does not exist
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
	at "/code/api/modules/data.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/code/modules/paths.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

declare function local:invalid-format(
	$invalid as xs:string
	) {
	api:error(404, "Format not supported.", $invalid)
};

declare function local:get-menu(
	$doc as document-node(),
	$share-type as xs:string,
	$owner as xs:string,
	$resource as xs:string
	) as element() {
	let $base := concat('/code/api/data/original/', string-join(($share-type, $owner, $resource), '/'))
	let $list :=
		<ul class="common" xmlns="http://www.w3.org/1999/xhtml">{
			api:list-item('Primary language', concat($base, '/lang'), 
        ("GET", "PUT", "DELETE"), 
        ("application/xml","text/plain"),
        ("application/xml","text/plain")
      ),
			api:list-item('Title', concat($base, '/title'),
        ("GET", "PUT", "DELETE"), 
        (api:tei-content-type("tei:title"), "text/plain"),
        (api:tei-content-type("tei:title"), "text/plain")
      ),
			api:list-item('Subtitle', concat($base, '/subtitle'),
        ("GET", "PUT", "DELETE"), 
        (api:tei-content-type("tei:title"), "text/plain"),
        (api:tei-content-type("tei:title"), "text/plain")
      ),
			api:list-item('License URI', concat($base, '/license'),
        ("GET", "PUT", "DELETE"), 
        (api:tei-content-type("tei:ptr"), "text/plain"),
        (api:tei-content-type("tei:ptr"), "text/plain")
      ),
			api:list-item('Front matter', concat($base, '/front'),
        ("GET", "PUT"), 
        (api:tei-content-type("tei:front")),
        api:tei-content-type("tei:front")
      ),
			api:list-item('Selection', concat($base, '/selection'), 
        ("GET", "POST"), 
        (api:tei-content-type("j:selection")),
        api:tei-content-type("tei:ptr")
      ),
			api:list-item('Text repository', concat($base, '/repository'),
        ("GET", "POST"), 
        (api:html-content-type(), api:tei-content-type("j:repository")),
        api:tei-content-type("tei:seg")
      ),
			api:list-item('Compile', concat($base, '/compile'),
        ("POST"), 
        ("text/plain", "application/xml"),
        api:html-content-type()
      ),
      api:list-item("XML Navigation", concat($base, "/nav"),
        ("GET"), 
        api:html-content-type(),
        ()
      )
		}</ul>
	return (
		api:serialize-as('xhtml'),
		api:list(
			let $title := $doc//tei:title[not(@type) or @type='main']
			return
				<title xmlns="http://www.w3.org/1999/xhtml">Resources for <span>{
					$title/@xml:lang,
					if ($title/@xml:lang)
					then attribute lang {string($title/@xml:lang)}
					else (),
					string($title)
				}</span></title>,
			$list,
      0,
      true(),
      "GET", 
      (api:html-content-type(), api:tei-content-type()), ()
		)
	)
}; 

declare function local:get(
	$share-type as xs:string, 
	$owner as xs:string, 
	$resource as xs:string, 
	$subresource as xs:string?, 
	$format as xs:string?
	) as node() {
	if ($paths:debug)
	then
		util:log-system-out(
		<debug source="resource.xql">
			<share-type>{$share-type}</share-type>
			<owner>{$owner}</owner>
			<resource>{$resource}</resource>
			<subresource>{$subresource}</subresource>
			<format>{$format}</format>
		</debug>
		)
	else (),
	let $collection := app:concat-path(data:top-collection($share-type, $owner), 'original')
	let $res-name := concat($resource, '.xml')
	let $path := app:concat-path($collection, $res-name)
	return
		if (api:require-authentication-as($share-type, $owner, true()))
		then
			if (doc-available($path))
			then
				let $doc := doc($path)
				return
					if (not($subresource))
					then
						if (not($format))
						then
							local:get-menu($doc, $share-type, $owner, $resource)
						else if ($format = 'xml')
						then (
							api:serialize-as('xml'),
							$doc
						)
						else
							local:invalid-format($format)
					else
						local:get-subresource($doc,	$subresource,	$format)
			else 
				api:error(404, "Resource not found", $path)
		else
			api:error-message("Proper authentication required")
};

(:~ return a reference to the subresource affected by the request :)
declare function local:get-subresource-reference(
	$doc as document-node(), 
	$subresource as xs:string
	) as node()? {
	let $by-id := $doc/id($subresource)
	return
		if (exists($by-id))
		then $by-id
		else api:error(404, "Subresource not found", $subresource)
};

declare function local:get-subresource(
	$doc as document-node(), 
	$subresource as xs:string, 
	$format as xs:string?
	) as item()? {
	let $node := local:get-subresource-reference($doc, $subresource)
	return
		if (local-name($node) = 'error')
		then
			(: return the error :) 
			$node
		else 
			if (exists($node))
			then
				(: only xml available :)
				if ($format = 'xml' or empty($format))
				then (
					api:serialize-as('xml'),
					$node
				)
				else
					local:invalid-format($format)
			else
				api:error(404, "Subresource not found.", $subresource)
		
};

declare function local:put(
	$share-type as xs:string, 
	$owner as xs:string, 
	$resource as xs:string, 
	$subresource as xs:string?, 
	$format as xs:string?
	) as element()? {
	()
};

declare function local:delete(
	$share-type as xs:string, 
	$owner as xs:string, 
	$resource as xs:string, 
	$subresource as xs:string?, 
	$format as xs:string?
	) as element()? {
	(: TODO: determine if the resource is addressed elsewhere :)
	if ($paths:debug)
	then
		util:log-system-out('resource: in delete.')
	else (),
	if (not($subresource))
	then 
		if (string($format) = ('xml', ''))
		then
			let $doc := data:doc('original', $share-type, $owner, $resource, 'xml', ())
			return	
				if ($doc instance of document-node())
				then
					let $coll-name := util:collection-name($doc)
					let $doc-name := util:document-name($doc)
					return (
						if ($paths:debug)
						then
							util:log-system-out('resource: deleting now successfully.')
						else (),
						response:set-status-code(204),
						xmldb:remove($coll-name, $doc-name)
					)
				else 
					$doc
		else
			api:error(404, "Format is incorrect.", $format)
	else
		api:error(404, "Subresource not supported", $subresource)
};

if (api:allowed-method(('GET', 'PUT', 'DELETE')))
then
	let $auth := api:request-authentication() or true()
	(: $user-name the user name in the request URI :)
	let $share-type := request:get-parameter('share-type', ())
	let $owner := request:get-parameter('owner', ())
	let $resource := request:get-parameter('resource', ())
	let $subresource := request:get-parameter('subresource', ())
	let $format := request:get-parameter('format', 
		if ($subresource)
		then 'xml'
		else 'xhtml')
	let $method := api:get-method()
	return
		if (data:is-valid-share-type($share-type))
		then 
			if (data:is-valid-owner($share-type, $owner))
			then
				if ($method = 'GET')
				then local:get($share-type, $owner, $resource, $subresource, $format)
				else if ($method = 'PUT') 
				then local:put($share-type, $owner, $resource, $subresource, $format)
				else 
					(: the only valid remaining method is delete :)
					local:delete($share-type, $owner, $resource, $subresource, $format)
			else
				api:error(404, concat("Invalid owner for the given share type ", $share-type), $owner)
		else
			api:error(404, "Invalid share type. Acceptable values are 'group' and 'user'", $share-type) 
else
	(: disallowed method :) 
	()
