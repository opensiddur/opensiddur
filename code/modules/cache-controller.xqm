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
 : $Id: cache-controller.xqm 769 2011-04-29 00:02:54Z efraim.feinstein $
 :)

module namespace jcache="http://jewishliturgy.org/modules/cache";

import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace transform="http://exist-db.org/xquery/transform";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace app="http://jewishliturgy.org/modules/app" at "/db/code/modules/app.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths" at "/code/modules/paths.xqm";

declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";
declare namespace exist="http://exist.sourceforge.net/NS/exist";
declare namespace err="http://jewishliturgy.org/errors";

(: all cache collections end in this name :)
declare variable $jcache:cache-collection := 'cache';

(:~ return the path to a flag for a given collection and resource as (cache-collection, resource) :)
declare function jcache:_get-flag-path(
  $collection as xs:string,
  $resource as xs:string) 
  as xs:string+ {
  (concat($collection, 
    if (ends-with($collection, '/')) then '' else '/', 
    $jcache:cache-collection, '/'),
    replace($resource,'.xml','.in-progress.xml')
  )
  
};

(:~ set in-progress flag for the given collection and resource :)
declare function jcache:_set-flag(
  $collection as xs:string, 
  $resource as xs:string) 
  as empty() {
  let $in-progress-path := jcache:_get-flag-path($collection, $resource)
  let $in-progress-collection := $in-progress-path[1]
  let $in-progress-resource := $in-progress-path[2]
  return
    if (xmldb:store($in-progress-collection, $in-progress-resource, <in-progress/>))
    then jcache:_set-cache-permissions($in-progress-collection, $in-progress-resource)
    else error(xs:QName('err:STORE'), concat('Cannot store progress indicator ', $in-progress-path))
};

(:~ remove in-progress flag for the given collection and resource :)
declare function jcache:_remove-flag(
  $collection as xs:string, 
  $resource as xs:string) 
  as empty() {
  let $in-progress-path := jcache:_get-flag-path($collection, $resource)
  let $in-progress-collection := $in-progress-path[1]
  let $in-progress-resource := $in-progress-path[2]
  return
    xmldb:remove($in-progress-collection, $in-progress-resource)
};

(:~ return true if an active in progress flag exists.  
 : if an inactive flag exists, remove it and return false.
 : if no flag exists, return false.
 :)
declare function jcache:_flag-is-active(
  $collection as xs:string,
  $resource as xs:string
  ) as xs:boolean {
  let $in-progress-path := jcache:_get-flag-path($collection, $resource)
  let $cache-collection := $in-progress-path[1]
  let $in-progress-resource := $in-progress-path[2]
  let $cache-exists := xmldb:collection-available($cache-collection)
  let $caching-in-progress := doc-available(concat($cache-collection, $in-progress-resource))
  let $caching-too-long := $caching-in-progress and 
    xmldb:last-modified($cache-collection, $in-progress-resource) gt (xs:dayTimeDuration("P0DT0H5M0S") + current-dateTime())
  return
    if ($caching-too-long)
    then (jcache:_remove-flag($collection, $resource), false())
    else $caching-in-progress
};

(:~ set appropriate resource permissions for a resource in the cache.
 : user = creating user, group = (everyone, authenticated-user, or group, as appropriate)
 : mode = 0774 (rwurwur--)
 : @param $cache The cache 
 : @param $resource The resource
 :)
declare function jcache:_set-cache-permissions(
	$cache as xs:string,
	$resource as xs:string
	) as empty() {
	xmldb:set-resource-permissions($cache, $resource,
  	app:auth-user(), (
  	(: group :)
  	let $collection-levels := 
  		tokenize(
  			if (starts-with($cache, '/db')) 
  			then substring-after($cache, '/db')
  			else $cache, '/')[.] (: the predicate avoids the first entry being a blank string :)
    let $top-level-collection := $collection-levels[1]
    return (
    	if ($top-level-collection = 'group')
    	then xmldb:get-group(concat('/', $top-level-collection, '/', $collection-levels[2]))
    	else 'everyone'
    	)
    ), util:base-to-integer(0774,8))	
};

(:~ commit a given resource to the cache 
 : @param $collection collection, must end with /
 : @param $resource resource name
 :)
