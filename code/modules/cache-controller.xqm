xquery version "1.0";
(:
 : Caching controller module
 : All the functions of the caching controller.
 : Intended to be called directly from controller.xql
 :
 : Note: the jcache prefix is used to avoid a conflict with
 : eXist's cache module
 :
 : Copyright 2010-2011 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)

module namespace jcache="http://jewishliturgy.org/modules/cache";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace transform="http://exist-db.org/xquery/transform";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace app="http://jewishliturgy.org/modules/app" 
	at "/code/modules/app.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths" 
	at "/code/modules/paths.xqm";

declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";
declare namespace exist="http://exist.sourceforge.net/NS/exist";
declare namespace err="http://jewishliturgy.org/errors";

(: the default cache is under this directory :)
declare variable $jcache:cache-collection := 'cache';

(:~ return the path to a flag for a given collection and resource as (cache-collection, resource) :)
declare function local:get-flag-path(
  $collection as xs:string,
  $resource as xs:string) 
  as xs:string+ {
  (
  	jcache:cached-document-path($collection),
    replace($resource,'.xml$','.in-progress.xml')
  )
  
};

(:~ set in-progress flag for the given collection and resource :)
declare function local:set-flag(
  $collection as xs:string, 
  $resource as xs:string) 
  as empty() {
  let $in-progress-path := local:get-flag-path($collection, $resource)
  let $in-progress-collection := $in-progress-path[1]
  let $in-progress-resource := $in-progress-path[2]
  return
    if (xmldb:store($in-progress-collection, $in-progress-resource, <in-progress/>))
    then local:set-cache-permissions($collection, $in-progress-resource)
    else error(xs:QName('err:STORE'), concat('Cannot store progress indicator ', $in-progress-path))
};

(:~ remove in-progress flag for the given collection and resource :)
declare function local:remove-flag(
  $collection as xs:string, 
  $resource as xs:string) 
  as empty() {
  let $in-progress-path := local:get-flag-path($collection, $resource)
  let $in-progress-collection := $in-progress-path[1]
  let $in-progress-resource := $in-progress-path[2]
  return
    xmldb:remove($in-progress-collection, $in-progress-resource)
};

(:~ return true if an active in progress flag exists.  
 : if an inactive flag exists, remove it and return false.
 : if no flag exists, return false.
 :)
declare function local:flag-is-active(
  $collection as xs:string,
  $resource as xs:string
  ) as xs:boolean {
  let $in-progress-path := local:get-flag-path($collection, $resource)
  let $cache-collection := $in-progress-path[1]
  let $in-progress-resource := $in-progress-path[2]
  let $cache-exists := xmldb:collection-available($cache-collection)
  let $caching-in-progress := doc-available(concat($cache-collection, $in-progress-resource))
  let $caching-too-long := $caching-in-progress and 
    xmldb:last-modified($cache-collection, $in-progress-resource) gt (xs:dayTimeDuration("P0DT0H5M0S") + current-dateTime())
  return
    if ($caching-too-long)
    then (local:remove-flag($collection, $resource), false())
    else $caching-in-progress
};

(:~ set appropriate resource permissions for a resource in the cache.
 : which are the same as the original file.
 : @param $collection The original resource collection 
 : @param $resource The resource
 :)
declare function local:set-cache-permissions(
	$collection as xs:string,
	$resource as xs:string
	) as empty() {
  let $cache := jcache:cached-document-path($cache)
  let $owner := xmldb:get-owner($collection, $resource)
  let $group := xmldb:get-group($collection, $resource)
  let $permissions := xmldb:get-permissions($collection, $resource)
  return
  	xmldb:set-resource-permissions($cache, $resource,
      $owner, $group, $permissions)
};

(:~ commit a given resource to the cache 
 : @param $collection collection, must end with /
 : @param $resource resource name
 :)
declare function local:commit-cache(
  $collection as xs:string,
  $resource as xs:string)
  as empty() {
  let $cache := jcache:cached-document-path($collection)
  where (app:require-authentication())
  return (
    (: make the cache collection if it does not already exist :)
    if (xmldb:collection-available($cache))
    then ()
    else (
      (: make the cache collection with the same priveleges as its parent :)
      app:make-collection-path(
				$cache, 
				'/',
				xmldb:get-owner($collection),
				xmldb:get-group($collection),
				xmldb:get-permissions($collection)
      )
    ),
    local:set-flag($collection, $resource),
    let $transform-result :=
    	util:catch('*', 
      	app:transform-xslt(
      		app:concat-path($collection, $resource), 
      		'/db/code/transforms/concurrent/concurrent.xsl2',
      		(<param name="exist:stop-on-warn" value="yes"/>), ()),
      	(
      		(: make sure the flag is removed if app:transform-xslt fails :)
      		local:remove-flag($collection, $resource),
      		error($util:exception cast as xs:QName, $util:exception-message)
      	)
      ) 
    return (
      if (xmldb:store($cache, $resource, $transform-result))
      then (
      	local:set-cache-permissions($collection, $resource)
      )
      else (
        local:remove-flag($collection, $resource),
        error(xs:QName('err:STORE'), concat('Cannot store resource ', $collection, $resource, ' in cache ', $cache)) 
      )
    ),
    local:remove-flag($collection, $resource)
  )
};

