xquery version "1.0";
(:~ search cache module 
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 : $Id: scache.xqm 720 2011-04-03 18:39:23Z efraim.feinstein $ 
 :)
module namespace scache="http://jewishliturgy.org/modules/scache";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace session="http://exist-db.org/xquery/session";
import module namespace util="http://exist-db.org/xquery/util";

import module namespace api="http://jewishliturgy.org/modules/api" 
	at "/code/api/modules/api.xqm";

declare variable $scache:prefix := 'cache.';

(:~ return the session key associated with the uri and search parameters :)
declare function local:key(
	$uri as xs:string,
	$search as xs:string
	) as xs:string {
	concat($scache:prefix, util:hash(concat($uri, $search), 'md5'))
};

(:~ check if a set of collections or resources is up to date since the search
 : $uri, $search :)
declare function scache:is-up-to-date(
	$collections as xs:string+,
	$uri as xs:string,
	$search as xs:string
	) as xs:boolean {
	scache:is-cached($uri, $search)
	and (
		every $collection in $collections
		satisfies (
			let $search-time := session:get-attribute(concat(local:key($uri, $search), '-time')) cast as xs:dateTime
			return
				if (xmldb:collection-available($collection))
				then 
					let $update-record := concat($collection, '/updated.xml')
					let $update-times := collection($collection)//updated
					return (
						(:
						util:log-system-out((
							'scache:is-cached(',$uri,'): collection=', $collection,' empty = ', empty($update-times),
							' ',
							for $u-t in $update-times
							return ($u-t, ' < ', $search-time, ' = ', $u-t < $search-time))),
						:)
						empty($update-times) or 
						(every $update-time in $update-times 
						satisfies xs:dateTime($update-time) < $search-time)
					)
				else 
					(: is it a resource? :)
					if (doc-available($collection))
					then 
						let $c-name := util:collection-name($collection)
						let $d-name := util:document-name($collection)
						let $update-time := xmldb:last-modified($c-name, $d-name)
						return
							xs:dateTime($update-time) < $search-time
					else ( (: do not know what to do - no contribution :) true() ) 
			)
	) 
};

(:~ check if the given search is cached in the session :)
declare function scache:is-cached(
	$uri as xs:string,
	$search as xs:string
	) as xs:boolean {
	session:get-attribute-names() = local:key($uri, $search)
};

(:~ store the content into the cache and return it, with request parameters taken account of 
 :)
declare function scache:store(
	$uri as xs:string,
	$search as xs:string,
	$content as item()
	) as item() {
	session:set-attribute(local:key($uri, $search), $content),
	session:set-attribute(concat(local:key($uri, $search), '-time'), current-dateTime()),
	scache:get-request($uri, $search)
};

(:~ retrieve an entire saved search from the cache :)
declare function scache:get(
	$uri as xs:string,
	$search as xs:string
	) as item()? {
	session:get-attribute(local:key($uri, $search))
}; 

(:~ return the parts of a saved search specified by the request parameters
 : start and max-results
 : Assumes a ul/li structure in the results
 :)
declare function scache:get-request(
	$uri as xs:string,
	$search as xs:string
	) as element()? {
	let $full-result := scache:get($uri, $search)
	let $start := request:get-parameter('start', 1)
	let $max-results := request:get-parameter('max-results', $api:default-max-results)
	where $full-result
	return
		element { node-name($full-result) }{
			$full-result/@*,
			subsequence($full-result/*, $start, $max-results)
		}
};

(:~ clear all session cached results :)
declare function scache:clear(
	) as empty() {
	for $a in session:get-attribute-names()
	where starts-with($a, $scache:prefix)
	return session:remove-attribute($a)
};