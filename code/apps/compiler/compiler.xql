xquery version "1.0";
(:~ temporary compiler front end UI 
 : 
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: compiler.xql 770 2011-04-29 00:26:24Z efraim.feinstein $
 :)
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace app="http://jewishliturgy.org/modules/app" 
	at "/code/modules/app.xqm";
import module namespace builder="http://jewishliturgy.org/apps/builder/controls"
	at "/code/apps/builder/modules/builder.xqm";	
import module namespace controls="http://jewishliturgy.org/modules/controls" 
	at "/code/modules/controls.xqm";
import module namespace site="http://jewishliturgy.org/modules/site" 
	at "/code/modules/site.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace ev="http://www.w3.org/2001/xml-events";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace xf="http://www.w3.org/2002/xforms";

declare option exist:serialize "method=xhtml media-type=application/xml omit-xml-declaration=no indent=yes 
        doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
        doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd";

declare variable $local:version := app:get-version();

let $error-instance := 'error'
let $document-chooser-id := 'chooser'
return
site:form(
	<xf:model>{
		controls:error-instance($error-instance),
		builder:document-chooser-instance(
			$document-chooser-id, false(), 'everyone'
		)
		}
		<xf:instance id="garbage">
			<!-- workaround for Firefox bug -->
			<tei:TEI j:junk="1" html:junk="1" xml:lang="en"/>
		</xf:instance>
		<xf:instance id="blank">
			<blank xmlns=""/>
		</xf:instance>
		<xf:instance id="resource">
			<resource xmlns="">
				<item>{request:get-parameter('item', ())}</item>
			</resource>
		</xf:instance>
		<xf:instance id="return">
			<return xmlns="">
				<path/>
			</return>
		</xf:instance>
		<xf:submission id="compile-submit"
			method="post"
			ref="instance('blank')"
			replace="none"
			mode="asynchronous"
			>
			<xf:resource value="concat(instance('resource')/item, '?compile=xhtml&amp;output={app:auth-user()}')"/>
			{
			controls:submission-response(
				$error-instance,
  			(),
  			(
  				<xf:setvalue ref="instance('return')/path" 
  					value="event('response-headers')/self::header[name='Location']/value"/>,
  				<xf:load show="new">
  					<xf:resource value="instance('return')/path"/>
  				</xf:load>
  			)
			)
		}</xf:submission>
		<xf:submission id="logout-submit" 
			method="post" 
			action="/code/api/user/logout" 
			ref="instance('blank')" 
			replace="none">{
			controls:submission-response(
				$error-instance, (), ()
			)
		}</xf:submission>
		<xf:action ev:event="xforms-model-destruct">
			{((: on exit, try to log out :))}
			<xf:send submission="logout-submit"/>
		</xf:action>
	</xf:model>,
	<title>Open Siddur Project Tech Demo v{$local:version}</title>,
	<body>
		<h1>Open Siddur Project Tech Demo v{$local:version}</h1>
		<p>This technology demonstration demonstrates the transform from the 
		<a href="http://wiki.jewishliturgy.org/JLPTEI">JLPTEI</a> XML format to XHTML and CSS
		that can be read by web browsers.</p>
		<p>It presents a menu of data from the <a href="http://tanach.us">Westminster Leningrad Codex</a> (WLC) Tanach</p>
		<p>As an early demo, it is by no means feature-complete, nor is it expected to be. Most of the
		technology being demonstrated is under the hood. Other demos, for example, the 
		<a href="/code/apps/builder">builder demo</a> include more interactive features.</p>
		<p>For the purposes of the demo, all users are logged in to the database with the username demouser and a transparent password.</p>
		<p>For a version history of this compiler, see <a href="http://wiki.jewishliturgy.org/TaNaKh_XML_to_XHTML_Conversion_Demonstration">the compiler demo wiki page</a>.</p>
		<p>To use the demo, select a book or chapter of the Tanach from the index below.  
		A new window or tab will open.  The transform may take anywhere from a few seconds to about 10 minutes,
		depending on the length of the book.  A new feature of the code is a 
		<a href="http://en.wikipedia.org/wiki/Cache">cache</a>, which pre-calculates the most complicated part of
		the transform for each file (in this case, by chapter) the first time it is needed.  Because of this feature,
		while the transform may take a long time the first time any chapter is used, subsequent uses of the
		same book or chapter will be many times faster.  Compiling the entire Tanach will take a very long time
		the first time it is done.  After it is done once, all compilations will be relatively fast.</p>
		<p>All software released by the <a href="http://opensiddur.org">Open Siddur Project</a> is 
		<a href="http://opensource.org/osd.html">free/open source software</a>.  The software is available from 
		<a href="http://jewishliturgy.googlecode.com">our subversion repository on Google Code</a>. To get involved
		in development or to discuss problems with the demo, talk to us on 
		<a href="http://groups.google.com/group/opensiddur-tech">our technical discussion mailing list</a>.
		</p>
		<p>Thank you for demo-ing the Open Siddur's technology!</p>
		{controls:error-report($error-instance)}
		<div id="menu" lang="he" xml:lang="he">
			{
      builder:document-chooser-ui(
				$document-chooser-id,
				concat('control-', $document-chooser-id),
				(
					<xf:trigger appearance="minimal">
						<xf:label>Compile</xf:label>
						<xf:action ev:event="DOMActivate">
							<xf:setvalue ref="instance('resource')/item" 
								value="context()/html:a/@href"/>
							<xf:send submission="compile-submit"/>
						</xf:action>
					</xf:trigger>			
  			)
			)
      }
		</div>
	</body>,
	(
		site:css(), builder:css(),
		controls:faketable-style(concat('control-', $document-chooser-id),	90,	4)
	)
)