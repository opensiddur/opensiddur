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
  
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace error="http://jewishliturgy.org/errors";
declare namespace exist="http://exist.sourceforge.net/NS/exist";

(:~ base of all data paths :)
declare variable $data:path-base := "/db/data";

(:~ convert a given path from an API path (may begin /code/api/data, /data or may be truncated) to a database path
 : works only to find the resource. 
 : @param $api-path API path  
 :)
declare function data:api-path-to-db(
	$api-path as xs:string 
	) as xs:string {
	error(
	  xs:QName("error:NOTIMPLEMENTED"), 
	  "Not implemented yet"
	)
};

(:~ Convert a database path to a path in the API
 : @param $db-path database path to convert
 :)
declare function data:db-path-to-api(
	$db-path as xs:string
	) as xs:string {
	 error(xs:QName("error:NOTIMPLEMENTED"), "Not implemented properly")
};

declare function local:resource-name-from-title-and-number(
  $title as xs:string,
  $number as xs:integer
  ) as xs:string {
  string-join(
    ( (: remove diacritics in resource names :)
      encode-for-uri(replace($title, "\p{M}", "")), 
      if ($number)
      then ("-", string($number))
      else (), ".xml"
    ),
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

(:~ get a document using an api path, with or without /api :)
declare function data:doc(
  $api-path as xs:string
  ) as document-node()? {
  let $path := replace($api-path, "^(/api)?/", "")
  let $tokens := tokenize($path, "/")
  let $resource-name := $tokens[count($tokens)] || ".xml"
  return
    if ($tokens[1] != "data")
    then
      error(
        xs:QName("error:NOTIMPLEMENTED"), 
        "Only implemented for the /data hierarchy"
      )
    else
      collection($data:path-base || "/" || $tokens[2])[util:document-name(.)=$resource-name]
};