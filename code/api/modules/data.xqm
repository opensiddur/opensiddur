xquery version "3.0";
(:~ support functions for the REST API for data retrieval
 :
 : Open Siddur Project
 : Copyright 2011-2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :) 
module namespace data="http://jewishliturgy.org/modules/data";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/code/modules/paths.xqm";
import module namespace resp="http://jewishliturgy.org/modules/resp"
  at "/code/modules/resp.xqm";
  
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace error="http://jewishliturgy.org/errors";
declare namespace exist="http://exist.sourceforge.net/NS/exist";

(:~ base of all data paths :)
declare variable $data:path-base := "/data";

(:~ convert a given path from an API path (may begin /code/api/data, /data or may be truncated) to a database path
 : works only to find the resource. 
 : @param $api-path API path  
 :)
declare function data:api-path-to-db(
	$api-path as xs:string 
	) as xs:string {
	let $tok := tokenize(replace($api-path, '^/(code/api/)?data/', ''), '/')
	let $share-type :=
		if ($tok[2] = 'group' or count($tok)=1)
		then 'group'
		else error(xs:QName('error:INPUT'), concat('api-path-to-db: Input has an invalid share-type. input=', $api-path))
	let $owner := $tok[3]
	let $purpose := $tok[1]
	let $resource :=
		let $resource-index := 4
		(:	if ($purpose = 'output')
			then 5
			else 4:)
		let $resource-noext := replace($tok[$resource-index], '(\.\S+)?$', '')
		let $ext := substring-after($tok[$resource-index], '.')
		return 
			concat(
				if ($purpose = 'output')
				then
					(: output paths reference collections, not xml files directly :) 
					concat($resource-noext, '/')
				else '',
				$resource-noext, 
        (: add an extension if the resource is not blank :)
        if ($resource-noext)
        then concat('.', 
          if ($ext) 
          then $ext 
          else if ($purpose = "output")
          then "xhtml"
          else "xml")
        else ''
			)[.]
	let $xmlid := 
		if ($tok[5] = 'id')
		then $tok[6]
		else ()
	return
		concat('/', 
			string-join(($share-type, $owner, $purpose,
				if ($xmlid)
				then concat($resource, '#', $xmlid)
				else $resource), '/'))
};

(:~ Convert a database path to a path in the API
 : @param $db-path database path to convert
 :)
declare function data:db-path-to-api(
	$db-path as xs:string
	) as xs:string {
	let $tok := tokenize(replace($db-path, '^(/db)?/', ''), '/')
	let $share-type := 
		if ($tok[1] = 'group')
		then 'group'
		else error(xs:QName('error:INPUT'), concat('db-path-to-api: Input has an invalid share-type. input=', $db-path))
	let $owner := $tok[2]
	let $purpose := $tok[3]
	let $resource-token :=
		(:if ($purpose = 'output')
		then 
			concat($tok[4], '/', $tok[5])
		else :) 
		$tok[4]
	let $resource := 
		replace(
			if (contains($resource-token, '#'))
			then substring-before($resource-token, '#')
			else $resource-token,
			'\.xml$', '')
	let $xmlid := substring-after($resource-token, '#') 
	return
	(
		string-join((
			'/code/api/data',
			$purpose, $share-type, $owner, $resource, 
			if ($xmlid) 
			then concat('id/', $xmlid)
			else ()
			),
			'/')
	)
};

(:~ convert an API path to component parts, returned inside an XML element
 :)
declare function data:path-to-parts(
  $path as xs:string
  ) as element(data:path) {
  <data:path>{
    (: split the path at the wildcard. Anything before is part of the full path, after is 
     :  part of the subresource :)
    let $wildcard := tokenize($path, '/\.\.\./')
    let $before-wildcard := $wildcard[1]
    let $after-wildcard := $wildcard[2]
    let $after-wildcard-tokens := tokenize($after-wildcard, '/')[.]
	  let $path-tokens := tokenize(replace($before-wildcard, '^(/code/api/data)?/', ''), '/')[.]
    let $n-tokens := count($path-tokens)
    let $purpose := $path-tokens[1]
    let $share-type := $path-tokens[2]
    let $owner := $path-tokens[3]
    let $resource := 
      if ($n-tokens = 4 and contains($path-tokens[4], '.'))
      then substring-before($path-tokens[4], '.')
      else $path-tokens[4]
    let $subresource := 
      if ($after-wildcard)
      then
        replace($after-wildcard[1], '\.(.*)$', '')
      else
        if ($n-tokens = 5 and contains($path-tokens[5], '.'))
        then substring-before($path-tokens[5], '.')
        else $path-tokens[5]
    let $subsubresource := 
      if ($after-wildcard)
      then
        replace($after-wildcard[2], '\.(.*)$', '')
      else
        if ($n-tokens = 6 and contains($path-tokens[6], '.'))
        then substring-before($path-tokens[6], '.')
        else $path-tokens[6]	
    let $format := 
      let $last-token := ($after-wildcard[last()], $path-tokens[last()])[1]
      return
        if (contains($last-token, '.'))
        then substring-after($last-token, '.')
        else ()
    return (
      <data:purpose>{$purpose}</data:purpose>,
      <data:share-type>{$share-type}</data:share-type>,
      <data:owner>{$owner}</data:owner>,
      <data:resource>{$resource}</data:resource>,
      <data:subresource>{$subresource}</data:subresource>,
      <data:subsubresource>{$subsubresource}</data:subsubresource>,
      <data:format>{$format}</data:format>
    )
  }</data:path>
};

