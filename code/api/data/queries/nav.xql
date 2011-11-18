xquery version "1.0";
(:~ XML navigation API
 :
 : Open Siddur Project 
 : Copyright 2011 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace nav="http://jewishliturgy.org/modules/nav"
  at "/code/api/modules/nav.xqm";
import module namespace navdoc="http://jewishliturgy.org/api/data/navdoc"
  at "/code/api/data/queries/navdoc.xqm";
import module namespace navel="http://jewishliturgy.org/api/data/navel"
  at "/code/api/data/queries/navel.xqm";
import module namespace navat="http://jewishliturgy.org/api/data/navat"
  at "/code/api/data/queries/navat.xqm";
import module namespace compile = "http://jewishliturgy.org/api/data/compile"
  at "/code/api/data/queries/compile.xqm";
import module namespace lic = "http://jewishliturgy.org/api/data/license"
  at "/code/api/data/queries/license.xqm";
import module namespace search="http://jewishliturgy.org/api/data/search"
  at "/code/api/data/queries/search.xqm";


declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

let $uri := request:get-uri()
let $sequence := nav:api-path-to-sequence($uri)
let $activity := nav:url-to-xpath($uri)/nav:activity/string()
let $index-uri := "/code/api/data/original"
return
  if (count($sequence) > 1 or 
    request:get-parameter("q", ()) or 
    $uri = $index-uri)
  then
    search:go($sequence)
  else
    typeswitch($sequence)
    case element() return navel:go($sequence)
    case document-node() return 
      if ($activity = "-compiled")
      then compile:go($sequence)
      else if ($activity = "-license")
      then lic:go($sequence)
      else navdoc:go($sequence)
    case attribute() return navat:go($sequence)
    default return api:error(404, "Not found")