(:~ determine if a given document is up to date in the given cache, including dependencies
 : @param $document-path Path to document in the database (assumed to be a document!)
 : @param $cache Subdirectory name of the cache to use 
 :)
declare function jcache:is-up-to-date(
	$document-path as xs:string,
	$cache as xs:string) 
	as xs:boolean {
  let $sanitized-document-path := replace($document-path, '^http://[^/]+', '')
	let $collection := util:collection-name($sanitized-document-path)
	let $resource := util:document-name($sanitized-document-path)
	let $cache-collection := jcache:cached-document-path($collection)
	let $cached-document-path := jcache:cached-document-path($sanitized-document-path)
	return
		doc-available($cached-document-path) and
		(xmldb:last-modified($cache-collection, $resource) gt xmldb:last-modified($collection, $resource))
		and (
			(: these paths can be absolute with http:// etc. Need to make them in-db paths
			The correct way to do it is probably with resolve-uri() :)
			every $path in doc($cached-document-path)//jx:cache-depend/@path 
			satisfies jcache:is-up-to-date(string($path), $cache)
			)
};

(:~ clear caches from a given collection, recurse down directories if $recurse is true() 
 : @param $collection The collection whose caches should be removed
 : @param $recurse true() if recurse down directories
 :)
declare function jcache:clear-cache-collection(
  $collection as xs:string,
  $recurse as xs:boolean) 
  as empty() {
  let $ccollection := jcache:cached-document-path($collection)
  where (app:require-authentication() and xmldb:collection-available($ccollection))
  return (
  	if ($paths:debug)
  	then
  		util:log-system-out(('In clear-cache-collection(',$ccollection,')'))
  	else (),
    for $res in xmldb:get-child-resources($ccollection) 
    return
      jcache:clear-cache-resource($ccollection, $res),
    if ($recurse)
    then
      for $child in xmldb:get-child-collections($collection)
      return 
        jcache:clear-cache-collection(app:concat-path($collection, $child), $recurse)
    else ()
  )
};

(:~ clear a single resource from the cache and any expired flags
 : @param $collection The collection where the original resource resides
 : @param $resource The resource whose cache entry should be removed
 :)
declare function jcache:clear-cache-resource(
  $collection as xs:string, 
  $resource as xs:string) 
  as empty() {
  let $ccollection := 
    if (starts-with(replace($collection, '^(/db)?/',''), $jcache:cache-collection))
    then $collection
    else jcache:cached-document-path($collection)
  where (app:require-authentication() and exists(local:flag-is-active($collection, $resource)))
  return xmldb:remove($ccollection, $resource)
};

(:~ bring all of the resources referenced from a given resource
 : up to date in the cache
 : @param $path Resource to be tested
 :  to prevent infinite recursion
 :)
declare function jcache:cache-all(
  $path as xs:string
  ) as empty() {
  for $resource in jcache:find-dependent-resources($path, ())
  let $collection := util:collection-name($resource)
  let $document := util:document-name($resource)
  let $dbcollection := 
    if (starts-with($collection, '/db')) 
    then $collection 
    else app:concat-path('/db', $collection)
  where not(jcache:is-up-to-date($resource, $jcache:cache-collection)) 
        and not(local:flag-is-active($dbcollection, $document))
  return 
    local:commit-cache($dbcollection, $document)
};

(:~ find resources dependent on a given path :)
declare function jcache:find-dependent-resources(
  $path as xs:string,
  $resources-checked as xs:string*
  ) as xs:string* {
  if (not($path = $resources-checked))
  then (
    let $doc := doc($path)
    let $this-resources-checked := (
      $resources-checked,
      document-uri($doc)
    )
    let $has-target-attributes := $doc//*[@target|@targets|@resp]
    let $new-targets := (
      distinct-values(
      for $has-target-attribute in $has-target-attributes
      let $targets := 
        for $t in tokenize(string-join(($has-target-attribute/(@targets,@target,@resp)),' '), '\s+')
        return 
          if (contains($t, '#'))
          then substring-before($t, '#')[.]
          else $t
      return (
        for $target in $targets
        let $abs-uri := resolve-uri($target, base-uri($has-target-attribute))[not(. = $this-resources-checked)]
        where (not(starts-with($abs-uri, 'http')) or starts-with($abs-uri, 'http://localhost'))
        return 
          replace($abs-uri, '^http://localhost(:\d+)?(/db)?','/db')
        )
      )
    )
    let $recurse :=
      for $new-target in $new-targets
      return jcache:find-dependent-resources($new-target, $this-resources-checked)
    return
      distinct-values(($this-resources-checked, $recurse))
  )
  else ( (: path already checked :) )
};

(:~ return a path to a cached document - whether it exists or not -
 : given the original's path
 : @param $path path to original document
 :)
declare function jcache:cached-document-path(
  $path as xs:string
  ) {
  replace($path, concat('^(/db)?(/', $jcache:cache-collection, ')?/'), concat('$1/', $jcache:cache-collection, '/'))
};

