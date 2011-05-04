xquery version "1.0";
(: Login UI (mostly a test form for login.xqm)
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: index.xql 688 2011-01-28 20:24:16Z efraim.feinstein $
 :)
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace err="http://jewishliturgy.org/apps/errors";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";

import module namespace user="http://jewishliturgy.org/apps/user" 
	at "/code/apps/user/modules/login.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths" 
	at "../../modules/paths.xqm";
import module namespace site="http://jewishliturgy.org/modules/site"
	at "../../modules/site.xqm";

let $form := 
	site:form(
		<xf:model>
			{user:login-instance('login')}
		</xf:model>,
		<title xmlns="http://www.w3.org/1999/xhtml">Login form control</title>,
		(
		<h1 xmlns="http://www.w3.org/1999/xhtml">Login form control test</h1>,
		user:login-ui('login','control-login')
		)
	)
return ($paths:xslt-pi,$paths:debug-pi,$form)
