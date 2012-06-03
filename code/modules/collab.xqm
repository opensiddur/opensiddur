xquery version "1.0";
(:~ collaboration groups functions
 : 
 : Open Siddur Project
 : Copyright 2011-2012 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
module namespace collab="http://jewishliturgy.org/modules/collab";

import module namespace app="http://jewishliturgy.org/modules/app"
	at "app.xqm";

declare namespace xrx="http://jewishliturgy.org/xrx";
declare namespace tei="http://www.tei-c.org/ns/1.0";


(:~ given privacy settings, find the collection path 
 : @param $sharing privacy settings: 'private', 'public', 'group'
 : @param $group if the privacy setting is 'group', specifies which group
 : @param $purpose purpose ('original', 'translation')
 : @param $language language code of primary language
 :)
declare function collab:collection-by-collab(
	$sharing as xs:string,
	$group as xs:string?,
	$purpose as xs:string?,
	$language as xs:string?
	) as xs:string {
	let $user := app:auth-user()
	return
		app:concat-path(( 
			if ($sharing = 'private')
			then
				(xmldb:get-user-home($user), 'data')
			else if ($sharing = 'public')
			then
				'/data/incoming'
			else if ($sharing = 'group')
			then 
				if (not($group))
				then
					error(xs:QName('err:INVALID'), 'Group sharing must also specify a group parameter')
				else if (not(xmldb:get-user-groups($user) = $group))
				then
					error(xs:QName('err:INVALID'), 'You can only share with a group you are a member of')
				else
					('/group', $group, 'data')
			else
				error(xs:QName('err:INVALID'), 'The sharing parameter must be one of public, private, or group')
			, 
			$purpose, $language))
};

(:~ return a path given all collaboration information :)
declare function collab:path-by-collab(
	$resource as xs:string?,
	$sharing as xs:string,
	$group as xs:string?,
	$purpose as xs:string,
	$language as xs:string
	) as xs:string {
	let $collection := 
		collab:collection-by-collab(
				$sharing, $group, $purpose, $language
			)
	return
		if ($resource)
		then 
			app:concat-path( 
				$collection, 
				if (ends-with($resource, '.xml'))
				then $resource
				else 
					(: add default extension:) 
					concat($resource, '.xml') 
			)
		else $collection
};
	

(:~ return a path given a document metadata structure :)
declare function collab:path-by-metadata(
	$meta as element(xrx:document)
	) as xs:string {
	($meta/xrx:ptr,
		collab:path-by-collab(
			string($meta/xrx:resource),
			string($meta/xrx:sharing), string($meta/xrx:group), 
			string($meta/xrx:purpose), string($meta/xrx:language)
			)
	)[1]
	
};

(: return a <document> metadata structure, given a full database path
 : to the document
 :)
declare function collab:metadata-by-path(
	$path as xs:string
	) as element(xrx:document) {
	<xrx:document>{
		let $path-parts := tokenize(replace($path, '^(http[s]?://[^/]+)?(/db)?[/]?',''), '/')
		let $document-name := util:document-name($path)
		let $sharing := 
			if ($path-parts[1] = 'home')
			then (
				(: home directories, it's private :)
				'private'
			)
			else if ($path-parts[1] = 'data')
			then (
				(: data directory, it's global :)
				'public'
			)
			else if ($path-parts[1] = 'group')
			then
				(: group :)
				'group'
			else
				error(xs:QName('err:INVALID'), concat('Invalid path: ', $path, ': Is it really a data file?'))
		return (
			<xrx:resource>{$document-name}</xrx:resource>,
			<xrx:sharing>{$sharing}</xrx:sharing>,
			if ($sharing = 'group')
			then
				<xrx:group>{$path-parts[2]}</xrx:group>
			else <group/>,
			<xrx:purpose>{$path-parts[if ($document-name) then (last() - 2) else (last() - 1)]}</xrx:purpose>,
			<xrx:language>{$path-parts[if ($document-name) then (last() - 1) else last()]}</xrx:language>,
			<xrx:ptr>{$path}</xrx:ptr>,
			if (doc-available($path))
			then doc($path)/tei:TEI/tei:teiHeader//tei:title
			else <tei:title xml:lang=""/>
		)
	}</xrx:document>
};

(:~ derive a metadata structure from request parameters 
 :
 :)
declare function collab:metadata-by-request(
	) as element(xrx:document) {
	let $resource := (
		request:get-parameter('resource', ()), 
		request:get-parameter('xrx:resource', ())
		)[1]
	let $sharing := (
		request:get-parameter('sharing', ()),
		request:get-parameter('xrx:sharing', 'private')
		)[1]
	let $group := (
		request:get-parameter('group', ()),
		request:get-parameter('xrx:group', ())
		)[1]
	let $purpose := (
		request:get-parameter('purpose', ()),
		request:get-parameter('xrx:purpose', 'original')
		)[1]
	let $language := (
		request:get-parameter('language', ()),
		request:get-parameter('xrx:language', 'he')
		)[1]
	let $ptr := collab:path-by-collab($resource, $sharing, $group, $purpose, $language)
	return
	<xrx:document xmlns="">
		<xrx:resource>{replace($resource, '\.xml$', '')}</xrx:resource>
		<xrx:sharing>{$sharing}</xrx:sharing>
		<xrx:group>{$group}</xrx:group>
		<xrx:purpose>{$purpose}</xrx:purpose>
		<xrx:language>{$language}</xrx:language>
		<xrx:ptr>{$ptr}</xrx:ptr>
		{
		if (doc-available($ptr))
		then
			doc($ptr)/tei:TEI/tei:teiHeader//tei:title
		else
			<tei:title xml:lang=""/>
		}
	</xrx:document>
};

(:~ find who should be the owner of a collection or resource, given current login
 :)
declare function collab:get-owner(
	$sharing as xs:string,
	$group as xs:string?
	) as xs:string {
	if ($sharing = ('private','group')) 
	then app:auth-user()
	else 'admin'
};

(:~ find what group should own a collection or resource, given current login and sharing properties :)
declare function collab:get-group(
	$sharing as xs:string,
	$group as xs:string?
	) as xs:string {
	if ($sharing = 'private') 
	then app:auth-user()
	else if ($sharing = 'group') 
	then $group 
	else 'everyone'
};

(:~ find what mode should be given to a collection or resource, given login and sharing properties :)
declare function collab:get-mode(
	$sharing as xs:string,
	$group as xs:string?
	) as xs:string {
	"rwxrwx---"
};

(:~ store a resource in the right collection with the right permissions, 
 : return the path if successful 
 :)
declare function collab:store(
	$meta as element(xrx:document),
	$data as node()
	) as xs:string? {
	collab:store(
		let $res := string($meta/xrx:resource)
		return
			if (ends-with($res, '.xml'))
			then $res
			else concat($res, '.xml'),
		string($meta/xrx:sharing),
		string($meta/xrx:group),
		string($meta/xrx:purpose),
		string($meta/xrx:language),
		$data)
};

(:~ store a resource given the path to it :)
declare function collab:store-path(
	$path as xs:string,
	$data as node()
	) as xs:string? {
	let $path-tokens := tokenize(replace($path, '^/db', ''), '/')
	let $collection := string-join(subsequence($path-tokens, 1, count($path-tokens) - 1), '/')
	let $resource := $path-tokens[last()]
	let $user-owner := app:auth-user()
	let $group-owner := $path-tokens[3]	(: ('', 'group|home', '') :)
	let $mode := "rwxrwx---"
	return (
		app:make-collection-path(
			$collection, '/', $user-owner, $group-owner, $mode
		),
		let $store := xmldb:store($collection, $resource, $data)
		return
			if ($store)
			then (
			  sm:chown(xs:anyURI($path), $user-owner),
			  sm:chgrp(xs:anyURI($path), $group-owner),
			  sm:chmod(xs:anyURI($path), $mode),
				$store
			)
			else () 
	)
};

(:~ store a resource in the right collection with the right permissions, 
 : return the path if successful 
 :)
declare function collab:store(
	$resource-name as xs:string,
	$sharing as xs:string,
	$group as xs:string?,
	$purpose as xs:string,
	$language as xs:string,
	$data as node()
	) as xs:string? {
	let $collection := 
		collab:collection-by-collab($sharing, $group, $purpose, $language)
	let $permissions-user :=
		collab:get-owner($sharing, $group)
	let $permissions-group :=
		collab:get-group($sharing, $group)
	let $mode := 
		collab:get-mode($sharing, $group)
	return (
		app:make-collection-path(
				$collection, '/', $permissions-user, $permissions-group, $mode 
			),
		let $return-name := xmldb:store($collection, $resource-name, $data)
		return
			if ($return-name)
			then (
				xmldb:set-resource-permissions($collection, $resource-name, 
					$permissions-user, $permissions-group, $mode),
				$return-name
			)
			else ()
	)
};

(:~ list xml resources in a given collection and its non-cache/non-trash subcollections
 : return a document metadata structure
 :)
declare function collab:list-resources(
	$top-level-collection as xs:string
	) as element(xrx:document)* {
	if (xmldb:collection-available($top-level-collection))
	then (
		let $collections := tokenize(replace($top-level-collection, '^/(db/)?', ''), '/')
		return
			for $resource in xmldb:get-child-resources($top-level-collection)[ends-with(., '.xml')]
			let $ptr := app:concat-path($top-level-collection, $resource)
			return
			<xrx:document>
				<xrx:resource>{replace($resource, '\.xml$', '')}</xrx:resource>
				<xrx:sharing>{
					if ($collections[1] = 'group')
					then 'group'
					else if ($collections[1] = 'data')
					then 'public'
					else 'private'
				}</xrx:sharing>
				{
				if ($collections[1] = 'group')
				then 
					<xrx:group>{xmldb:get-group($top-level-collection, $resource)}</xrx:group>
				else ()
				}
				<xrx:purpose>{$collections[last() - 1]}</xrx:purpose>
				<xrx:language>{$collections[last()]}</xrx:language>
				{doc($ptr)/tei:TEI/tei:teiHeader//tei:title}
				<xrx:ptr>{$ptr}</xrx:ptr>
			</xrx:document>
		,
		for $subcollection in xmldb:get-child-collections($top-level-collection)[not(.=('cache','trash'))]
		return collab:list-resources(app:concat-path($top-level-collection, $subcollection))
	)
	else ()
};

(: given a base collection, filter the subcollect :)
declare function collab:filter-subcollections(
	$collection as xs:string, 
	$filter as xs:string?
	) as xs:string* {
	if (xmldb:collection-available($collection))
	then 
		for $subcollection in xmldb:get-child-collections($collection)[not(.=('cache','trash'))]
		where (
			if ($filter) 
			then $subcollection = $filter  
			else true()
		)
		return app:concat-path($collection, $subcollection)
	else ()
};

(:~ list the documents that are accessible to the current user 
 : according to the set of filters 
 : @param $sharings may be any or all of 'private', 'public', 'group'; if 'group', $groups may be used to filter by group
 : @param $groups list of groups to filter by (empty for no filter)
 : @param $purposes may be 'original', 'translation' (empty for no filter)
 : @param $languages primary language (empty for no filter)
 :)
declare function collab:list-accessible-documents(
	$sharings as xs:string*,
	$groups as xs:string*,
	$purposes as xs:string*,
	$languages as xs:string*
	) as element(xrx:documents) {
	<xrx:documents>{
		let $user := app:auth-user()
		let $home := xmldb:get-user-home($user)
		let $user-groups := xmldb:get-user-groups($user)
		let $use-sharings :=
			if (exists($sharings))
			then $sharings
			else ('private','public','group')
		let $collection-bases as xs:string* :=
			(: collection base without purpose, language :)
			for $sharing in $use-sharings 
			return
				if ($sharing = 'group')
				then (
					for $group in (
						if (exists($groups))
						then $groups
						else $user-groups
						)
					return collab:collection-by-collab($sharing, $group, (), ())
				)
				else (
					(: looking for public or private, group does not matter :)
					collab:collection-by-collab($sharing, (), (), ())
				)
		let $collection-bases-with-purpose :=
			for $collection-base in $collection-bases
			return collab:filter-subcollections($collection-base, $purposes)
		let $collection-bases-with-language :=
			for $purpose-base in $collection-bases-with-purpose
			return collab:filter-subcollections($purpose-base, $languages)
		let $resource-list :=
			for $language-base in $collection-bases-with-language
			return collab:list-resources($language-base)
		return
			for $resource in $resource-list
			order by string-join(($resource/tei:title, $resource/xrx:resource), ' ')
			return $resource
	}</xrx:documents>
};
