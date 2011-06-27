(:~
 : XQuery functions to output a given XML file in a format.
 : 
 : Copyright 2011 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: format.xqm 708 2011-02-24 05:40:58Z efraim.feinstein $ 
 :)
module namespace format="http://jewishliturgy.org/modules/format";

declare namespace exist="http://exist.sourceforge.net/NS/exist";
declare namespace err="http://jewishliturgy.org/errors";

import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace app="http://jewishliturgy.org/modules/app" 
  at "xmldb:exist:///code/modules/app.xqm";
import module namespace jcache="http://jewishliturgy.org/modules/cache" 
  at "xmldb:exist:///code/modules/cache-controller.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths" 
  at "xmldb:exist:///code/modules/paths.xqm";


declare variable $format:temp-dir := '.format';
declare variable $format:path-to-xslt := '/db/code/transforms';

declare function format:_wrap-document(
	$node as node()
	) as document-node() {
	if ($node instance of document-node())
	then $node
	else document {$node}
};

declare function format:data-compile(
	$jlptei-uri-or-node as item()	
	) as document-node() {
	format:_wrap-document(
		let $uri-or-node :=
			if ($jlptei-uri-or-node instance of xs:string)
			then (
        jcache:cache-all($jlptei-uri-or-node),
        jcache:cached-document-path($jlptei-uri-or-node) (:concat($jlptei-uri-or-node,	'?format=fragmentation'):)
      )
			else (
        jcache:cache-all(document-uri(root($jlptei-uri-or-node))),
        $jlptei-uri-or-node
      )
		return
			app:transform-xslt($uri-or-node, 
				app:concat-path($format:path-to-xslt, 'data-compiler/data-compiler.xsl2'),
				(), ())
	)
};

declare function format:list-compile(
	$data-compiled-node as item()
	) as document-node() {
	format:_wrap-document(
		app:transform-xslt($data-compiled-node, 
			app:concat-path($format:path-to-xslt, 'list-compiler/list-compiler.xsl2'),
			(), ())
	)
};

declare function format:format-xhtml(
	$list-compiled-node as item(),
	$style-href as xs:string?
	) as document-node() {
	format:_wrap-document(
		app:transform-xslt($list-compiled-node, 
			app:concat-path($format:path-to-xslt, 'format/xhtml/xhtml.xsl2'),
			if ($style-href)
			then <param name="style" value="{$style-href}"/>
			else ()
			, ())
	)
};

declare function format:format-xhtml(
	$list-compiled-node as item()
	) as document-node() {
	format:format-xhtml($list-compiled-node, ())
};

declare function format:compile(
	$jlptei-uri as xs:string,
	$final-format as xs:string
	) as document-node()? {
	format:compile($jlptei-uri, $final-format, ())
};

declare function format:compile(
	$jlptei-uri as xs:string,
	$final-format as xs:string,
	$style-href as xs:string?
	) as document-node()? {
	let $data-compiled as document-node() := format:data-compile($jlptei-uri)
	return 
		if ($final-format = 'debug-data-compile')
		then $data-compiled
		else 
			let $list-compiled as document-node() := format:list-compile($data-compiled)
			return
				if ($final-format = 'debug-list-compile')
				then $list-compiled
				else
					let $html-compiled as document-node() := format:format-xhtml($list-compiled, $style-href)
					return
						if ($final-format = ('html','xhtml'))
						then $html-compiled
						else error(xs:QName('err:UNKNOWN'), concat('Unknown format ', $final-format))
};

(:~ Equivalent of the main query.  
 : Accepts the controller's exist:* external variables as parameters 
 : request parameters format and clear may also be used 
 : returns an element in the exist namespace 
 :)
declare function format:format-query(
  $path as xs:string,
  $resource as xs:string,
  $controller as xs:string,
  $prefix as xs:string,
  $root as xs:string) 
  as element()? {
  let $user := app:auth-user()
  let $password := app:auth-password()
  let $document-path := 
    app:concat-path($controller, $path)
  let $collection :=
    (: collection name, always ends with / :)
    let $step1 := util:collection-name($document-path)
    return
      if (ends-with($step1, '/')) then $step1 else concat($step1, '/')
  let $format := request:get-parameter('format', '')
  let $output := request:get-parameter('output', '')
  let $output-collection := util:collection-name($output)
  (: util:document-name() won't return a nonexistent document's name :)
  let $output-resource := tokenize($output,'/')[last()] 
  where (app:require-authentication())
  return
  	if (xmldb:store($output-collection, $output-resource, format:compile($document-path, $format)) )
  	then (
  		if ($format = ('html', 'xhtml'))
  		then xmldb:copy(app:concat-path($format:path-to-xslt, 'format/xhtml'), $output-collection, 'style.css')
  		else (),
  		<exist:dispatch>
  			<exist:forward url="/code/modules/view-html.xql">
  				<exist:add-parameter name="doc" value="{$output}"/>
  			</exist:forward>
  		</exist:dispatch>
  	)
  	else
  		error(xs:QName('err:STORE'), concat('Could not store ', $document-path))
};
