xquery version "1.0";
(:~ general support functions for the REST API
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 : $Id: api.xqm 766 2011-04-28 02:42:20Z efraim.feinstein $
 :) 
module namespace api="http://jewishliturgy.org/modules/api";

import module namespace response="http://exist-db.org/xquery/response";
import module namespace request="http://exist-db.org/xquery/request";

import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 

declare variable $api:default-max-results := 50;

(:~ the API allows POST to be used instead of PUT and DELETE 
 : if PUT and DELETE are not supported by the client. If so,
 : they are in the _method request parameter :)
declare function api:get-method(
	) {
	let $real-method := upper-case(request:get-method())
	let $alt-method := upper-case(request:get-parameter('_method', ()))
	return
	( 
		if ($real-method = 'POST' and $alt-method)
		then $alt-method
		else $real-method
	)
};

(:~ check if the calling method is allowed. If not, set the response error to 405
 : and an Allow header to the allowed methods
 : @param $methods A sequence of allowed methods
 :
 : This function is intended to be called early in the controller and no other consequential
 : calls should be made if it fails. 
 :)
declare function api:allowed-method(
	$methods as xs:string+
	) as xs:boolean {
	let $umethods := 
		for $umethod in $methods
		return upper-case($umethod)
	return
		if ($umethods = api:get-method())
		then true()
		else (
			false(),
			response:set-status-code(405),
			response:set-header('Allow', string-join($umethods, ', '))
		)
};


(:~ return true() is authenticated, false() if not :)
declare function api:request-authentication(
	) as xs:boolean {
	not(xmldb:get-current-user() = 'guest') or 
		xmldb:login('/db', app:auth-user(), app:auth-password(), false())
};

(:~ set a requirement for authentication. Intended to be the condition of an if statement that
 : surrounds the query.
 : @return true() if authenticated, false() if not; also, set response to 401 
 :)
declare function api:require-authentication(
	) as xs:boolean {
	if (api:request-authentication())
	then (
		true()
	)
	else (
		false(),
		response:set-status-code(401), 
    response:set-header('WWW-Authenticate', 'Basic') 
	)
};

(:~ set a requirement that a query is authenticated as a given user *or*
 : a user within a group, depending on the share-type
 :)
declare function api:require-authentication-as(
	$share-type as xs:string,
	$owner as xs:string,
	$can-tell-resource-exists as xs:boolean
	) as xs:boolean {
	if ($share-type = 'user')
	then api:require-authentication-as($owner, $can-tell-resource-exists)
	else api:require-authentication-as-group($owner, $can-tell-resource-exists)
};

(:~ set a requirement that the query is authenticated as a given user.
 : if not authenticated, return status 401.
 : if authenticated as the wrong user, 
 :	set the response code to 403 (if $can-tell-resource-exists) 
 :	or 404 if not($can-tell-resource-exists). 
 :)
declare function api:require-authentication-as(
	$user as xs:string,
	$can-tell-resource-exists as xs:boolean
	) as xs:boolean {
	if (api:require-authentication())
	then 
		if (app:auth-user() = $user)
		then true()
		else (
			false(),
			response:set-status-code(
				if ($can-tell-resource-exists) 
				then 403 
				else 404
			)
		)
	else false()
};

(:~ set a requirement that the query is authenticated as a user who is a member of a given group.
 : if not authenticated, return status 401.
 : if authenticated as the wrong user, 
 :	set the response code to 403 (if $can-tell-resource-exists) 
 :	or 404 if not($can-tell-resource-exists). 
 :)
declare function api:require-authentication-as-group(
	$group as xs:string,
	$can-tell-resource-exists as xs:boolean
	) as xs:boolean {
	if (api:require-authentication())
	then 
		let $user := app:auth-user()
		return
			if (xmldb:get-user-groups($user) = $group)
			then true()
			else (
				false(),
				response:set-status-code(
					if ($can-tell-resource-exists) 
					then 403 
					else 404
				)
			)
	else false()
};

declare function api:list(
	$title as element(title),
	$list-body as element(ul)+,
	$n-results as xs:integer) {	
	api:list($title, $list-body, $n-results, false(), false(), false())
};

(:~ list-type API 
 : @param $title API page title
 : @param $list-body Body of the list 
 : @param $n-results Number of total results in the list
 : @param $search-capable true() if the URI is searchable (default false())
 : @param $post-capable true() if the URI can be posted to (default false()) 
 : @param $tei-capable true() if the URI has an alternate TEI-only version (GET, PUT, DELETE) (default false())
 :)
