xquery version "1.0";
(: wiki.xqm
 : General wiki interface
 :
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: wiki.xqm 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
module namespace wiki="http://jewishliturgy.org/modules/wiki";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";

declare option exist:serialize "method=text media-type=text/plain indent=no process-pi-xsl=no";

declare variable $wiki:server := 'http://wiki.jewishliturgy.org';
declare variable $wiki:path := '/w/index.php?title=';

(:~ Determine if a wiki user's login and password are correct 
 : @param $user-name Name of the wiki user
 : @param $password Password 
 :)
declare function wiki:valid-user(
	$user-name as xs:string,
	$password as xs:string)
	as xs:boolean {
	
	let $mediawiki-login := xs:anyURI(concat(
		'http://wiki.jewishliturgy.org/w/api.php?action=login&amp;lgname=', $user-name, 
		'&amp;lgpassword=', $password, 
		'&amp;format=xml')) 
	let $mediawiki-response := httpclient:post($mediawiki-login, '', false(), ())
	let $mediawiki-answer := $mediawiki-response//@result
	return xs:boolean($mediawiki-answer = 'Success')
};
