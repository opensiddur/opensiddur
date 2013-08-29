xquery version "1.0";
(: run an xslt script, relative to /code/transforms 
 : The existence of this XQuery is a kluge because you have to start XSLT through xsl:import
 : The script accepts one parameter script=, which points to the script
 :  document= points to the document you run the script on *or* post the document to the script
 : 
 : The Open Siddur Project
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 : $Id: run-xslt.xql 769 2011-04-29 00:02:54Z efraim.feinstein $
 :)

import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace transform="http://exist-db.org/xquery/transform";

import module namespace app="http://jewishliturgy.org/modules/app" at "/code/modules/app.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths" at "/code/modules/paths.xqm";



declare namespace xsl="http://www.w3.org/1999/XSL/Transform";

let $authenticated := app:authenticate()
let $script := request:get-parameter('script', '')
let $document-param := request:get-parameter('document','')
let $document := 
  if ($document-param)
  then doc($document-param)
  else request:get-data()
return (
	if ($paths:debug)
	then
	  util:log-system-out(
	  <debug src="run-xslt.xql">
	    <script>{$script}</script>
	    <document>{$document-param}</document>
	    <user>{app:auth-user()}</user>
	  </debug>)
	else (),
  app:transform-xslt($document-param, app:concat-path('/db/code/transforms/', $script),(), ()) 
)
