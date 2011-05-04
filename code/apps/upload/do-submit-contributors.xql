xquery version "1.0";
(: do-submit-contributors.xql
 : Submit the corrections to the contributor list, return
 : a template for the categorization step 
 : Requires login
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: do-submit-contributors.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace err="http://jewishliturgy.org/apps/errors";
declare option exist:serialize "method=xml media-type=text/xml";
declare option exist:output-size-limit "500000"; (: 50x larger than default :)

import module namespace app="http://jewishliturgy.org/ns/functions/app";
import module namespace catgui="http://jewishliturgy.org/apps/upload/catgui"
	at "categorize-gui.xqm";
import module namespace contributors="http://jewishliturgy.org/apps/lib/contributors"
	at "../lib/contributors.xqm";
import module namespace paths="http://jewishliturgy.org/apps/lib/paths"
	at "../lib/paths.xqm";
import module namespace savecontrib="http://jewishliturgy.org/apps/contributors/save"
	at "../contributors/save.xqm";	

let $logged-in := app:authenticate() or 
	error(xs:QName('err:NOT_LOGGED_IN'), 'You must be logged in.')
let $data := request:get-data()
let $unknown-contribs := $data/unknown-contributors/tei:item
let $mini-contributor-list :=
	if ($unknown-contribs)
	then
		<tei:list>{
			$unknown-contribs
		}</tei:list>
	else ()
let $saved :=
	empty($unknown-contribs) or
	savecontrib:save($mini-contributor-list, 'append')
return (
	if ($saved)
	then (
		<categories xmlns="">{
			$catgui:prototype/*,
			$data/written-files
		}</categories>
	)
	else
		error(xs:QName('err:SAVING'), 'Error saving new contributors.')
	)