declare function api:list(
	$title as element(title),
	$list-body as element(ul)+,
	$n-results as xs:integer,
	$search-capable as xs:boolean,
	$post-capable as xs:boolean,
	$tei-capable as xs:boolean
	) as element(html) {
	let $my-uri := request:get-uri()
	let $params := (
		let $params-string := 
			(: params string should include parameters that are not contained in the path :)
			for $p in request:get-parameter-names()[not(. = ('start', 'purpose', 'share-type', 'owner', 'resource', 'subresource', 'subsubresource', 'format'))]
			return concat($p, '=', request:get-parameter($p, ()))
		where exists($params-string)
		return
			concat('&amp;', string-join($params-string, '&amp;'))
		)
	let $start := xs:integer(request:get-parameter('start', 1))
	let $max-results := xs:integer(request:get-parameter('max-results', $api:default-max-results))
	return
		<html>
			<head>
				<title>{string($title)}</title>
				{
				(: add first, previous, next, and last links :)
				if ($start > 1 and $n-results >= 1)
				then (
					let $prev-start := max((1,$start - $max-results))
					return (
						<link rel="first" href="{$my-uri}?start=1{$params}"/>,
						<link rel="previous" href="{$my-uri}?start={string($prev-start)}{$params}"/>
					)
				)
				else (),
				if ($start + $max-results lt $n-results)
				then (
					<link rel="next" href="{$my-uri}?start={string($start + $max-results)}{$params}"/>,
					<link rel="last" href="{$my-uri}?start={string(1 + $n-results - $max-results)}{$params}"/>
				)
				else (),
				(: add data about where this page is in the search :)
				<meta name="start" content="{if ($n-results eq 0) then 0 else $start}"/>,
				<meta name="end" content="{min(($start + $max-results - 1, $n-results))}"/>,
				<meta name="results" content="{$n-results}"/>,
				if ($tei-capable)
				then
					<link rel="alternate" type="application/xml" href="{$my-uri}.xml"/>
				else ()
			}</head>
			<body>{
				<h1>{$title/node()}</h1>,
				<ul class="navigation">{
					(: add first, previous, next, and last links :)
					if ($start > 1)
					then (
						<li><a href="{$my-uri}?start=1{$params}">&lt;&lt;</a></li>,
						<li><a href="{$my-uri}?start={string(max((1,$start - $max-results)))}{$params}">&lt;</a></li>
					)
					else (),
					if ($start + $max-results lt $n-results)
					then (
						<li><a href="{$my-uri}?start={string($start + $max-results)}{$params}">&gt;</a></li>,
						<li><a href="{$my-uri}?start={string(1 + $n-results - $max-results)}{$params}">&gt;&gt;</a></li>
					)
					else ()
				}</ul>,
				$list-body,
				(: add a search box to search capable APIs :)
				if ($search-capable)
				then 
					<form action="{my-uri}" method="get">
						<input type="text" name="q"/>
						<input type="submit" value="Search" />
					</form>
				else (),
				(: add a POST box to POST-capable APIs :)
				if ($post-capable)
				then
					<form action="{$my-uri}" accept="application/xml" method="post">
						<textarea type="text" />
						<input type="submit" value="POST" />
					</form>
				else ()
			}</body>
		</html>
};

declare function api:list-item(
	$description as item(),
	$link as xs:string,
	$formats as xs:string*
	) as element(li) {
	api:list-item($description, $link, $formats, (), ())
};

(:~ add a list item to a list
 : @param $description description: may be text or HTML
 : @param $link main link to the item
 : @param $formats alternative formats
 : @param $alt-link alternative link to the item (eg, database location)
 : @param $alt-description Description of the alternate link
 :)
declare function api:list-item(
	$description as item()+,
	$link as xs:string,
	$formats as xs:string*,
	$alt-link as xs:string?,
	$alt-description as item()*
	) as element(li) {
	<li>
		<a href="{$link}">{$description}</a>
		{
		for $format in $formats
		let $lformat := lower-case($format) 
		order by $lformat
		return ('[', <a href="{$link}.{$format}">{$lformat}</a>, ']'),
		if ($alt-link)
		then 
			('(', <a class="alt" href="{$alt-link}">{$alt-description}</a>, ')')
		else ()
		}
	</li>
};

(:~ output an API error and set the HTTP response code 
 : @param $status-code return status
 : @param $message return message (text preferred, but may contain XML)
 : @param $object (optional) error object
 :)
declare function api:error(
	$status-code as xs:integer?,
	$message as item()*, 
	$object as item()*
	) as element() {
	if ($status-code)
	then response:set-status-code($status-code)
	else (),
	api:serialize-as('xml'),
	<error xmlns="">
		<path>{request:get-uri()}</path>
		<message>{$message}</message>
		{
			if (exists($object))
			then
				<object>{$object}</object>
			else ()
		}
	</error>
};

declare function api:error(
	$status-code as xs:integer?,
	$message as item()* 
	) as element() {
	api:error($status-code, $message, ())
};

(:~ set the error message, without changing the response code 
 : this function may be used when another api:* function already set the code
 :)
declare function api:error-message(
	$message as item() 
	) as element() {
	api:error((), $message, ())
};

declare function api:error-message(
	$message as item(),
	$object as item()?
	) as element() {
	api:error((), $message, $object)
};

(:~ dynamically declare serialization options as txt, tei, xml, xhtml, or html (xhtml w/o indent)
 : @param $serialization type of serialization
 :)
declare function api:serialize-as(
	$serialization as xs:string
	) as empty() {
	let $ser := lower-case($serialization)
	let $options :=
		if ($ser = ('txt', 'text'))
		then
			'method=text media-type=text/plain'
		else if ($ser = 'css')
		then 
			'method=text media-type=text/css'
		else if ($ser = ('xml','tei'))
		then
			'method=xml media-type=application/xml omit-xml-declaration=no indent=yes'
		else if ($ser = 'xhtml')
		then
		  'method=xhtml media-type=text/html omit-xml-declaration=no indent=yes'
		 (:
        doctype-public="-//W3C//DTD&#160;XHTML&#160;1.1//EN"
        doctype-system="http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"'
        :)
    else if ($ser = 'html')
    then
    	'method=xhtml media-type=text/html omit-xml-declaration=no indent=no'
		else
			error(xs:QName('err:INTERNAL'),concat('Undefined serialization option: ', $serialization))
	return
		util:declare-option('exist:serialize', $options) 
};