(:~ convert an API path into exist:add-parameter elements 
 :)
declare function data:path-to-parameters(
	$path as item()
	) as element(exist:add-parameter)+ {
  let $tokenized-path as element(data:path) :=
    if ($path instance of element(data:path))
    then $path
    else data:path-to-parts($path)
	return $tokenized-path/(
		<exist:add-parameter name="purpose" value="{data:purpose}"/>,
		<exist:add-parameter name="share-type" value="{data:share-type}"/>,
		<exist:add-parameter name="owner" value="{data:owner}"/>,
		<exist:add-parameter name="resource" value="{data:resource}"/>,
		<exist:add-parameter name="subresource" value="{data:subresource}"/>,
		<exist:add-parameter name="subsubresource" value="{data:subsubresource}"/>,
		<exist:add-parameter name="format" value="{data:format}"/>
	)
}; 

(:~ return a document based on sharing parameters.
 : If the document doesn't exist or is inaccessible, return an error element and set an error code.
 : @param $purpose Purpose 
 : @param $share-type Share type, must exist
 : @param $owner Owner, must exist
 : @param $resource Resource name
 : @param $format Format of database document, default is xml
 :)
declare function data:doc(
	$purpose as xs:string,
	$share-type as xs:string,
	$owner as xs:string,
	$resource as xs:string,
	$format as xs:string?,
	$valid-formats as xs:string*
	) as node() {
	if (data:is-valid-share-type($share-type))
	then
		if (data:is-valid-owner($share-type, $owner))
		then
			if (api:require-authentication-as($share-type, $owner, true()))
			then
				if (empty($valid-formats) or $format = $valid-formats)
				then 
					let $top-collection := data:top-collection($share-type, $owner)
					let $doc-path := app:concat-path(($top-collection, $purpose, 
						concat($resource, '.', ($format, 'xml')[1] ) 
						))
					return (
						if ($paths:debug)
						then
							util:log-system-out(('$doc-path=', $doc-path))
						else (),
						if (doc-available($doc-path))
						then
							doc($doc-path)
						else
							api:error(404, "Document not found")
					)
				else 
					api:error(404, "Invalid format", $format)
			else api:error-message("Authentication required")
		else
			api:error(404, "Invalid owner", $owner)
	else
		api:error(404, "Invalid share type", $share-type)
};

(:~ return whether the share type is valid :)
declare function data:is-valid-share-type(
	$share-type as xs:string?
	) as xs:boolean {
	empty($share-type) or $share-type = ('group', '')
};

(:~ return whether the owner is valid :)
declare function data:is-valid-owner(
	$share-type as xs:string?,
	$owner as xs:string?
	) as xs:boolean {
	if (exists($share-type) and exists($owner))
	then 
		xmldb:collection-available(
			app:concat-path(
				$share-type, $owner
			)
		)
	else true()
};

(:~ return the top level collection(s) that need to be searched :)
declare function data:top-collection(
	$share-type as xs:string?,
	$owner as xs:string?
	) as xs:string* {
	if ($share-type)
	then
		app:concat-path(concat('/', $share-type), $owner)
	else
		(: no share-type and no owner, need all accessible top-level collections :) 
    '/group'
	
};

(:~ if $node exists, replace it with $new-content.
 : if $node does not exist, insert $new-content into $parent
 : return 'inserted' if inserted, 'replaced' if replaced
 :)
