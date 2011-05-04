xquery version "1.0";
(: index.xql
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: index.xql 522 2010-06-24 18:35:25Z efraim.feinstein $
 :)
import module namespace login="http://jewishliturgy.org/apps/lib/login" at "lib/login.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";

let $xslt-pi := processing-instruction xml-stylesheet {'type="text/xsl" href="/exist/rest/db/xforms/xsltforms/xsltforms.xsl"'}
let $debug := processing-instruction xsltforms-options {'debug="yes"'}
let $form :=
	<html xmlns="http://www.w3.org/1999/xhtml">
		<head>
			<title>Open Siddur Apps index</title>
			{login:form-model()}
		</head>
		<body>
			<h1>Open Siddur XRX Applications index</h1>
			<div>
				<h2>User management</h2>
				{login:form-ui()}
				<ul>
					<li><a href="user/new.xql">New database user (link a database user name to a wiki name)</a></li>
					<li><a href="user/login.xql">Login</a></li>
					<li><a href="contributors/edit.xql">Contributor list management</a></li>
				</ul>
			</div>
			<div>
				<h2>Sources management</h2>
				<ul>
					<li><a href="bibliography/edit.xql">Bibliography editor</a></li>
				</ul>
			</div>
			<div>
				<h2>Content Encoding and Upload</h2>
				<ul>
					<li><a href="upload/wiki-import.xql">Assemble text from wiki</a></li>
					<li>File splitting</li>
					<li>Auto-encoding</li>
					<li>Computer-aided fixup</li>
					<li>Categorize and upload</li>
				</ul>
			</div>
		</body>
	</html>
return
	($xslt-pi, $form) 