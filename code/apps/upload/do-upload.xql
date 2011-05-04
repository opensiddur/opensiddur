xquery version "1.0";
(: do-upload.xql
 : Enter data into db /data hierarchy
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: do-upload.xql 709 2011-02-24 06:37:44Z efraim.feinstein $
 :)
import module namespace app="http://jewishliturgy.org/ns/functions/app";
 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace err="http://jewishliturgy.org/apps/errors"; 

declare option exist:serialize "method=xml media-type=text/xml";

let $logged-in := app:authenticate() or 
	error(xs:QName('err:NOT_LOGGED_IN'),'You must be logged in.')
let $user-name := app:auth-user()
let $data := request:get-data()
let $translation-name := 
	if (starts-with($data/translation-name, 'START NEW'))
	then $data/new-translation-name
	else $data/translation-name
let $dest-collection := string-join((
	'/db/data/incoming/', 
	$data/language,
	if ($data/is-original = 'true') 
	then '/original' 
	else (
		'/translation/',
		$translation-name
		)
	),'')
let $file-list := $data/written-files/file
return (
	util:log-system-out(('file-list = ', $file-list)),
	app:make-collection-path($dest-collection, '/', 'admin','everyone',util:base-to-integer(0775,8)),
	for $file in $file-list
	let $collection := util:collection-name(string($file))
	let $resource := util:document-name(string($file))
	where not($resource = ('index.xml','contributors.xml')) 
	return (
		util:log-system-out(('data = ', $data, ' collection = ', $collection, ' resource = ', $resource, ' dest-collection=', $dest-collection)),
		xmldb:copy($collection, $dest-collection, $resource),
		xmldb:set-resource-permissions($dest-collection, $resource, 'admin', 'everyone', util:base-to-integer(0775,8))
	),
	$data
)
