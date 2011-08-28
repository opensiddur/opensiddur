xquery version "1.0";
(:~ Format the resource.
 : Required parameters:
 :  to= format
 :  output= group
 :
 : Available formats: xml
 : Method: POST
 : Status:
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

declare default element namespace "http://www.w3.org/1999/xhtml";
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
	let $output-share-path := local:setup-output-share($doc, $output-share) 
  let $collection-name := util:collection-name($doc)
	let $document-name := util:document-name($doc)
  let $status-path := 
    concat($output-share-path, "/status")
  let $style := request:get-parameter("style","style.css")
	return (
    format:enqueue-compile(
      $collection-name,
      $document-name,
      $output-share-path,
      $compile,
      $style
    ),
    response:set-status-code(202),
  	response:set-header('Location', data:db-path-to-api($status-path)),
    api:list(
      element title {concat("Compile ", request:get-uri())},
      element ul {
        api:list-item(
          "Status",
          data:db-path-to-api($status-path),
          "GET",
          api:html-content-type(),
          ()
        )
      },
      0,
      false(),
      "POST",
      (),
      api:form-content-type()
    )
	)
};

if (api:allowed-method("POST"))
then
	let $purpose := request:get-parameter('purpose', ())
	let $share-type := request:get-parameter('share-type', ())
	let $owner := request:get-parameter('owner', ())
	let $resource := request:get-parameter('resource', ())
	let $format := request:get-parameter('format', 'txt')
	let $compile := api:get-parameter('to', ())
	let $output-share := api:get-parameter('output', ())
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
