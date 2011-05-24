xquery version "1.0";

(: site.xqm
 : Copyright 2010-2011 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 : $Id: site.xqm 767 2011-04-28 18:15:42Z efraim.feinstein $
 :)
module namespace site="http://jewishliturgy.org/modules/site";

import module namespace app="http://jewishliturgy.org/modules/app"
	at "app.xqm";
import module namespace controls="http://jewishliturgy.org/modules/controls"
	at "controls.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "paths.xqm";
import module namespace login="http://jewishliturgy.org/apps/user/login"
	at "/code/apps/user/modules/login.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace ev="http://www.w3.org/2001/xml-events";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace html="http://www.w3.org/1999/xhtml";

declare option exist:serialize "method=xhtml media-type=text/xml indent=yes omit-xml-declaration=no
	doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
	doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"; 


declare variable $site:resource-path := 'resources';
declare variable $site:templates-path := app:concat-path(($paths:prefix, $paths:modules, $site:resource-path));

(:~ write a form
 :
 : @param $model the XForms model 
 : @param $head-content the content of the page under the head element
 : @param $body-content the content of the page under the body element 
 :)
declare function site:form(
	$model as element(xf:model)?,
	$head-content as element()+,
	$body-content as element()+
	) as node()+ {

	site:form($model, $head-content, $body-content, 
		site:css(), site:header(), site:sidebar(), site:footer())
};

(:~ write a form with custom CSS link or style element
 : Use site:css() to get the default value
 :)
declare function site:form(
	$model as element(xf:model)?,
	$head-content as element()+,
	$body-content as element()+,
	$css as element()*
	) as node()+ {

	site:form($model, $head-content, $body-content, $css,
		site:header(), site:sidebar(), site:footer())
};

(:~ form with defaulted app-header :)
declare function site:form(
	$model as element(xf:model)?,
	$head-content as element()+,
	$body-content as element()+,
	$css as element()*,
	$header as element()*,
	$sidebar as element()*,
	$footer as element()*) 
	as node()+ {
	site:form($model, $head-content, $body-content, $css, $header, $sidebar, $footer,
		site:app-header())
};


(:~ write a form, long version that allows custom CSS, header, sidebar, footer, application header :)
declare function site:form(
	$model as element(xf:model)?,
	$head-content as element()+,
	$body-content as element()+,
	$css as element()*,
	$header as element()*,
	$sidebar as element()*,
	$footer as element()*,
	$app-header as element()*) 
	as node()+ {
	(
	$paths:xslt-pi, $paths:debug-pi,
	<html	xmlns:tei="http://www.tei-c.org/ns/1.0">
		<head>
			{
			$css,
			$head-content,
      (: favicon :)
      <link rel="shortcut icon" href="/code/modules/{$site:resource-path}/favicon.ico"/>,
			if ($paths:xforms-processor = 'xsltforms')
			then $model
			else ()
			}
		</head>
		<body>
			{
				if ($paths:xforms-processor = 'xsltforms')
				then ()
				else
					<div style="display:none">
						{ $model }
					</div>
			}
      <div id="allContent">
        <div id="header">{
          $header
        }</div>
        <div id="sidebar">{
          $sidebar
        }</div>
        {
        	if (exists($app-header))
        	then
        		<div id="appHeader">{
        			$app-header
        		}</div>
        	else ()
        }
        <div id="mainContent">{
          $body-content 
        }</div>
        <div id="footer">{
          $footer 
        }</div>
      </div>
		</body>
	</html>
	)
};

(:~ site wide styling pointers (link, style) :)
declare function site:css() 
	as element()* {
	<link type="text/css" rel="stylesheet" href="{$site:templates-path}/site.css"/>
};

(:~ site-wide header :)
declare function site:header() 
	as element()* {
	(
	
	)
};

(:~ show sidebar logo :)
declare function site:_sidebar-logo(
	) as element()+ {
	<div id="logo-div">
		<img id="logo" src="{$site:templates-path}/open-siddur-logo.png" alt="Open Siddur Logo"/>
		<div id="logo-text">The Open Siddur</div>
	</div>
}; 

(:~ return an id for a link submission given its target xql :)
declare function site:_link-submission-id(
	$target-xql as xs:string
	) as xs:string {
	concat('sidebar-',
		replace(
			replace($target-xql, '\.xql', '-submit'),
			'[/=?]', '-'
		)
	)
};

(:~ site-wide sidebar :)
declare function site:sidebar() 
	as element()* {
  (
  site:_sidebar-logo()
	)
};

(:~ return sidebar login actions :)
declare function site:sidebar-login-actions-id(
	) as xs:string {
	'sidebar-login-actions'
};

(:~ sidebar menu, whose content is dependent on the login state :)
declare function site:_sidebar-menu-ui(
	$login-instance-id as xs:string
	) as element()+ {
	<xf:group id="sidebar-login-actions">
		<xf:toggle ev:event="login" case="sidebar-login"/>
		<xf:toggle ev:event="logout" case="sidebar-logout"/>
	</xf:group>,
	<xf:switch id="sidebar-switch">
		<xf:case id="sidebar-login">
			<ul>
				<li><a href="/code/apps/builder/welcome.xql">Home</a></li>
				<li><a href="/code/apps/user/edit.xql">Edit user profile</a></li>
				<li><a href="/code/apps/builder/my-siddurim.xql">My Siddurim</a></li>
			</ul>
		</xf:case>
		<xf:case id="sidebar-logout">
			<ul>
				<li><a href="/code/apps/builder/welcome.xql">Home</a></li>
				<li><a href="/code/apps/user/new.xql">Create an account</a></li>
			</ul>
		</xf:case>
	</xf:switch>
};

(:~ standardized sidebar showing a login control 
 : attached to the given instance (which must be in the form's model
 : @param $login-instance-id login instance id
 : The control id is {$login-instance-id}-control
 :)
declare function site:sidebar-with-login(
	$login-instance-id as xs:string
	) as element()* {
	(
	site:_sidebar-logo(),
	login:login-ui($login-instance-id, concat($login-instance-id, '-control'), false()),
	site:_sidebar-menu-ui($login-instance-id)
	)	
};

(:~ site-wide footer :)
declare function site:footer() 
	as element()* {
  (
		<p>This site powered by <a href="http://www.exist-db.org">eXist</a> native XML database and {
			if ($paths:xforms-processor eq 'betterform') 
			then <a href="http://www.betterform.de">BetterFORM</a>
			else <a href="http://www.agencexml.com/xsltforms">XSLTForms</a>} XForms processor. The software is free and open source. See the <a href="http://jewishliturgy.googlecode.com">source code</a> for details.</p>
	)
};

(: the app-header is a header that goes inside the applet's space :)
declare function site:app-header()
	as element()* {
	()
};
