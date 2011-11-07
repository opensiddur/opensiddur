xquery version "1.0";
(: Testing module
 : Original author: Wolfgang Meier (eXist db)
 : 
 : Modified by Efraim Feinstein, 2011
 : 
 : Licensed under the GNU Lesser General Public License, version 2.1 or later
 :)
(:
 : 
 : Modifications from the original version:
 : * namespace change to avoid conflict with the original version
 :
 : * allow setup to be optional (not all tests require a setup)
 : ** allow setup to include code
 : 
 : * add a top-level TestSuite element to contain multiple TestSet elements
 :  and a function t:run-testSuite()
 : ** add setup and teardown for the entire suite
 : 
 : * add a <TestClass xml:id="..."> element for tests with no code that can be 
 :  included into other TestSets with <class href=""/>
 : 
 : * allow each test to include any of:
 : ** at most 1 error element
 : ** 1 or _more_ xpath elements to perform tests on the  (the xpath
 : element is a useful undocumented feature!); I changed the context of the
 : XPath evaluation so it always explicitly occurs in the context of the
 : output.
 : ** 1 or _more_ expected elements
 : ** combinations of xpath and expected elements, so multiple assertions
 : can be tested on the same code.
 : 
 : * error, xpath, and expected elements can have an @desc attribute to
 : document the expected result in natural language
 : 
 : * expected elements can have an @xpath attribute to limit the
 : expectation to a subset of the returned value
 : 
 : * when literal XML is given as an output (through expected elements):
 : ** Attribute and element content can be specified to exist with any
 : value by replacing the expectation value with an elipsis ... (I borrowed
 : this idea from XSpec)
 : ** Attributes in the xml namespace can be aliased to
 : http://www.w3.org/1998/namespace/alias . That would allow multiple
 : expectations that use the same @xml:id attribute to coexist in the same
 : xml file.
 : 
 : * add a namespace element to declare namespaces used in tests (the
 : current code uses in-scope-prefixes(), which sometimes behaves in
 : "unexpected" ways when XML is stored in the database: the prefixes are
 : only in-scope at the point they're used)
 : 
 : * add an @as parameter to the variable element to specify the variable's
 : type (I don't know if this is ever necessary for XQuery)
 : 
 : * Many improvements to the html visualization in t:format-testResult()
 :  
 :)
module namespace t="http://exist-db.org/xquery/testing/modified";

import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace xdiff="http://exist-db.org/xquery/xmldiff"
at "java:org.exist.xquery.modules.xmldiff.XmlDiffModule";

declare function t:setup-action($action) {
    typeswitch ($action)
        case element(code) return
            t:setup-run($action)
        case element(create-collection) return
            xdb:create-collection($action/@parent, $action/@name)
        case element(store) return
						t:store($action)
				case element(store-files) return
            t:store-files($action)
        case element(remove-collection) return
            xdb:remove($action/@collection)
        case element(remove-document) return
            xdb:remove($action/@collection, $action/@name)
        default return
            ()
};

declare function t:setup-run($action as element(code)) {
    util:eval(concat(t:init-prolog($action), $action/string()))
};

(: return whether a test should run :)
declare function t:if($condition as element(if)*) as xs:boolean {
  empty($condition) or (
  every $cond in $condition
    satisfies (
      not(normalize-space($cond)) or 
        boolean(util:eval(concat(t:init-prolog($cond), $cond/string())))
    )
  )
};

declare function t:store($action as element(store)) {
    let $type := if ($action/@type) then $action/@type/string() else "application/xml"
    let $data :=
		if ($action/*) then
			$action/*[1]
		else
			$action/string()
	return
        xdb:store($action/@collection, $action/@name, $data, $type)
};

declare function t:store-files($action as element(store-files)) {
    let $type := if ($action/@type) then $action/@type/string() else "application/xml"
    return
        xdb:store-files-from-pattern($action/@collection, $action/@dir, $action/@pattern, $type)
};

declare function t:setup($setup as element(setup)?) {
    for $action in $setup/*
    return
        t:setup-action($action)
};

declare function t:tearDown($tearDown as element(tearDown)?) {
    for $action in $tearDown/*
    return
        t:setup-action($action)
};

declare function t:declare-variable($var as element(variable)) as item()? {
    let $children := $var/*
    return
        if (empty($children)) then
            string-join($var/node(), '')
        else
            util:serialize($children, ())
};

declare function t:init-prolog($test as element()) {
	let $imports := $test/ancestor::*/imports
	let $vars :=
	    string-join(
	    		(
	    		for $ns in $test/ancestor::*/namespace
          return
          		concat("declare namespace ", $ns/@prefix, " = '", string($ns), "';"),
        	for $var in $test/ancestor::*/variable
        	return
        	    string-join(("declare variable $", $var/@name, 
        	    	if ($var/@as)
        	    	then (" as ", $var/@as)
        	    	else (),
        	    	" := ", t:declare-variable($var), ";"), '')
         	), "&#x0a;"
        )
	return
		string-join(($imports, $vars, $test/ancestor::*/functions), '')
};

declare function t:test($result as item()*) {
    if ($result instance of xs:boolean) then
        $result
    else
        exists($result)
};

(:~ run a single test and record the results of its assertions
 : @param $test Test to run
 : @param $count A number to assign to the test
 :)
declare function t:run-test($test as element(test), $count as xs:integer) {
	let $context := t:init-prolog($test)
	let $null := 
	   if ($test/@trace eq 'yes') then 
	       (system:clear-trace(), system:enable-tracing(true(), false()))
     else ()
    let $highlight-option := concat("highlight-matches=",
          if ($test/expected//@*[matches(., '^(\|{3}).*\1$')] and $test/expected//exist:match) then "both"
          else if ($test/expected//@*[matches(., '^(\|{3}).*\1$')]) then "attributes"
          else if ($test/expected//exist:match) then "elements"
          else "none"        
          )
    let $serialize-options := 
      let $decls := ($test/../*[name() ne 'test']|$test/code)[matches(., 'declare[\- ]option(\((&#34;|&#39;)|\s+)exist:serialize(\2,)?\s+(&#34;|&#39;).*?\4[;)]')]
      let $ops1 := $decls/replace(., "declare[\- ]option(\((&#34;|&#39;)|\s+)exist:serialize(\2,)?\s+(&#34;|&#39;)(.*?)\4[;)]", "_|$5_")
      let $ops2 :=
        for $a in $ops1
        for $b in tokenize($a, '_')[starts-with(., '|')]
        return tokenize(substring-after($b, '|'), '\s+')
      return if (count($ops2[matches(., 'highlight-matches')]))
        then string-join($ops2, ' ')
        else string-join(($ops2, $highlight-option), ' ')      
    let $queryOutput :=
		util:catch("*",
			util:eval(concat($context, $test/code/string())),
			<error>Compilation error: {$util:exception-message}</error>
		)
	let $output := if ($test/@trace eq 'yes') then system:trace() else $queryOutput
  let $expanded :=
        if ($output instance of element(error)) then
            $output
        else if ($test/@serialize) then
            let $options := $test/@serialize
            let $serialized :=
                util:catch("*",
                    for $x in $output
                    return
                        util:serialize($x, $options),
                    <error>Serialization error: {$util:exception-message}</error>
                )
            return
                if ($serialized instance of element(error)) then
                    $serialized
                else
                    normalize-space(string-join($serialized, ' '))
				else if ($output instance of node()) then
        		util:expand($output, $serialize-options)        	
				else
						$output
    let $expected :=
        if ($test/@output eq 'text') then
            data($test/expected)
        else $test/expected
    let $OK := 
    	for $assert in $test/(error|xpath|expected|t:expand-class(class))
    	return (
        if ($assert instance of element(error)) then
        		let $pass := $expanded instance of element(error) and contains($expanded, $assert)
        		return 
        			<error
        				pass="{$pass}">
        				{
        				$assert/@desc,
        				if (not($pass))
        				then $assert
        				else ()
        				}
        			</error>
        else if ($assert instance of element(xpath)) then
        		let $pass := t:test(t:xpath($output, $assert))
        		return
        			<xpath pass="{$pass}">
        				{$assert/@desc, if (not($pass)) then $assert else ()}
        			</xpath>
        else if ($test/@output eq 'text') then 
            let $asString :=
                if ($test/@serialize) then
                    $expanded
                else
                    normalize-space(string-join(for $x in $output return string($x),' '))
            let $pass := $asString eq normalize-space($expected)
            return 
            	<expected pass="{$pass}">{
            		$assert/@desc,
            		if (not($pass))
            		then 
            			$expected
            		else ()
            	}</expected>
        else 
            let $xn := t:normalize($expanded)
            let $en := t:normalize($assert/node())
            let $xp :=
            	if ($assert/@xpath)	then
            		t:xpath($xn, $assert/@xpath) 
            	else $xn
            let $pass := t:deep-equal-wildcard($xp, $en)
            return
        	  	<expected pass="{$pass}">
        	  			{
            			$assert/@desc, $assert/@xpath,
            			if (not($pass))
            			then $en
            			else ()
            			}
        	   	</expected>
    )
    let $all-OK := empty($OK[@pass='false'])
    return
        <test n="{$count}" pass="{$all-OK}">
        {
        		attribute desc { $test/task },
        		$OK, 
            if (not($all-OK)) then             		
                <result>{$expanded}</result>
            else 
                ()
                
        }
        </test>
};

(: expand abstract test class references :)
declare function t:expand-class(
  $classes as element(class)*
  ) as element()* {
  for $class in $classes
  let $base := substring-before($class/@href, '#')
  let $fragment := substring-after($class/@href, '#')
  let $doc := 
    if ($base)
    then doc(resolve-uri($base, base-uri($class)))
    else root($class)
  let $testClass as element(TestClass) := $doc/id($fragment)
  return
    $testClass/(error|xpath|expected|t:expand-class(class))
};

declare function t:normalize($nodes as node()*) {
	for $node in $nodes return t:normalize-node($node)
};

declare function t:normalize-node($node as node()) {
	typeswitch ($node)
		case element() return
			element { node-name($node) } {
				$node/@*, for $child in $node/node() return t:normalize-node($child)
			}
		case text() return
			let $norm := normalize-space($node)
			return
				if (string-length($norm) eq 0) then () else $node
		default return
			$node
};

declare function t:xpath($output as item()*, $xpath as node()) {
	let $xpath-element := if ($xpath instance of element()) then $xpath else $xpath/..
	return (
    for $prefix in in-scope-prefixes($xpath-element)
    let $nsuri := namespace-uri-for-prefix($prefix, $xpath-element)
    return ( 
        if ($prefix != 'xml') then
            util:declare-namespace($prefix, $nsuri)
        else ()
    ),
    for $nselm in $xpath-element/ancestor::*/namespace
    let $prefix := string($nselm/@prefix)
    let $nsuri := string($nselm)
    return (
    	util:declare-namespace($prefix, $nsuri)
    ),
    let $imports := string-join($xpath/ancestor::*/imports, " ")
    let $expr := $xpath/string()
    return
    	util:eval(concat($imports, " $output/(", $expr, ")"))
    (: ^ EDF: I don't understand why this code wasn't the code above
        if (matches($expr, "^\s*/")) then
            util:eval(concat("$output", $expr))
        else
            util:eval($expr)
    :)
 	)
};

(:~ Front-end to run a test suite :)
declare function t:run-testSuite($suite as element(TestSuite)) as element() {
	let $copy := util:expand($suite)
	let $as-user := ($copy/asUser/string(), "guest")[1]
	let $password := ($copy/password/string(), "guest")[1]
	let $if := t:if($copy/if) 
	where $if 
	return
		<TestSuite>
			{$copy/suiteName}
			{$copy/description}
			{
			  system:as-user($as-user, $password, 
  			  let $null := t:setup($copy/setup)
          let $result :=
    				for $set in $suite/TestSet[empty(@ignore) or @ignore = "no"]
  	  			return
  		  			t:run-testSet($set)
          let $null := t:tearDown($copy/tearDown)
          return $result
        )
			}
		</TestSuite>
};

(:~ Front-end to run a single test set :)
declare function t:run-testSet($set as element(TestSet)) {
    let $copy := 
    	if ($set/parent::TestSuite)
    	then $set
    	else util:expand($set)
    let $as-user := ($copy/asUser/string(), "guest")[1]
    let $password := ($copy/password/string(), "guest")[1]
    let $if := t:if($copy/if)
    where $if
    return 
      system:as-user($as-user, $password,
        util:expand(
           <TestSet>
           {$copy/testName}
           {$copy/description}
           {
               for $test at $p in $copy/test[empty(@ignore) or @ignore = "no"][t:if(if)]
               let $null := t:setup($copy/setup)
               let $result :=  t:run-test($test, $p)
               let $null := t:tearDown($copy/tearDown)
               return $result 
               
           }
           </TestSet>
        )
      )
};

declare function local:pass-string($pass as xs:boolean) {
	if ($pass)
	then 'PASS'
	else 'FAIL'
};

(:~ Format a test result as HTML :)
declare function t:format-testResult($result as element()) {
		(: This should be namespaced, but it isn't.
		 : Using xmlns is impractical because the referenced elements would be html ns
		 : and we can't declare a blank namespace prefix.
		 : Using a prefix is impractical because browsers don't like it.
		 :)
    <html>
    		<head>
    			<title>{$result/(testName|suiteName)/node()}</title>
    			<style type="text/css">
    			.PASS {{
    				background-color:green;
    			}}
    			
    			.FAIL {{
    				background-color:red;
    			}}
    			</style>
    		</head>
        <body>
          <h1>{$result/(testName|suiteName)/node()}</h1>
          <p>{$result/description/p}</p>
          <h2>Summary</h2>
          <table border="1">
          	<tr>
          		<th>Tests</th>
          		<th>Passed</th>
          		<th>Failed</th>
          	</tr>
          	<tr>
          		<td>{count($result//test/*[@pass])}</td>
          		<td>{
          			let $ct := count($result//test/*[@pass='true'])
          			return (
          				if ($ct)
          				then
          					attribute class {'PASS'}
          				else (),
          				$ct
          			)
          		}</td>
          		<td>{
          			let $ct := count($result//test/*[@pass='false'])
          			return (
          				if ($ct)
          				then
          					attribute class {'FAIL'}
          				else (),
          				$ct
          			)
          		}</td>
          	</tr>
          </table>
          <h2>Details</h2>
          <table border="1">
          {
          for $set in $result//TestSet
          return (
          	<tr>
          		<th>{
          			$set/testName/node()
          		}</th>
          		<th colspan="4">{
          			$set/description/p
          		}</th>
          	</tr>,
          	for $test in $set//test
          	let $pass := local:pass-string(xs:boolean($test/@pass))
          	let $subtests := $test/(* except (code, task, result))
          	let $n-subtests := count($subtests)
          	return (
          		(:util:log-system-out(('subtests(', $n-subtests, ') = ', $subtests)),:)
          		for $subtest at $pos in $subtests
            	let $subpass := local:pass-string(xs:boolean($subtest/@pass))
            	return 
                <tr>{
                	if ($pos = 1)
                	then (
                    <td rowspan="{$n-subtests}">{string(($test/@desc, $test/@n)[1])}</td>,
                    <td rowspan="{$n-subtests}" class="{$pass}">{$pass}</td>
                  )
                  else (),
            			<td>{string($subtest/@desc)}</td>,
            			<td class="{$subpass}">{$subpass}</td>,
            			if ($pos = 1)
            			then 
            				<td rowspan="{$n-subtests}">{
            					if ($test/@pass='false')
            					then
            						<pre>{
            							util:serialize($test/result/node(), "indent='yes'")
            						}</pre>
            					else ()
            				}</td>
            			else ()
                }</tr>
          	)
					)

          }
          </table>
        </body>
     </html>
};

(:~ determine if two nodes are deep-equal, allowing for the string ... to be a wildcard
 : and the namespace http://www.w3.org/1998/xml/namespace/alias to be equivalent to the
 : xml namespace
 : @param $node1 The original node
 : @param $node2 The expectation node, which may include aliased namespaces and wildcards
 :)
declare function t:deep-equal-wildcard(
	$node1 as node()*,
	$node2 as node()*
	) as xs:boolean {
	let $counts := count($node1) = count($node2)
	let $subordinates := 
		(every $result in 
			(
			for $n at $pos in $node1
			return
				typeswitch ($n)
				case document-node() return t:deep-docnode($n, $node2[$pos])
				case comment() return t:deep-comment($n, $node2[$pos])
				case text() return t:deep-text($n, $node2[$pos])
				case attribute() return t:deep-attribute($n, $node2)	
				case element() return t:deep-element($n, $node2[$pos])
				default return false()
			)
			satisfies $result
		)
	return (
		(:util:log-system-out(('d-e-w for node1=', $node1, ' node2 = ', $node2, ' result = ', $counts and $subordinates)),:)
		$counts and $subordinates
	)
};

declare function t:deep-docnode(
	$node1 as document-node(),
	$node2 as node()
	) as xs:boolean {
	($node2 instance of document-node()) and
	t:deep-equal-wildcard($node1/node(), $node2/node())
};

declare function t:deep-comment(
	$node1 as comment(),
	$node2 as node()
	) as xs:boolean {
	($node2 instance of comment()) and (
		string($node1) = string($node2)
		or string($node2) = '...'
	)
};

declare function t:deep-text(
	$node1 as text(),
	$node2 as node()
	) as xs:boolean {
	($node2 instance of text()) and ( 
		string($node1) = string($node2)
		or string($node2) = '...'
	)
};

declare function t:deep-attribute(
	$node1 as attribute(),
	$node2 as attribute()*
	) as xs:boolean {
	let $equivalent :=
		$node2[
		(
		namespace-uri(.) = namespace-uri($node1)
		or
		namespace-uri(.) = 'http://www.w3.org/1998/xml/namespace/alias' and 
			namespace-uri($node1) = 'http://www.w3.org/1998/xml/namespace'  
		)
		and local-name(.) = local-name($node1)
		]
	return exists($equivalent) and (
		string($equivalent) = (string($node1), '...')
	)
};

declare function t:deep-element(
	$node1 as element(),
	$node2 as node()
	) as xs:boolean {
	($node2 instance of element()) and
	namespace-uri($node1) = namespace-uri($node2) and
	local-name($node1) = local-name($node2) and
	t:deep-equal-wildcard($node1/@*, $node2/@*) and
	(
		(count($node2/node()) = 1 and string($node2) = '...') or
		t:deep-equal-wildcard($node1/node(), $node2/node())
	)
};
