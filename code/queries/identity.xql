xquery version "1.0";
(:~ identity query
 : 
 : 
 : $Id: identity.xql 714 2011-03-13 21:56:57Z efraim.feinstein $
 :)
import module namespace request="http://exist-db.org/xquery/request";

declare option exist:serialize "method=xml";

let $uri := request:get-parameter('uri', ())
return
	if ($uri)
	then
		doc($uri) 
	else
		request:get-data()