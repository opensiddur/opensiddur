xquery version "1.0";
(: api for compilation status
 : 
 : Parameters:
 : 	path = full path
 :	standard path parameters
 :
 : Method: GET
 : Return: 
 :		200 Status is returned
 :		401 you are not logged in and requested a resource that requires login
 :		403 you are logged in, but you can't access the requested resource
 :		404 share type, group, user, or compilation job does not exist
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
import module namespace response="http://exist-db.org/xquery/response";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/code/modules/paths.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
	at "/code/api/modules/data.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "/code/modules/format.xqm";
import module namespace jobs="http://jewishliturgy.org/apps/jobs"
  at "/code/apps/jobs/modules/jobs.xqm";
    
declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace err="http://jewishliturgy.org/errors";

declare option exist:serialize "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes 
        doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
        doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd";

(: output is xhtml :)
declare function local:get(
	$path as xs:string
	) as item() {
	let $resource := request:get-parameter("resource", ())
	let $api-path-wo-status := replace($path, "/status$", "")
  let $db-collection-path := 
    replace(data:api-path-to-db($api-path-wo-status), "/[^/]+$", "")
  let $db-status-path := 
    concat($db-collection-path, "/", format:status-xml($resource))
  let $db-error-path :=
    concat($db-collection-path, "/", $format:compile-error-resource)
	return 
		if (doc-available($db-status-path))
		then 
		  let $status-doc := doc($db-status-path)/*
		  (: TODO: there's a bug in eXist's query 
		   which prevents us from using a blank namespace
		   :)
		  let $error-doc := doc($db-error-path)
		  let $current := $status-doc/*[name()="current"]/number()
		  let $steps := $status-doc/*[name()="steps"]/number()
		  let $completed := $status-doc/*[name()="completed"]/number()
		  let $job := $status-doc/*[name()="job"]/number()
		  let $done := $completed = $steps
		  return 
		    api:list(
		      element title { 
		        concat("Compile status for ", substring-before($path,"/status"))
		      },
		      <ul>
		        <li>Current status: {
		          if (exists($error-doc))
		          then (
		            <span xml:id="error">Error</span>,
		            <div xml:id="error-details">
		              <div>Code: <span xml:id="error-code">{$error-doc//jobs:code/node()}</span></div>
		              <div>Description: <span xml:id="error-description">{$error-doc//jobs:description/node()}</span></div>
		              <div>Value: <span xml:id="error-value">{$error-doc//jobs:value/node()}</span></div>
		            </div>
		          )
		          else if ($done)
		          then 
		            <span xml:id="complete">Complete</span>
		          else if ($current = 0)
		          then (
		           <span xml:id="queue">Queued</span>,
		           " with ",
		           <span xml:id="ahead">{jobs:wait-in-queue($job)}</span>,
		           " jobs ahead in the queue."
		          )
		          else (
		            <span xml:id="at">{$completed}</span>,
		            " of ",
		            <span xml:id="of">{$steps}</span>,
		            " stages completed."
		          )
		        }</li>
		      </ul>,
		      0,
		      false(),
		      ("GET"),
		      api:html-content-type(),
		      ()
		    )
		else
			api:error(404, "Not found", $path)
};

if (api:allowed-method('GET'))
then
	let $auth := api:request-authentication() or true()
	let $share-type := request:get-parameter('share-type', ())
	let $owner := request:get-parameter('owner', ())
	let $resource := request:get-parameter('resource', ())
	let $format := request:get-parameter('format', ())
	let $path := request:get-parameter('path', ())
	return
	  (: require-authentication-as-group ? :)
		if (data:is-valid-share-type($share-type))
		then 
			if (data:is-valid-owner($share-type, $owner))
			then 
			  if (api:require-authentication-as($share-type, $owner, true()))
			  then 
			    local:get($path)
			  else
			    api:error((), "Access forbidden.")
			else
				api:error(404, concat("Invalid owner for the given share type ", $share-type), $owner)
		else
			api:error(404, "Invalid share type. Acceptable values are 'group'", $share-type) 
else
	(: disallowed method :) 
	()