declare function data:update-replace-or-insert(
	$node as node()?,
	$parent as element(),
	$new-content as node()
	) as xs:string {
	let $doc := root($node)
	return (
  	if (exists($node))
  	then (
  	  if ($node/@xml:id)
  	  then resp:remove($node)
  	  else (),
  		update replace $node with $new-content,
  		'replaced'
  	)
  	else (
  		update insert $new-content into $parent,
  		'inserted'
  	),
  	if ($new-content/@xml:id)
  	then
  	  resp:add($doc//id($new-content/@xml:id), 
  	    "editor", app:auth-user(), "location value")
  	else ()
  )
};

(:~ if $node exists, replace its value with $new-content.
 : if $node does not exist, insert $new-content into $parent with $wrapper element
 : return 'inserted' if inserted, 'replaced' if replaced
 :)
declare function data:update-value-or-insert(
	$node as element()?,
	$parent as element(),
	$wrapper as element(),
	$new-content as item()
	) as xs:string {
	let $doc := (root($node), root($parent))[1]
	return 
  	if (exists($node))
  	then (
  	  for $n in $node/descendant::*[@xml:id]
  	  return
  	    resp:remove($n),
  		update value $node with $new-content,
  		let $id := $doc//id(($new-content, $node)/@xml:id[1])
  		where exists($id)
  		return
  		  resp:add($id, "editor", app:auth-user(), "value"),
  		'replaced'
  	)
  	else 
  	  let $xmlid := 
  	    ($wrapper/@xml:id/string(), 
        concat("_", util:uuid()))[1]
      return (
  		update insert 
  			element {node-name($wrapper)} {
  				$wrapper/(@* except @xml:id),
  				attribute xml:id { $xmlid },
  				$new-content
  			} into $parent,
  			resp:add($doc//id($xmlid), "editor", app:auth-user(), "location value"),
  			'inserted'
  		)
};

(:~ given an id, find which virtual resource to forward to :)
declare function data:forward-by-id(
	$purpose as xs:string,
	$share-type as xs:string,
	$owner as xs:string,
	$resource as xs:string,
	$id as xs:string) as xs:string? {
	let $doc := data:doc($purpose, $share-type, $owner, $resource, (), ())
	let $by-id := $doc/id($id)
	return
		(
		if ($paths:debug)
		then util:log-system-out(('data:forward-by-id(): $id = ', $id, ' $doc = ', document-uri($doc), ' $by-id =', $by-id))
		else (),
		if ($doc instance of element(error))
		then ()
		else 
			if ($by-id/parent::j:selection)
			then 'selection'
			else
				(: don't know - use generic id processing :) 
				'id'  
		)
};

declare function local:resource-name-from-title-and-number(
  $title as xs:string,
  $number as xs:integer
  ) as xs:string {
  string-join(
    (encode-for-uri($title), 
    if ($number)
    then ("-", string($number))
    else (), ".xml"),
    "")
};

declare function local:find-duplicate-number(
  $type as xs:string,
  $title as xs:string,
  $n as xs:integer
  ) as xs:integer {
  if (exists(collection(concat($data:path-base, "/", $type))
    [util:document-name(.)=
      local:resource-name-from-title-and-number($title, $n)]
    ))
  then local:find-duplicate-number($type, $title, $n + 1)
  else $n
};

(:~ make the path of a new resource
 : @param $type The category of the resource (original|transliteration, eg)
 : @param $title The resource's human-readable title
 : @return (collection, resource)
 :)
declare function data:new-path-to-resource(
  $type as xs:string,
  $title as xs:string
  ) as xs:string+ {
  let $date := current-date()
  let $resource-name := 
    local:resource-name-from-title-and-number($title, 
      local:find-duplicate-number($type, $title, 0))
  return (
    (: WARNING: the format-date() function works differently 
     : from the XSLT spec!
     : In the spec, the format string should be:
     : [Y0001]/[M01]
     :)
    app:concat-path(($data:path-base, $type, xsl:format-date($date, "YYYY/MM"))), 
    $resource-name
  ) 
};

(:~ make the path of a new resource
 : @param $type The category of the resource (original|transliteration, eg)
 : @param $title The resource's human-readable title
 :)
declare function data:new-path(
  $type as xs:string,
  $title as xs:string
  ) as xs:string {
  let $new-paths := data:new-path-to-resource($type, $title)
  return
    string-join($new-paths, "/")
};

(:~ return a document from the collection hierarchy for $type 
 : given a resource name $name (without extension) :)
declare function data:doc(
  $type as xs:string,
  $name as xs:string
  ) as document-node()? {
  collection(app:concat-path($data:path-base, $type))
    [replace(util:document-name(.), "\.([^.]+)$", "")=$name]
};