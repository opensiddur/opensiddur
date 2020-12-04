xquery version "3.1";
(:~ support functions for the REST API for data retrieval
 :
 : Open Siddur Project
 : Copyright 2011-2014 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :) 
module namespace data="http://jewishliturgy.org/modules/data";

import module namespace api="http://jewishliturgy.org/modules/api"
  at "api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "app.xqm";
import module namespace didx="http://jewishliturgy.org/modules/docindex"
	at "docindex.xqm";
  
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace error="http://jewishliturgy.org/errors";
declare namespace exist="http://exist.sourceforge.net/NS/exist";

(:~ base of all data paths :)
declare variable $data:path-base := "/db/data";

(:~ API paths that can be supported by doc and db-api-path-to-db :)
declare variable $data:supported-api-paths := ("data", "user");

(:~ convert a given path from an API path (may begin / or /api) to a database path
 : works only to find the resource. 
 : @param $api-path API path
 : @return The database path or empty sequence if a db path cannot be found  
 :)
declare function data:api-path-to-db(
	$api-path as xs:string 
	) as xs:string? {
	let $doc := data:doc($api-path)
	where exists($doc)
	return document-uri($doc)
};

(:~ Convert a database path to a path in the API
 : @param $db-path database path to convert
 : @return the API path or empty sequence 
 :)
declare function data:db-path-to-api(
	$db-path as xs:string
	) as xs:string? {
	let $norm-db-path := replace($db-path, "^(/db)?/", "/db/")
	let $doc-query := didx:query-by-path($norm-db-path)
	where exists($doc-query)
	return
        api:uri-of(string-join(
        ("/api",
         if ($doc-query/@data-type = "user")
         then ()
         else "data",
         $doc-query/@data-type,
         $doc-query/@resource), "/"))
};

(: Find the API path of a user by name
 : @param user name
 : @return API path of a user by name
 :)
declare function data:user-api-path(
  $name as xs:string
  ) as xs:string? {
  let $doc := collection("/db/data/user")//tei:idno[.=$name]/root(.)
  where $doc
  return
    concat(api:uri-of("/api/user/"), 
      encode-for-uri(
        replace(util:document-name($doc), "\.xml$", "")
      )
    )
};

declare function data:resource-name-from-title-and-number(
  $title as xs:string,
  $number as xs:integer
  ) as xs:string {
  string-join(
    ( (: remove diacritics in resource names and replace some special characters 
       : like strings of ,;=$:@ with dashes. The latter characters have special 
       : meanings in some URIs and are not always properly encoded on the client side
       :)
      encode-for-uri(replace(replace(normalize-space($title), "\p{M}", ""), "[,;:$=@]+", "-")), 
      if ($number)
      then ("-", string($number))
      else (), ".xml"
    ),
  "")
};

declare function data:find-duplicate-number(
  $type as xs:string,
  $title as xs:string,
  $n as xs:integer
  ) as xs:integer {
  if (exists(collection(concat($data:path-base, "/", $type))
    [util:document-name(.)=
      data:resource-name-from-title-and-number($title, $n)]
    ))
  then data:find-duplicate-number($type, $title, $n + 1)
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
    data:resource-name-from-title-and-number($title, 
      data:find-duplicate-number($type, $title, 0))
  return (
    app:concat-path(($data:path-base, $type)),
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
  try {
    doc(didx:query-path($type, $name))
  }
  catch err:FODC0005 {
    ( (: return empty on access denied :) )
  }
};

(:~ get a document using an api path, with or without /api :)
declare function data:doc(
  $api-path as xs:string
  ) as document-node()? {
  let $path := replace($api-path, "^((" || api:uri-of("/api") || ")|(/api))?/", "")
  let $tokens := tokenize($path, "/")
  let $token-offset := if ($tokens[1] = "data") then 1 else 0
  let $data-type := $tokens[1 + $token-offset]
  let $resource := $tokens[2 + $token-offset]
  return
    if ($tokens[1] = ("data", "user"))
    then
        data:doc($data-type, $resource)
    else
        error(
        	      xs:QName("error:NOTIMPLEMENTED"),
        	      "data:doc() not implemented for the path: " || $api-path
        	    )
};

(:~ given the parts (eg, title and subtitle) of a document title, put together a standardized
 : title that can be used as a resource name.
 : This function will restrict the available title space to be stricter than valid xml:id's
 : @param case-sensitive if true(), do not lowercase, the title, otherwise, do
 : @return the string value of the normalized title. If the value is an "", the title is invalid.
 :)
declare function data:normalize-resource-title(
    $title-string-parts as xs:string+,
    $case-sensitive as xs:boolean
) as xs:string {
    let $part-composition-character := "-"
    let $word-composition-character := "_"
    let $composed-parts := string-join($title-string-parts[.], $part-composition-character)
    let $removed-whitespace := replace($composed-parts, "\s+", $word-composition-character)
    let $normalized := replace(
        normalize-unicode($removed-whitespace, "NFKD"),
        "[^-_\p{L}\p{Nd}]+", "")
    let $cased :=
        if (not($case-sensitive)) then lower-case($normalized)
        else $normalized
    (: disallow punctuators at the beginning and end :)
    let $remove-begin-end-punct := replace($cased, "(^[-_]+)|([-_]+$)", "")
    (: remove duplicate punctuators :)
    let $remove-dupe-punct := replace($remove-begin-end-punct, "(([-])+|([_])+)", "$2$3")
    (: must begin with a letter :)
    let $no-begin-with-number :=
        if (matches($remove-dupe-punct, "^\d"))
        then $word-composition-character || $remove-dupe-punct
        else $remove-dupe-punct
    (: empty it out if it's only - and _ :)
    let $emptied-blanks := replace($no-begin-with-number, "^[-_]+$", "")
    (: can't be empty :)
    return $emptied-blanks
};