declare function jcache:_commit-cache(
  $collection as xs:string,
  $resource as xs:string)
  as empty() {
  let $cache := app:concat-path($collection, $jcache:cache-collection)
  where (app:require-authentication())
  return (
    (: make the cache collection if it does not already exist :)
    if (xmldb:collection-available($cache))
    then ()
    else (
      (: make the cache directory :)
      if (xmldb:create-collection($collection, $jcache:cache-collection))
      then 
        xmldb:set-collection-permissions($cache, 'admin', 'everyone', 
          util:base-to-integer(0774,8))
      else 
        error(xs:QName('err:STORE'), concat('Cannot create cache collection ', $cache))
    ),
    jcache:_set-flag($collection, $resource),
    let $transform-result :=
    	util:catch('*', 
      	app:transform-xslt(app:concat-path($collection, $resource), '/db/code/transforms/concurrent/concurrent.xsl2',(), ()),
      	(
      		(: make sure the flag is removed if app:transform-xslt fails :)
      		jcache:_remove-flag($collection, $resource),
      		error($util:exception cast as xs:QName, $util:exception-message)
      	)
      ) 
    return (
      if (xmldb:store($cache, $resource, $transform-result))
      then (
      	jcache:_set-cache-permissions($cache, $resource)
      )
      else (
        jcache:_remove-flag($collection, $resource),
        error(xs:QName('err:STORE'), concat('Cannot store resource ', $collection, $resource, ' in cache ', $cache)) 
      )
    ),
    jcache:_remove-flag($collection, $resource)
  )
};

(:~ determine if a given document is up to date in the given cache, including dependencies
 : @param $document-path Path to document in the database (assumed to be a document!)
 : @param $cache Subdirectory name of the cache to use 
 :)
declare function jcache:_is-up-to-date(
	$document-path as xs:string,
	$cache as xs:string) 
	as xs:boolean {
  let $sanitized-document-path := replace($document-path, '^http://[^/]+', '')
	let $collection := util:collection-name($sanitized-document-path)
	let $resource := util:document-name($sanitized-document-path)
	let $cache-collection := app:concat-path($collection, $cache)
	let $cached-document-path := app:concat-path($cache-collection, $resource)
	return
		doc-available($cached-document-path) and
		(xmldb:last-modified($cache-collection, $resource) gt xmldb:last-modified($collection, $resource))
		and (
			(: these paths can be absolute with http:// etc. Need to make them in-db paths
			The correct way to do it is probably with resolve-uri() :)
			every $path in doc($cached-document-path)//jx:cache-depend/@path 
			satisfies jcache:_is-up-to-date(string($path), $cache)
			)
};

(:~ given a collection, return the associated cache collection :)
declare function jcache:_get-cache-collection(
  $collection as xs:string
  ) as xs:string {
  app:concat-path($collection, $jcache:cache-collection)
};

(:~ clear caches from a given collection, recurse down directories if $recurse is true() 
 : @param $collection The collection whose caches should be removed
 : @param $recurse true() if recurse down directories
 :)
declare function jcache:clear-cache-collection(
  $collection as xs:string,
  $recurse as xs:boolean) 
  as empty() {
  let $ccollection := jcache:_get-cache-collection($collection)
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
      for $child in xmldb:get-child-collections($collection)[. ne $jcache:cache-collection]
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
    if (ends-with($collection, concat('/', $jcache:cache-collection)))
    then $collection
    else jcache:_get-cache-collection($collection)
  where (app:require-authentication() and exists(jcache:_flag-is-active($collection, $resource)))
  return xmldb:remove($ccollection, $resource)
};

(:~ set authentication parameters for an ex:dispatch :)
declare function jcache:_set-authentication-parameters(
	) as element()* {
	let $user := app:auth-user()
	let $password := app:auth-password()
	return 
		if ($user and $password)
		then (
    	<exist:set-attribute name="xquery.user" value="{$user}"/>,
    	<exist:set-attribute name="xquery.password" value="{$password}"/>
  	)
  	else ()
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
  where not(jcache:_is-up-to-date($resource, $jcache:cache-collection)) 
        and not(jcache:_flag-is-active($dbcollection, $document))
  return 
    jcache:_commit-cache($dbcollection, $document)
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
  let $path-tokens := tokenize($path,'/')
  let $collection := subsequence($path-tokens, 1, count($path-tokens) - 1) (:util:collection-name($path):)
  let $resource := $path-tokens[last()]
  return
    app:concat-path(($collection, 
    	if ($collection[last()] = $jcache:cache-collection) 
    	then ()
    	else $jcache:cache-collection,
    	$resource))
};

(:~ Equivalent of the main query.  
 : Accepts the controller's exist:* external variables as parameters 
 : request parameters format and clear may also be used 
 : returns an element in the exist namespace 
 :)
