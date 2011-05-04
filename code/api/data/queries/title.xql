xquery version "1.0";
(:~ Title/subtitle: manages the information both in the front matter 
 : and the header 
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
 : $Id: title.xql 769 2011-04-29 00:02:54Z efraim.feinstein $
 :)
import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
	at "/code/api/modules/data.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/code/modules/paths.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $local:valid-formats := ('xml', 'txt');

declare function local:get(
	$node as element(tei:title)?,
	$subresource as xs:string,
	$format as xs:string?
	) as item() {
	if ($paths:debug)
	then
		util:log-system-out(('title: $subresource =', $subresource, ' $format=', $format))
	else (),
	if ($format = 'xml')
	then (
		api:serialize-as('xml'),
		($node, 
		<tei:title xml:lang="">{
			attribute type {
				if ($subresource = 'title')
				then 'main'
				else 'sub'
			}
		}</tei:title>)[1]
	)
	else (
		api:serialize-as('txt'),
		text {string($node)}
	)
};

declare function local:put(
	$doc as document-node(),
	$node-main as element(tei:title)?,
	$node-front as element(tei:titlePart)?,
	$subresource as xs:string,
	$format as xs:string?
	) as empty() {
	let $content := request:get-data()
	let $type := 
		if (not($content/@type))
		then 
			attribute type {
				if ($subresource = 'title')
				then 'main'
				else 'sub'
			}
		else ()
	return (
		response:set-status-code(204),
		if ($format = 'xml')
		then (
			if (
				data:update-replace-or-insert(
					$node-main,
					$doc//tei:titleStmt,
					element tei:title {
						$content/@*,
						$type,
						$content/node()
					}
				) or
				data:update-replace-or-insert(
					$node-front,
					$doc//tei:docTitle,
					element tei:titlePart {
						$content/@*,
						$type,
						$content/node()
					}
				)
			)
			then () else ()
		)
		else (
			if (
				data:update-value-or-insert(
					$node-main,
					$doc//tei:titleStmt,
					element tei:title {
						$content/@*,
						$type
					},
					string($content)
				)
				or
				data:update-value-or-insert(
				 $node-front, 
				 $doc//tei:docTitle,
				 <tei:titlePart>{
				 	$content/@*,
				 	$type
				 }</tei:titlePart>,
				 string($content)
				)
			)
			then () else ()
		)
		
	) 
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
	let $format := (request:get-parameter('format', 'xml')[.], 'xml')[1]
	let $doc := data:doc($purpose, $share-type, $owner, $resource, 'xml', $local:valid-formats)
	let $method := api:get-method()
	return
		if ($doc instance of document-node())
		then
			let $node-main :=
				if ($subresource = 'title')
				then 
					$doc//tei:title[not(@type) or @type='main']
				else
					$doc//tei:title[@type='sub']
			let $node-front :=
				if ($subresource = 'title')
				then 
					$doc//tei:docTitle/tei:titlePart[not(@type) or @type='main']
				else
					$doc//tei:docTitle/tei:titlePart[@type='sub']
			return
				if ($method = 'GET')
				then local:get($node-main, $subresource, $format)
				else local:put($doc, $node-main, $node-front, $subresource, $format)
		else 
			(: an error occurred and is in $doc :)
			$doc
else 
	(:disallowed method:)
	api:error-message("Method not allowed")
