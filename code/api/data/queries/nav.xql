xquery version "1.0";
(:~ XML navigation API
 :
 : Available formats: XML, TEI, XHTML
 : 
 : Methods: GET, POST, DELETE
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
import module namespace nav="http://jewishliturgy.org/modules/nav"
  at "/code/api/modules/nav.xqm";
import module namespace icompile="http://jewishliturgy.org/modules/icompile"
  at "/code/api/modules/icompile.xqm";
  	
declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace err="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

declare variable $local:entry-points := (
  "j:concurrent",
  "j:selection",
  "j:repository",
  "j:view"
  );
  
declare variable $local:accepted-formats := $nav:accept-content-types;

declare function local:get-tei(
  $base as node(),
  $format as xs:string
  ) as element()? {
  api:serialize-as($format[1]),
  if ($format = "flat")
  then ()
  else 
    if (count($base) = 1)
    then $base
    else 
      (: in order to make valid XML, we need to wrap the
       : returned elements
       :)
      element nav:wrapper { 
        attribute n { count($base) },
        $base
      }
};

declare function local:get-xhtml(
	$base as node()
	) as element()? {
	if ($base instance of document-node())
	then (
	  api:serialize-as("xhtml"),
	  (: show the entry point menu :)
	  api:list(
	    element title {
	      concat("XML Navigation for ", request:get-uri())
	    },
	    element ul {
  	    let $uri := request:get-uri()
  	    for $entry-point in $local:entry-points
  	    for $element in $base//*[name()=$entry-point]
  	    let $index := count($element/preceding::*[name()=$entry-point]) + 1
  	    return
  	      api:list-item(
  	        element span { attribute class {"service"}, $entry-point }, 
  	        concat($uri, "/", nav:xpath-to-url(concat($entry-point, "[", $index, "]"))),
  	        ("GET", "POST", "DELETE"),
  	        $nav:accept-content-types,
  	        $nav:request-content-types
  	      )
	    },
	    0,
	    false(),
	    "GET",
	    api:html-content-type(),
	    (),
	    ()
	  )
	)
	else 
	 (: show the navigation menu :)
	 nav:xml-to-navigation($base, ())
};

declare function local:put(
	) as element()? {
	()
};

declare function local:post(
	) as element()? {
	()		
};

declare function local:delete(
	) as element()? {
	()	
};

if (api:allowed-method(('GET', 'POST', 'DELETE')))
then
	let $auth := api:request-authentication() or true()
	(: $user-name the user name in the request URI :)
	let $purpose := request:get-parameter('purpose', ())
	let $share-type := request:get-parameter('share-type', ())
	let $owner := request:get-parameter('owner', ())
	let $resource := request:get-parameter('resource', ())
	let $subresource := request:get-parameter('subresource', ())
	let $subsubresource := request:get-parameter('subsubresource', ())[.]
	let $format := api:get-accept-format($local:accepted-formats)
	let $doc := data:doc($purpose, $share-type, $owner, $resource, 'xml', ())
	let $method := api:get-method() 
	return (
	  if ($format instance of element(api:error))
	  then $format
		else if ($doc instance of document-node())
		then
		  let $format := api:simplify-format($format, "xml")
		  let $nav-url-path := substring-after(request:get-uri(), "/nav")
		  let $path := nav:url-to-xpath($nav-url-path)
		  let $xpath := $path/nav:path/string()
		  let $position := $path/nav:position/string()
		  let $activity := $path/nav:activity/string()
		  let $base := 
		    if ($xpath)
		    then util:eval(concat("$doc/", $xpath))
		    else $doc
			return
				if ($method = 'GET')
				then 
				  if (empty($base))
				  then api:error(404, "Not found", $nav-url-path)
				  else 
				    if ($activity = "-compile")
				    then
				      icompile:compile(
				        $base, 
				        false(),
				        $format = "xhtml"
				      )
				    else if ($format = "xhtml")
				    then local:get-xhtml($base)
				    else if ($format = ("xml", "tei"))
				    then local:get-tei($base, $format)
				    else error(xs:QName("err:WTF"), "You should never get here")
				else if ($method = "POST")
				then local:post()
				else local:delete()
		else 
			(: an error occurred and is in $doc :)
			$doc
	)
else 
	(:disallowed method:)
	api:error-message("Method not allowed")