declare function jcache:cache-query(
  $path as xs:string,
  $resource as xs:string,
  $controller as xs:string,
  $prefix as xs:string,
  $root as xs:string) 
  as element() {
  let $user := app:auth-user()
  let $password := app:auth-password()
  let $document-path := 
    app:concat-path($controller, $path)
  let $collection :=
    (: collection name, always ends with / :)
    let $step1 := util:collection-name($document-path)
    return
      if (ends-with($step1, '/')) then $step1 else concat($step1, '/')
  let $cache := 
    concat($collection, $jcache:cache-collection, '/')
  let $cached-document-path :=
    concat($cache, $resource)
  let $in-progress-flag :=
    concat(substring-before($resource,'.xml'),'.in-progress.xml')
  (: the first condition is a workaround for a bug in eXist :)
  let $path-is-document := (
  	if ($paths:debug)
  	then
  		util:log-system-out(('You are: ', xmldb:get-current-user()))
  	else (),
  	not(util:is-binary-doc($document-path)) and doc-available($document-path))
  let $path-is-collection := xmldb:collection-available($document-path)
  let $format := request:get-parameter('format','original')
  let $clear := request:get-parameter('clear','')
  return (
  	if ($paths:debug)
  	then
  		util:log-system-out(('cache-query for ', $document-path, ' authenticated as ', $user))
  	else (),
    if ($path-is-document or $path-is-collection)
    then 
      (: if not available, ignore :)
      if ($clear)
      then
        (: request is to clear the cache for $document-path :)
        <exist:dispatch>
          <exist:forward url="/code/modules/clear-cache.xql">
       	    {jcache:_set-authentication-parameters()}
            <exist:add-parameter name="clear" value="{$clear}"/>
            <exist:add-parameter name="path" value="{$document-path}"/>
          </exist:forward>
        </exist:dispatch>
      else if ($path-is-document and $format = 'fragmentation')
      then
        (: the document exists, might be/need to be cached :)
        let $is-up-to-date := jcache:_is-up-to-date($document-path, $jcache:cache-collection)
        return
          if ($is-up-to-date) 
          then
            (: the cache is up to date, return the cached version :)
            (
            if ($paths:debug)
            then
            	util:log-system-out(('FORWARDING TO CACHED VERSION: ', $cached-document-path))
            else (),
            <exist:dispatch>
            	{jcache:_set-authentication-parameters()}
              <exist:forward url="/code/modules/passthrough.xql">
              	<exist:add-parameter name="doc" value="{$cached-document-path}"/>
              </exist:forward>
            </exist:dispatch>)
          else (
            (: the cache is nonexistent, out of date, in progress.  process and cache the document :)
            if (jcache:_flag-is-active($collection, $resource)
            	or not(app:authenticate()))
            then (
              (: caching is already in progress, but we have an active request *or*
               : the user is not authenticated, so we can't cache the document:
               : return the processed document, but don't cache it
               :)
              if ($paths:debug)
              then
              	util:log-system-out(('jcache: being called for ', $document-path, ' which cannot be cached now. user=', xmldb:get-current-user()))
              else (),
              <exist:dispatch>
                <exist:forward url="/code/modules/run-xslt.xql">
                	{jcache:_set-authentication-parameters()}
                  <exist:add-parameter name="script" value="concurrent/concurrent.xsl2"/>
                  <exist:add-parameter name="document">{
                    attribute {'value'}{
                      if (starts-with($document-path, '/db')) 
                      then $document-path
                      else app:concat-path('/db', $document-path)
                    } 
                  }</exist:add-parameter>
                </exist:forward>
              </exist:dispatch>
             )
            else (
              (: the document needs to be cached. :)
              let $dbcollection := 
                if (starts-with($collection, '/db')) then $collection else concat('/db', $collection)
              return 
                jcache:_commit-cache($dbcollection, $resource),
              <exist:dispatch>
              	{jcache:_set-authentication-parameters()}
                <exist:forward url="/code/modules/passthrough.xql">
                	<exist:add-parameter name="doc" value="{$cached-document-path}"/>
                </exist:forward>
              </exist:dispatch>
            )
          )
      else
        (: caching is not requested, but we may need a passthrough for login: ignore and continue :)
        if ($path-is-document)
        then
        	<exist:dispatch>
        		{jcache:_set-authentication-parameters()}
        		<exist:forward url="/code/modules/passthrough.xql">
        			<exist:add-parameter name="doc" value="{$document-path}"/>
        		</exist:forward>
        	</exist:dispatch> 
        else
        	<exist:ignore/>
    else
      (: document doesn't exist or is binary :)
      <exist:ignore/>
  )
};

