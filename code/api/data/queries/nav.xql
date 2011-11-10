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
import module namespace search="http://jewishliturgy.org/api/data/search"
  at "/code/api/data/queries/search.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";

let $sequence := nav:api-path-to-sequence(request:get-uri())
return
  if (empty($sequence))
  then 
    api:error(404, "Not found")
  else if (count($sequence) > 1 or request:get-parameter("q", ()))
  then
    search:go($sequence)
  else
    typeswitch($sequence)
    case element() return navel:go($sequence)
    case document-node() return navdoc:go($sequence)
    case attribute() return navat:go($sequence)
    default return api:error(404, "Not found")
