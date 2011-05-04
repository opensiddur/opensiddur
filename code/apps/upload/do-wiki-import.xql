xquery version "1.0";
(: do-wiki-import.xql
 : Import text from the wiki
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: do-wiki-import.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
declare option exist:serialize "method=xml media-type=text/xml";
declare option exist:output-size-limit "500000"; (: 10x larger than default :)

import module namespace wiki="http://jewishliturgy.org/apps/lib/wiki" 
	at "../lib/wiki.xqm";
import module namespace namegui="http://jewishliturgy.org/apps/upload/namegui" 
	at "name-gui.xqm";
import module namespace scangui="http://jewishliturgy.org/apps/upload/scangui" 
	at "scangui.xqm";
	
let $incoming-text as xs:string := wiki:from-post()
return
	let $return-val :=
	<corrections xmlns="">
		<bibliography/>
		<language>{
			(: try to guess the primary language of the text :)
			let $en-chars := string-length(replace($incoming-text, '[\P{IsBasicLatin}]','','s')) 
			let $he-chars := string-length(replace($incoming-text, '[\P{IsHebrew}]','','s'))
			return
				if ($en-chars > $he-chars) 
				then 'en'
				else 'he'
		}</language>
		<license>{
			(: try to guess the license, default to cc0 :)
			if (matches($incoming-text, 'ShareAlike', 's'))
			then 'cc-by-sa'
			else if (matches($incoming-text, 'Attribution', 's'))
			then 'cc-by'
			else 'cc0'
		}</license>
		<index-name>{$namegui:default-index-name}</index-name>
		<index-title/>
		<has-facsimile>true</has-facsimile>
		<facsimile/>
		<text>
			{$incoming-text}
		</text>
	</corrections>
	return 
		(util:log-system-out($return-val), $return-val)