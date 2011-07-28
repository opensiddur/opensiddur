(:~
 : XQuery functions to output a given XML file in a format.
 : 
 : Copyright 2011 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
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
import module namespace jobs="http://jewishliturgy.org/apps/jobs"
  at "xmldb:exist:///code/apps/jobs/modules/jobs.xqm";

declare variable $format:temp-dir := '.format';
declare variable $format:path-to-xslt := '/db/code/transforms';

(: stage numbers for compilation :)
declare variable $format:queued := 0;
declare variable $format:caching := 1;
declare variable $format:data := 2;
declare variable $format:list := 3;
declare variable $format:format := 4;


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

declare function format:enqueue-compile(
	$source-collection as xs:string,
  $source-resource as xs:string,
  $dest-collection as xs:string,
	$final-format as xs:string,
	$style-href as xs:string?) {
  format:enqueue-compile(
    $source-collection, $source-resource, 
    $dest-collection, $final-format,
    $style-href, (), ())
};


(:~ set up a compile operation in the job queue :)
declare function format:enqueue-compile(
	$source-collection as xs:string,
  $source-resource as xs:string,
  $dest-collection as xs:string,
	$final-format as xs:string,
	$style-href as xs:string?,
  $user as xs:string?,
  $password as xs:string?
  ) {
  let $user := ($user, app:auth-user())[1]
  let $password := ($password, app:auth-password())[1]
  let $total-steps := 
    if ($final-format = "fragmentation")
    then 1
    else if ($final-format = "debug-data-compile")
    then 2
    else if ($final-format = "debug-list-compile")
    then 3
    else if ($final-format = ("html","xhtml"))
    then 4
    else 
      (: unknown format :)
      error(xs:QName("err:FORMAT"), concat("Unknown format: ", $final-format))
  let $dest-resource :=
    (: make a list of resource names for each step in the transformation :)
    for $i in (1 to $total-steps)
    return
      replace(
        $source-resource, "\.xml$", 
        if ($i = 1)
        then ".frag.xml"
        else if ($i = 2)
        then ".data.xml"
        else if ($i = 3)
        then ".list.xml"
        else ".xhtml"
      )
  return (
    format:new-status($dest-collection, $source-resource, $source-collection, $source-resource, $total-steps),
    let $frag-job :=
      jobs:enqueue(
        <jobs:job>
          <jobs:run>
            <jobs:query>/code/apps/jobs/queries/bg-compile-cache.xqm</jobs:query>
            <jobs:param name="source-collection" value="{$source-collection}"/>
            <jobs:param name="source-resource" value="{$source-resource}"/>
            <jobs:param name="dest-collection" value="{$dest-collection}"/>
            <jobs:param name="dest-resource" value="{$dest-resource[1]}"/>
          </jobs:run>
        </jobs:job>, $user, $password)
    let $data-job := 
      if ($total-steps >= 2)
      then
        jobs:enqueue(
          <jobs:job>
            <jobs:run>
              <jobs:query>/code/apps/jobs/queries/bg-data-compile.xqm</jobs:query>
              <jobs:param name="source-collection" value="{jcache:cached-document-path($source-collection)}"/>
              <jobs:param name="source-resource" value="{$source-resource}"/>
              <jobs:param name="dest-collection" value="{$dest-collection}"/>
              <jobs:param name="dest-resource" value="{$dest-resource[2]}"/>
            </jobs:run>
            <jobs:depends>{string($frag-job)}</jobs:depends>
          </jobs:job>, $user, $password)
      else ()  
    let $list-job :=
      if ($total-steps >= 3)
      then
        jobs:enqueue(
          <jobs:job>
            <jobs:run>
              <jobs:query>/code/apps/jobs/queries/bg-list-compile.xqm</jobs:query>
              <jobs:param name="source-collection" value="{$dest-collection}"/>
              <jobs:param name="source-resource" value="{$dest-resource[2]}"/>
              <jobs:param name="dest-collection" value="{$dest-collection}"/>
              <jobs:param name="dest-resource" value="{$dest-resource[3]}"/>
            </jobs:run>
            <jobs:depends>{string($data-job)}</jobs:depends>
          </jobs:job>, $user, $password)
      else ()
    let $format-job :=
      if ($total-steps >= 4)
      then
        jobs:enqueue(
          <jobs:job>
            <jobs:run>
              <jobs:query>/code/apps/jobs/queries/bg-format-compile.xqm</jobs:query>
              <jobs:param name="source-collection" value="{$dest-collection}"/>
              <jobs:param name="source-resource" value="{$dest-resource[3]}"/>
              <jobs:param name="dest-collection" value="{$dest-collection}"/>
              <jobs:param name="dest-resource" value="{$dest-resource[4]}"/>
              <jobs:param name="style" value="{$style-href}"/>
            </jobs:run>
            <jobs:depends>{string($list-job)}</jobs:depends>
          </jobs:job>, $user, $password)
      else ()
    return ()
  )
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

declare function local:status-xml(
  $resource as xs:string
  ) as xs:string {
  replace($resource, "\.xml$", ".status.xml")
};

(:~ make a new status file for the given collection and resource.
 : the status file will generally be in the destination collection
 :)
declare function format:new-status(
  $collection as xs:string,
  $resource as xs:string,
  $source-collection as xs:string,
  $source-resource as xs:string,
  $total-steps as xs:integer
  ) {
  let $status-xml := local:status-xml($resource) 
  return
    if (xmldb:store($collection, $status-xml, 
      <status>
        <steps>{$total-steps}</steps>
        <current>0</current>
        <completed>0</completed>
        <location/>
      </status>
    ))
    then
      let $owner := xmldb:get-owner($source-collection, $source-resource)
      let $group := xmldb:get-group($source-collection, $source-resource) 
      let $mode := xmldb:get-permissions($source-collection, $source-resource) 
      return
        xmldb:set-resource-permissions($collection, $status-xml, $owner, $group, $mode)
    else
      error(xs:QName("err:STORE"), concat("Cannot store status file ", $status-xml))
};

(:~ return the status document,
 : which is a structure that looks like:
 :     <status>
 :       <steps></steps>         total number of steps
 :       <current></current>     current step
 :       <completed></completed> last step that was finished
 :       <location/>             location of the completed resource
 :     </status>
 :
 :)
declare function format:get-status(
  $collection as xs:string,
  $resource as xs:string
  ) as document-node() {
  doc(concat($collection, "/", local:status-xml($resource)))
};

declare function format:update-status(
  $collection as xs:string,
  $resource as xs:string,
  $new-stage as xs:integer
  ) {
  let $status-doc := doc(concat($collection, "/", local:status-xml($resource)))
  let $current := $status-doc//current
  return (
    update value $current with $new-stage
  ) 
};

(:~ Complete the current processing stage. If the processing is entirely complete,
 : set location with the final resource location :)
declare function format:complete-status(
  $collection as xs:string,
  $resource as xs:string
  ) {
  let $status-doc := doc(concat($collection, "/", local:status-xml($resource)))
  let $current := $status-doc//current
  let $completed := $status-doc//completed
  let $location := $status-doc//location
  let $steps := $status-doc//steps
  return (
    update value $completed with $current, 
    update value $current with "",
    if ($steps = $current)
    then update value $location with concat($collection, "/", $resource)
    else ()
  )
};
