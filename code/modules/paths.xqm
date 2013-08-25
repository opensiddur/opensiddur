(: Path mnemonics
 : Open Siddur Project
 : Copyright 2010-2011 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Released under the GNU Lesser General Public License, ver 3 or later
 : $Id: paths.xqm 771 2011-04-29 04:24:30Z efraim.feinstein $
 :)
xquery version "1.0";

module namespace paths="http://jewishliturgy.org/modules/paths";

(: requires "/rest" in the uri or not? :)
declare variable $paths:requires-rest := true();
(:~ Choice of XForms processor: for now, may be 'betterform' or 'xsltforms' :)
declare variable $paths:xforms-processor := 'xsltforms';
(:~ path to web application context, relative to server root 
 : either '' or 'exist' :)
declare variable $paths:exist-prefix := 
	if (request:exists())
	then substring-after(request:get-context-path(),'/')
	else 'exist';	
(:~ path to db rest interface, relative to server root :)
declare variable $paths:prefix := concat('/', $paths:exist-prefix, 
	if ($paths:exist-prefix and $paths:requires-rest) then '/' else '', 
  if ($paths:requires-rest) then 'rest' else '');
(:~ constant beginning part of REST URL :)
declare variable $paths:internal-rest-prefix :=
		concat(
			'http://localhost:8080', 
			$paths:prefix); 
declare variable $paths:rest-prefix :=
	if (request:exists())
	then $paths:internal-rest-prefix
	else '';
(:~ absolute REST URL prefix as seen from the outside the server:)
declare variable $paths:external-rest-prefix :=
	if (request:exists())
	then
		concat(
			'http://', request:get-server-name(), ':', request:get-server-port(), 
			$paths:prefix) 
	else '';

declare variable $paths:webapp := '/webapp';  (: server local hdd :)
(:~ db path to apps.  concat to $paths:prefix or $paths:rest-prefix :)
declare variable $paths:apps := '/db/code/apps';
(:~ absolute db path to modules.  Concat to $paths:prefix for an absolute path :)
declare variable $paths:modules := '/db/code/modules';	
declare variable $paths:xforms := concat($paths:external-rest-prefix, 'db/apps/xsltforms/xsltforms.xsl');
declare variable $paths:xslt-pi := 
	if ($paths:xforms-processor = 'xsltforms')
	then ( 
		processing-instruction xml-stylesheet {
			concat('type="text/xsl" href="',
			$paths:xforms, 
			'"')},
		processing-instruction css-conversion {'no'}
	)
	else ();
(:~ when to debug: when not on the primary server :)
declare variable $paths:debug as xs:boolean :=
	if (request:exists())
  then request:get-server-name()='localhost'
  else true();
declare variable $paths:debug-pi := 
	if ($paths:xforms-processor = 'xsltforms')
	then
		if (request:exists() and not(request:get-server-name()='localhost')) 
		then ()
		else processing-instruction xsltforms-options {'debug="yes"'}
	else ();
