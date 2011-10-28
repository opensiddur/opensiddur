xquery version "1.0";
(: original text data api controller.
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
	at "/code/api/modules/data.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/code/modules/paths.xqm";
	
declare namespace exist="http://exist.sourceforge.net/NS/exist";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

(: queries that handle specific subresources :)
declare variable $local:query-base := concat($exist:controller, '/../queries');
declare variable $local:subresource :=
	<subresource>
		<s xquery="{$local:query-base}/lang.xql">lang</s>
		<s xquery="{$local:query-base}/title.xql">title</s>
		<s xquery="{$local:query-base}/title.xql">subtitle</s>
		<s xquery="{$local:query-base}/license.xql">license</s>
		<s xquery="{$local:query-base}/literal.xql">repository</s>
		<s xquery="{$local:query-base}/selection.xql">selection</s>
		<s xquery="{$local:query-base}/literal.xql">front</s>
    <s xquery="{$local:query-base}/compile.xql">compile</s>
    <s xquery="{$local:query-base}/nav.xql">nav</s>
	</subresource>;

if ($paths:debug)
then
	util:log-system-out(
	<debug from="data/original api controller">
		<user>{app:auth-user()}:{app:auth-password()}</user>
	  <uri>{request:get-uri()}</uri>
	  <path>{$exist:path}</path>
	  <root>{$exist:root}</root>
	  <controller>{$exist:controller}</controller>
	  <prefix>{$exist:prefix}</prefix>
	  <resource>{$exist:resource}</resource>
	</debug>
	)
else (),
let $has-search-query := request:get-parameter('q', ())
let $path-tokens := tokenize($exist:path, '/')[.]
let $n-tokens := count($path-tokens)
let $purpose := 'original'
let $share-type := $path-tokens[1]
let $owner := $path-tokens[2]
let $resource := 
	if ($n-tokens = 3 and contains($path-tokens[3], '.'))
	then substring-before($path-tokens[3], '.')
	else $path-tokens[3]
let $subresource := 
	if ($n-tokens = 4 and contains($path-tokens[4], '.'))
	then substring-before($path-tokens[4], '.')
	else $path-tokens[4]
let $subsubresource := 
	if ($n-tokens = 5 and contains($path-tokens[5], '.'))
	then substring-before($path-tokens[5], '.')
	else $path-tokens[5]	
let $format := substring-after($path-tokens[$n-tokens], '.')
let $sr := 
	if ($subresource = 'id')
	then data:forward-by-id($purpose, $share-type, $owner, $resource, $subsubresource)
	else $subresource
return
	if ($has-search-query)
	then
		<exist:dispatch>
			{app:pass-credentials-xq()}
			<exist:forward url="{$local:query-base}/search.xql">
				<exist:add-parameter name="purpose" value="{$purpose}"/>
				<exist:add-parameter name="share-type" value="{$share-type}"/>
				<exist:add-parameter name="owner" value="{$owner}"/>
				<exist:add-parameter name="resource" value="{$resource}"/>
				<exist:add-parameter name="subresource" value="{$sr}"/>
				<exist:add-parameter name="subsubresource" value="{$subsubresource}"/>
				<exist:add-parameter name="format" value="{$format}"/>
			</exist:forward>
		</exist:dispatch>
	else if ($n-tokens <= 2)
	then
		<exist:dispatch>
			{app:pass-credentials-xq()}
			<exist:forward url="{$exist:controller}/original.xql">
				<exist:add-parameter name="share-type" value="{$share-type}"/>
				<exist:add-parameter name="owner" value="{$owner}"/>
			</exist:forward>
		</exist:dispatch>
	else if ($n-tokens = (3, 4, 5) or $sr = "nav")
	then (
		if ($paths:debug)
		then
			util:log-system-out(('controller: subresource for ', $exist:path,'= ', $sr))
		else (),
		if ($sr = $local:subresource/s)
		then 
			(: subresource handled in its own query :)
			<exist:dispatch>
				{app:pass-credentials-xq()}
				<exist:forward url="{$local:subresource/s[.=$sr]/@xquery}">
					<exist:add-parameter name="purpose" value="{$purpose}"/>
					<exist:add-parameter name="share-type" value="{$share-type}"/>
					<exist:add-parameter name="owner" value="{$owner}"/>
					<exist:add-parameter name="resource" value="{$resource}"/>
					<exist:add-parameter name="subresource" value="{$sr}"/>
					<exist:add-parameter name="subsubresource" value="{$subsubresource}"/>
					<exist:add-parameter name="format" value="{$format}"/>
				</exist:forward>
			</exist:dispatch>
		else
			(: resource with or w/no subresource :)
			<exist:dispatch>
				{app:pass-credentials-xq()}
				<exist:forward url="{$exist:controller}/resource.xql">
					<exist:add-parameter name="share-type" value="{$share-type}"/>
					<exist:add-parameter name="owner" value="{$owner}"/>
					<exist:add-parameter name="resource" value="{$resource}"/>
					<exist:add-parameter name="subresource" value="{$sr}"/>
					<exist:add-parameter name="subsubresource" value="{$subsubresource}"/>
					<exist:add-parameter name="format" value="{$format}"/>
				</exist:forward>
			</exist:dispatch>
		)
	else
		(: path is too long :)
		api:error(404, 'Not found')
