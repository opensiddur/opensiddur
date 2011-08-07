xquery version "1.0";
(:~ Format a given resource, given the compile query parameter
 :
 : Available formats: xml
 : Method: POST
 : Status:
 :	200 OK 
 : 	202 Accepted, request is queued for processing
 :	401, 403 Authentication
 :	404 Bad format 
 : Returns Location header
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
import module namespace format="http://jewishliturgy.org/modules/format"
	at "/code/modules/format.xqm";
import module namespace jcache="http://jewishliturgy.org/modules/cache"
	at "/code/modules/cache-controller.xqm";
	
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $local:valid-formats := ('xml');
declare variable $local:valid-compile-targets := ('fragmentation', 'debug-data-compile', 'debug-list-compile', 'xhtml', 'html');

declare function local:setup-output-share(
	$doc as document-node(),
	$output-share as xs:string
	) as xs:string {
	let $document-name := util:document-name($doc)
	let $group-collection := concat('/group/', $output-share)
	let $output-share-path := concat($group-collection, '/output/', replace($document-name, '\.xml$', ''))
	return (
		app:make-collection-path(
			$output-share-path, 
			'/db',
			xmldb:get-owner($group-collection),
			xmldb:get-group($group-collection),
			xmldb:get-permissions($group-collection)
			),
		$output-share-path
	)
};

declare function local:post(
	$doc as document-node(),
	$compile as xs:string,
	$output-share as xs:string
	) as item() { 
	let $document-uri := document-uri($doc)
	let $cached-document-uri := jcache:cached-document-path($document-uri)
	let $output-share-path := local:setup-output-share($doc, $output-share) 
	let $document-name := util:document-name($document-uri)
	let $extension := 
		if (starts-with($compile, 'debug'))
		then '.debug.xml'
		else if ($compile = ('xhtml', 'html'))
		then '.xhtml'
		else '.xml'
	let $output-document-name := replace($document-name, '\.xml$', $extension)
	let $output-document-path := 
		concat($output-share-path, '/', $output-document-name)
	return (
		jcache:cache-all($document-uri),
		if ($compile = 'fragmentation')
		then
			(
				xmldb:copy(util:collection-name($cached-document-uri), $output-share-path, $document-name),
				(: send back the cached copy of the document :)
				response:set-status-code(200),
				response:set-header('Location', data:db-path-to-api($output-document-path)),
				doc($cached-document-uri)
			)
		else (
			let $compiled := format:compile($cached-document-uri, $compile, ())
			return (
				if (xmldb:store($output-share-path, $output-document-name, $compiled))
				then (
					response:set-status-code(200),
					if ($compile = ('html','xhtml'))
					then
						xmldb:copy('/code/transforms/format/xhtml', $output-share-path, 'style.css')
					else (),
					response:set-header('Location', data:db-path-to-api($output-document-path)),
					$compiled
				)
				else api:error(500, "Cannot store result.", concat($output-share-path, '/', $output-document-name))
			)
		)
	)
};

if (api:allowed-method('POST'))
then
	let $purpose := request:get-parameter('purpose', ())
	let $share-type := request:get-parameter('share-type', ())
	let $owner := request:get-parameter('owner', ())
	let $resource := request:get-parameter('resource', ())
	let $format := request:get-parameter('format', 'txt')
	let $compile := request:get-parameter('compile', ())
	let $output-share := request:get-parameter('output', ())
	return
		if ($output-share)
		then
			if (api:require-authentication-as-group($output-share, true()))
			then
				if ($compile = $local:valid-compile-targets)
				then
					let $doc := data:doc($purpose, $share-type, $owner, $resource, 'xml', $local:valid-formats)
					return
						if ($doc instance of document-node())
						then
							local:post($doc, $compile, $output-share)
						else 
							(: an error occurred and is in $doc :)
							$doc
				else api:error(400, "Bad or missing compile target format", $compile)
			else
				api:error-message("Authentication error. Not logged in or output query parameter is required to be a group that you are a member of.")
		else
			api:error(400, "Missing output query parameter.")
else 
	(:disallowed method:)
	api:error-message("Method not allowed")
