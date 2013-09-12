xquery version "3.0";
(:~ general support functions for the REST API
 :
 : Open Siddur Project
 : Copyright 2011-2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :) 
module namespace api="http://jewishliturgy.org/modules/api";

import module namespace app="http://jewishliturgy.org/modules/app"
	at "app.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 

declare namespace http="http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare variable $api:default-max-results := 50;

(:~ the API allows POST to be used instead of PUT and DELETE 
 : if PUT and DELETE are not supported by the client. If so,
 : they are in the _method request parameter *or* in the X-HTTP-Method-Override header :)
declare function api:get-method(
	) as xs:string? {
	let $real-method as xs:string? := upper-case(request:get-method())
	let $alt-method as xs:string? := upper-case(
    (
      request:get-header('X-HTTP-Method-Override'),
      request:get-parameter('_method', ())
    )[1]
  )
	return
	( 
		if ($real-method = 'POST' and $alt-method)
		then $alt-method
		else $real-method
	)
};

(:~ check if the calling method is allowed. If not, set the response error to 405.
 : Add an Allow header to the allowed methods
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
	return (
		if ($umethods = api:get-method())
		then true()
		else (
			false(),
			response:set-status-code(405)
		),
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
    response:set-header('WWW-Authenticate', 'Basic realm="opensiddur"')
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
			if (sm:get-user-groups($user) = $group)
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

declare function local:content-type-priority(
  $base-value as xs:double,
  $mime-tokens as xs:string+,
  $param-tokens as xs:string*
  ) as xs:double {
  $base-value
  - .0001 * count($mime-tokens[. = "*"]) 
  + .00001 * count($param-tokens[not(matches(., "^\s*q"))])
};

declare function api:parse-content-types(
  $ct as xs:string
  ) {
  local:parse-content-types($ct)
};

(:~ construct a structure of content types sorted by request priority :)
declare function local:parse-content-types(
  $ct-string as xs:string
  ) as element(api:content-type)* {
  for $content-type in tokenize($ct-string, ',')
  let $tokens := tokenize($content-type, ';')
  let $mime-tokens := tokenize(normalize-space($tokens[1]), '/')
  let $mime-type := 
    (
      <api:major>{$mime-tokens[1]}</api:major>,
      <api:minor>{$mime-tokens[2]}</api:minor>
    )
  let $param-tokens := subsequence($tokens, 2)
  let $parameters :=
    for $param in $param-tokens
    let $ns := normalize-space($param)
    let $t := tokenize($ns, "=")
    let $name := $t[1]
    let $value := $t[2]
    return 
      if ($name = "q")
      then
        <api:priority>{
          local:content-type-priority($value, $mime-tokens, $param-tokens)
        }</api:priority>
      else
        <api:param name="{$name}">{$value}</api:param>
  let $ct :=
    <api:content-type>{
      $mime-type,
      $parameters,
      if (exists($parameters/self::api:priority))
      then ()
      else <api:priority>{local:content-type-priority(1.0, $mime-tokens, $param-tokens)}</api:priority>
    }</api:content-type>
  order by $ct/api:priority descending
  return $ct
};

declare function api:get-accept-format(
  $accepted-formats as xs:string*
  ) {
  api:get-accept-format($accepted-formats, request:get-header('Accept'))
};

declare function api:get-request-format(
  $accepted-formats as xs:string*
  ) {
  api:get-accept-format($accepted-formats, request:get-header('Content-Type'))
};

(:~ perform content negotiation:
 : return the highest priority requested format of the data 
 : If none can be found acceptable, return error 406 and an error message
 : @param $accepted-formats Formats that are acceptable, in order of priority.
 :)
declare function api:get-accept-format(
  $accepted-formats as xs:string*,
  $accept-header as xs:string?
  ) as element() {
  let $requested-cts := local:parse-content-types($accept-header)
  let $accepted-cts := 
    for $format in $accepted-formats
    return local:parse-content-types($format)
  let $default-ct := $accepted-cts[1]
  let $negotiated-ct :=
    if (empty($requested-cts))
    then $default-ct
    else
      for $request in $requested-cts
      for $accept in $accepted-cts
      where 
        $request/api:major = ($accept/api:major, "*") and 
        $request/api:minor = ($accept/api:minor, "*") and
        (: additional parameters - like charset - can be ignored, not
         : actual requirements? - we just cannot contradict the request
         :)
        (every $param in $request/api:param satisfies 
          not($accept/api:param[@name=$param/@name]!=string($param)))
      return $accept
  return
    if (empty($negotiated-ct))
    then api:error(406, "The requested format(s) cannot be served by this API call.", $accept-header)
    else $negotiated-ct[1]
};

(:~ simplify the format returned by api:get-accept-format()
 : return: 'tei' (request is specifically for tei), 'xml' (request is for generic xml), 
 :  'xhtml' (request is for xhtml), 'none' (content negotiation failed)
 :  subsequent strings include any parameters
 :)
declare function api:simplify-format(
  $format as element(),
  $default-format as xs:string
  ) as xs:string+ {
  if ($format instance of element(api:error))
  then 'none'
  else (
    let $fmt-string := concat($format/api:major, "/", $format/api:minor)
    return 
      if ($fmt-string = ("text/xml", "application/xml"))
      then "xml"
      else if ($fmt-string = ("application/xhtml+xml", "text/html"))
      then "xhtml"
      else if ($fmt-string = ("application/tei+xml"))
      then "tei"
      else if ($fmt-string = ("text/css"))
      then "css"
      else if ($fmt-string = ("text/plain"))
      then "txt"
      else if ($fmt-string = ("application/x-www-form-urlencoded"))
      then "form"
      else $default-format
      , 
    $format/api:param/@name/string()
  )
};

declare function api:list(
	$title as element(title),
	$list-body as element(ul)+,
	$n-results as xs:integer) {	
	api:list($title, $list-body, $n-results, false(), (), (), ())
};

declare function api:list(
	$title as element(title),
	$list-body as element(ul)+,
	$n-results as xs:integer,
	$supports-search as xs:boolean,
	$supported-methods as xs:string*,
	$accept-content-types as xs:string*,
	$request-content-types as xs:string*
	) as element(html) {
	api:list($title, $list-body, $n-results, $supports-search, $supported-methods, 
    $accept-content-types, $request-content-types, ())
  
};

(:~ list-type API 
 : @param $title API page title
 : @param $list-body Body of the list 
 : @param $n-results Number of total results in the list
 : @param $supports-search true() if the URI is searchable (default false())
 : @param $supported-methods List of HTTP methods that this URI will support (default GET)
 : @param $accept-content-types List of content types for the Accept header in GET (default application/xhtml+xml, text/html)
 : @param $request-content-types List of Content-Type header in PUT or POST request (no default)
 : @param $test-source URL(s) to the test source(s) if this API supports the ?_test= parameter
 :)
declare function api:list(
	$title as element(title),
	$list-body as element(ul)+,
	$n-results as xs:integer,
	$supports-search as xs:boolean,
	$supported-methods as xs:string*,
	$accept-content-types as xs:string*,
	$request-content-types as xs:string*,
  $test-source as xs:string*
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
        (: add links to the tests, if available :)
        for $source in $test-source
        return (
          <link rel="test" href="{$my-uri}?_test={$source}"/>,
          <link rel="test-source" href="{$source}"/>
        ),
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
				(: add data about where this page is in the search, conformant to OpenSearch :)
				<meta name="startIndex" content="{if ($n-results eq 0) then 0 else $start}"/>,
				<meta name="endIndex" content="{min(($start + $max-results - 1, $n-results))}"/>,
        <meta name="itemsPerPage" content="{$max-results}"/>,
				<meta name="totalResults" content="{$n-results}"/>,
        (: add metadata about supported methods and content types :)
        let $umethods := 
          distinct-values((
            for $method in $supported-methods
            return upper-case($method),
            'GET'
          ))
        for $method in $umethods
        return
          <meta name="supported-method" content="{$method}"/>,
        for $type in distinct-values(($accept-content-types, "application/xhtml+xml", "text/html"))
        return 
          <meta name="accept-content-type" content="{$type}"/>,
        for $type in distinct-values($request-content-types)
        return
          <meta name="request-content-type" content="{$type}"/>,
        (: add a link to the search description if this is search capable :)
        if ($supports-search)
        then 
          <link rel="search"
             type="application/opensearchdescription+xml" 
             href="/code/api/OpenSearchDescription?source={encode-for-uri(request:get-uri())}"
             title="Full text search" />
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
				$list-body
			}</body>
		</html>
};

declare function api:list-item(
	$description as item(),
	$link as xs:string,
  $supported-methods as xs:string*,
  $accept-content-types as xs:string*,
  $request-content-types as xs:string*
	) as element(li) {
	api:list-item($description, $link, $supported-methods, $accept-content-types, $request-content-types, ())
};

(:~ add a list item to a list
 : @param $description description: may be text or HTML
 : @param $link main link to the item,
 : @param $supported-methods What methods it supports
 : @param $accept-content-types what content types can be returned via GET
 : @param $request-content-types what content types can be sent via PUT or POST
 : @param $alt-links alternate descriptions and links, alternating (desc, link, desc, link,...)
 :)
declare function api:list-item(
	$description as item()+,
	$link as xs:string,
  $supported-methods as xs:string*,
  $accept-content-types as xs:string*,
  $request-content-types as xs:string*,
	$alt-links as item()*
	) as element(li) {
  let $methods := 
    for $m in distinct-values($supported-methods)
    return upper-case($m)
  return
    <li>
      <a class="service" href="{$link}">{$description}</a>
      {
      for $alt-link-n in (1 to count($alt-links))[. mod 2 = 1]
      return ("(", <a class="alt" href="{$alt-links[$alt-link-n + 1]}">{$alt-links[$alt-link-n]}</a>, ")"),
      if (exists($supported-methods))
      then 
        <ul class="supported-methods">{
          for $method in $methods
          return
            <li>{
              $method,
              if ($method = "GET" and exists($accept-content-types))
              then 
                <ul class="accept-content-types">{
                  for $ct in distinct-values($accept-content-types)
                  return <li>{$ct}</li>
                }</ul>
              else if ($method = ("PUT", "POST") and exists($request-content-types))
              then
                <ul class="request-content-types">{
                  for $ct in distinct-values($request-content-types)
                  return <li>{$ct}</li>
                }</ul>
              else ()
            }</li>
        }</ul>
      else ()
      }
    </li>
};

(:~ all requestable form content types.
 : If allow-text is true(), allow text/plain, which means
 : only 1 parameter is required
 :)
declare function api:form-content-type(
  $allow-text as xs:boolean?
  ) as xs:string+ {
  ("application/xml",
  "text/xml",
  "application/x-www-form-urlencoded",
  if ($allow-text)
  then "text/plain"
  else ()
  )
};

declare function api:form-content-type(
  ) as xs:string+ {
  api:form-content-type(false())
};

(:~ return the HTML content types for use in accept/request header :)
declare function api:html-content-type(
  ) as xs:string+ {
  api:html-content-type(())
};


(:~ return the HTML content types for use in accept/request header 
 : if $reject-text is true, do not allow text/html
 :)
declare function api:html-content-type(
  $reject-text as xs:boolean?
  ) as xs:string+ {
  ("application/xhtml+xml", ("text/html")[not($reject-text)])
};

declare function api:tei-content-type(
  ) as xs:string {
  api:tei-content-type(())
};

declare function api:tei-content-type(
  $element as xs:string?
  ) as xs:string {
  concat("application/tei+xml", 
    if ($element)
    then concat("; type=", $element)
    else ""
  )
};

declare function api:xml-content-type(
  ) as xs:string+ {
  "text/xml", "application/xml"
};

declare function api:text-content-type(
  ) as xs:string+ {
  "text/plain"
};

(:~ output an API error and set the HTTP response code
 : for RESTXQ 
 : @param $status-code return status
 : @param $message return message (text preferred, but may contain XML)
 : @param $object (optional) error object
 :)
declare function api:rest-error(
  $status-code as xs:integer?,
  $message as item()*, 
  $object as item()*
  ) as item()+ {
  <rest:response>
    <output:serialization-parameters>
      <output:method value="xml"/>
    </output:serialization-parameters>
    <http:response status="{$status-code}"/>
  </rest:response>,
  <error xmlns="">
    <path>{
      if (request:exists())
      then request:get-uri()
      else ()}</path>
    <message>{$message}</message>
    {
      if (exists($object))
      then
        <object>{$object}</object>
      else ()
    }
  </error>
};

declare function api:rest-error(
  $status-code as xs:integer?,
  $message as item()*
  ) as item()+ {
  api:rest-error($status-code, $message, ())
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

declare function api:serialize-as(
  $serialization as xs:string
  ) {
  api:serialize-as($serialization, ())
};

(:~ dynamically declare serialization options as none, txt, tei, xml, xhtml, or html (xhtml w/o indent)
 : @param $serialization type of serialization
 : @param $accept-format result of api:get-accept-formats() - attempt to match content type to the requested one
 :)
declare function api:serialize-as(
	$serialization as xs:string,
	$accept-format as element(api:content-type)?
	) as empty-sequence() {
	let $ser := lower-case($serialization)
	let $accept-format-match := 
    api:simplify-format($accept-format, "none")=$ser
  let $media-type :=
    if ($accept-format-match)
    then concat($accept-format/api:major, "/", $accept-format/api:minor) 
    else ()
	let $options :=
		if ($ser = ('none', 'txt', 'text'))
		then
			concat('method=text media-type=', ($media-type, 'text/plain')[1])
		else if ($ser = 'css')
		then 
			concat('method=text media-type=', ($media-type, 'text/css')[1])
		else if ($ser = ('xml','tei'))
		then
			concat('method=xml omit-xml-declaration=no indent=yes media-type=', 
			  ($media-type, 
			  concat('application/', 'tei+'[$ser="tei"] ,'xml'))[1])
		else if ($ser = 'xhtml')
		then
		  concat('method=xhtml omit-xml-declaration=no indent=yes media-type=',
		    ($media-type, 'text/html')[1])
		 (:
        doctype-public="-//W3C//DTD&#160;XHTML&#160;1.1//EN"
        doctype-system="http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"'
        :)
    else if ($ser = 'html')
    then
    	concat('method=xhtml omit-xml-declaration=no indent=no media-type=',
    	  ($media-type, 'text/html')[1])
    else if ($ser = 'html5')
    then 'method=html5'
		else
			error(xs:QName('err:INTERNAL'),concat('Undefined serialization option: ', $serialization))
	return
		util:declare-option('exist:serialize', $options) 
};

(:~ get the request data. if it's text data, convert it to a string
 : instead of xs:base64Binary 
 :)
declare function api:get-data(
  ) as item()? {
  let $data := request:get-data()
  return
    if ($data instance of xs:base64Binary)
    then util:binary-to-string($data)
    else 
      (: eXist switched from returning elements to document nodes 
       : this wrapper changes back to the old behavior
       :)
      typeswitch($data)
      case document-node() return $data/node()
      default return $data
};

declare function api:get-parameter(
  $param as xs:string,
  $default as xs:string?
  ) as xs:string? {
  api:get-parameter($param, $default, false())
};

(:~ get a parameter from query parameters, form encoded parameters, xml, or text
 : @param $param parameter name
 : @param $default parameter default value
 : @param $allow-one-parameter If only one parameter can be given without a name (eg, text/plain), return it?
 :)
declare function api:get-parameter(
  $param as xs:string,
  $default as xs:string?,
  $allow-one-parameter as xs:boolean?
  ) as xs:string? {
  (
    request:get-parameter($param, ()),
    let $method := api:get-method()
    let $data := api:get-data()
    where $method = ("POST", "PUT")
    return
      if ($data instance of xs:string and $allow-one-parameter)
      then $data
      else if ($data instance of node())
      then 
        if ($allow-one-parameter)
        then $data/string()
        else $data//*[name() = $param]/string()
      else (),
    $default
  )[1]
};


(:~ temporary function to handle rest:response elements
 : and convert them to response:* function calls
 : or simply pass on the return value.
 : will be obsoleted by RESTXQ
 : @param $r (element response{}, resource) or (resource) 
 :)
declare function api:rest-response(
  $r as item()*
  ) as item()* {
  if ($r[1] instance of element(rest:response))
  then (
    let $response := $r[1]
    let $serialization-default :=
      (: prevent parsing errors, particularly for 204 responses :)
      if (
        empty($response/output:serialiation-parameters/output:method) and
        $response instance of element(rest:response) and
        empty($r[2])
        )
      then api:serialize-as("txt")
      else ()
    for $element in $response/*
    return
      typeswitch($element)
      case element(http:response)
      return (
        response:set-status-code(($element/@status/number(), 200)[1]),
        for $header in $element/http:header
        return response:set-header($header/@name, $header/@value)
      )
      case element(output:serialization-parameters)
      return
        for $parameter in $element/*
        return
          typeswitch($parameter)
          case element(output:method) 
          return 
            if ($parameter/@value="text")
            then api:serialize-as("txt")
            else if ($parameter/@value=("xhtml", "html"))
            then api:serialize-as($parameter/@value,api:get-accept-format(api:html-content-type()))
            else if ($parameter/@value="html5")
            then api:serialize-as("html5")
            else ()
          default return ()
      default return ( (: don't know what to do :)),
    subsequence($r, 2)
    )
  else $r
};

(:~ @return a valid root-relative HTTP path for a given API :)
declare function api:uri-of(
  $api as xs:string?
  ) as xs:string {
  try {
    concat(rest:base-uri(), $api)
  }
  catch rerr:RQDY0101 { (: not in a restxq context :)
    $api
  }
};
