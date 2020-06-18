xquery version "3.1";
(: Testing module
 : Original author: Wolfgang Meier (eXist db)
 : 
 : Modified by Efraim Feinstein, 2011-2012,2018
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
 : ** each TestSuite or TestSet can have asUser/password elements, indicating
 :  the priviliges that the tests should run under. Higher depth
 :  asUser overrides lower depth, and blank asUser resets to unauthenticated 
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
 : * run multiple test suites using t:run-testSuites(), format results using t:format-testResults()
 :
 : * XPath tests and internal functions can be run using XQuery 3.0  
 :
 : * Many improvements to the html visualization in t:format-testResult()
 :
 : * Testing for XSLT in addition to XQuery:
 : ** XSLT tests have xslt elements instead of code, which also accept @href
 : ** node context can be set using the context element, which also accepts @href
 : ** stylesheets and parameters can be included using xsl:include and xsl:param
 : ** stylesheet-global parameters can be sent using parameters/param[@name,@value] elements
 : *** parameters with the same name are passed at the greatest depth
 :  
 :)
module namespace t="http://exist-db.org/xquery/testing/modified";

import module namespace xdb="http://exist-db.org/xquery/xmldb";

declare namespace xsl="https://www.w3.org/1999/XSL/Transform";

declare function local:error(
  $activity as xs:string, 
  $line as xs:string?, 
  $column as xs:string?, 
  $code as xs:string?, 
  $description as xs:string*, 
  $value as xs:string*, 
  $error-data as item()*
  ) as element(error) {
  <error 
    pass = "false"
    during="{$activity}"
    line-number="{$line}"
    column-number="{$column}"
    code="{$code}"
    >
    <value>{$value}</value>
    <description>{$description}</description>
    {$error-data}
  </error>
};

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
            if (xdb:collection-available($action/@collection))
            then
              xdb:remove($action/@collection)
            else ()
        case element(remove-document) return
          if (doc-available(concat($action/@collection, "/", $action/@name)))
          then xdb:remove($action/@collection, $action/@name)
          else ()
        case element(copy) return
          t:copy($action)
        default return
            ()
};

declare function t:setup-run($action as element(code)) {
    util:eval(concat(t:init-prolog($action), $action/string()))
};

(: return whether a test should run 
 : false() = run, true() = do not run
 : element(error) = do not run, the condition has an error
 :)
declare function t:if(
  $condition as element(if)*
  ) as item() {
  try {
    not(
    empty($condition) or (
    every $cond in $condition
      satisfies (
        not(normalize-space($cond)) or 
        boolean(util:eval(concat(t:init-prolog($cond), $cond/string())))
      )
    )
    )
  }
  catch * {
    local:error("condition", $err:line-number, $err:column-number,
      $err:code, $err:description, $err:value,
      $condition)
  }
};

declare function t:store($action as element(store)) {
  let $type := 
    if ($action/@type) 
    then $action/@type/string() 
    else "application/xml"
  let $data :=
    if ($action/*) 
    then $action/*[1]
    else $action/string() 
	return
	  xdb:store($action/@collection, $action/@name, $data, $type)
};

declare function t:store-files($action as element(store-files)) {
    let $type := if ($action/@type) then $action/@type/string() else "application/xml"
    return
        xdb:store-files-from-pattern($action/@collection, $action/@dir, $action/@pattern, $type)
};

declare function t:setup(
  $setup as element(setup)?
  ) as empty-sequence() {
  for $action in $setup/*
  let $null := t:setup-action($action)
  return ()
};

declare function t:tearDown(
  $tearDown as element(tearDown)?
  ) as empty-sequence() {
  for $action in $tearDown/*
  let $null := t:setup-action($action)
  return ()
};

declare function t:copy(
  $copy as element(copy)
  ) as empty-sequence() {
  if ($copy/@destination-name)
  then
    let $uri := concat($copy/@source, "/", $copy/@name)
    let $null :=
      xmldb:store($copy/@destination, $copy/@destination-name,
        try { doc($uri) }
        catch err:FODC0005 { util:binary-doc($uri) }
        )
    return ()
  else
    xmldb:copy-resource($copy/@source, $copy/@name, $copy/@destination, $copy/@name, true())
};

declare function t:declare-variable($var as element(variable)) as item()? {
    let $children := $var/*
    return
        if (empty($children)) then
            string-join($var/node(), '')
        else
            serialize($children, ())
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
		string-join(("xquery version '3.0';&#x0a;", $imports, $vars, $test/ancestor::*/functions), '')
};

declare function t:test($result as item()*) {
  typeswitch($result)
  case xs:boolean return $result
  case xs:boolean+ return $result=true() (: any? :)
  default return exists($result)
};

declare function t:run-test(
  $test as element(test),
  $count as xs:integer
  ) {
  if (exists($test/code))
  then local:run-xquery-test($test, $count)
  else if (exists($test/(xslt|context)))
  then local:run-xslt-test($test, $count)
  else ( (: skip tests that dont have any code to run :) )
};

declare function local:evaluate-assertions(
  $test as element(test),
  $output as item()*,
  $count as xs:integer
  ) as element(test) {
  let $highlight-option := 
    concat("highlight-matches=",
      if ($test/expected//@*[matches(., '^(\|{3}).*\1$')] 
        and $test/expected//exist:match) 
      then "both"
      else if ($test/expected//@*[matches(., '^(\|{3}).*\1$')]) 
      then "attributes"
      else if ($test/expected//exist:match) 
      then "elements"
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
  let $expanded :=
    if ($output instance of element(error)) 
    then $output
    else if ($test/@serialize) 
    then
    (: TODO: this will not work anymore because the serialization options have changed. :)
      let $options := $test/@serialize
      let $serialized :=
        try {
          for $x in $output
          return
            serialize($x, $options)
        }
        catch * {
          local:error("serialization", $err:line-number, 
            $err:column-number, $err:code, $err:description, $err:value, ())
        }
      return
        if ($serialized instance of element(error)) 
        then $serialized
        else
          normalize-space(string-join($serialized, ' '))
    else if ($output instance of node()) 
    then
      let $exp := util:expand($output, $serialize-options)
      return
        (: util:expand() kills document nodes :)
        typeswitch($output)
        case document-node() 
        return document { $exp }
        default
        return $exp
    else $output
  let $OK := 
    for $assert in $test/(error|xpath|expected|t:expand-class(class))
    return 
      try {
        if ($assert instance of element(error)) 
        then
          let $pass := 
            $expanded instance of element(error) 
            and 
              ( (: the assertion is that the err:* parameters
                 : in the assertion match those in the returned
                 : error :)
                every $err-attribute in $assert/(@* except @desc) 
                satisfies $expanded/@*[name()=$err-attribute/name()]=$err-attribute
              )
          return 
            <error pass="{$pass}">{
              $assert/@desc,
              if (not($pass))
              then $assert
              else ()
            }</error>
        else if ($assert instance of element(xpath)) 
        then
          let $pass := t:test(t:xpath($output, $assert))
          return
            <xpath pass="{$pass}">{
              $assert/@desc, 
              if (not($pass)) 
              then $assert 
              else ()
            }</xpath>
        else
          (: $assert is expected :)
          let $expected :=
            if ($assert/@href)
            then 
              if ($test/@output eq "text")
              then util:binary-doc(resolve-uri($assert/@href, base-uri($assert)))
              else 
                let $d := doc(resolve-uri($assert/@href, base-uri($assert)))
                return
                  (: transform:transform() returns element()|node(), not document-node() :)
                  if ($test/(xslt|context))
                  then $d/*
                  else $d
            else 
              if ($test/@output eq "text") 
              then data($assert)
              else $assert/node()
          return
            if ($test/@output eq 'text') then 
              let $asString :=
                if ($test/@serialize) 
                then $expanded
                else
                  normalize-space(
                    string-join(
                      for $x in $output 
                      return string($x),
                      ' '
                    )
                  )
              let $pass := $asString eq normalize-space($expected)
              return 
                <expected pass="{$pass}">{
                  $assert/@desc,
                  if (not($pass))
                  then $expected
                  else ()
                }</expected>
            else
              let $xn := t:normalize($expanded)
              let $en := t:normalize($expected)
              let $xp :=
                if ($assert/@xpath) 
                then t:xpath($xn, $assert/@xpath) 
                else $xn
              let $pass := t:deep-equal-wildcard($xp, $en)
              return
                <expected pass="{$pass}">{
                  $assert/(@desc, @xpath),
                  if (not($pass))
                  then $en
                  else ()
                }</expected>
    }
    catch * {
      element { name($assert) }{
        attribute pass { false() },
        $assert/(@desc, @xpath),
        local:error("assertion", 
          $err:line-number, $err:column-number, 
          $err:code, $err:description, $err:value, 
          $assert)
      }
    }
  let $all-OK := empty($OK[@pass='false'])
  return
    <test n="{$count}" pass="{$all-OK}">{
      attribute desc { $test/task },
      $OK, 
      if (not($all-OK)) 
      then                
        <result>{
        if ($OK/error/@during = "assertion")
        then $OK/error[@during="assertion"]
        else $expanded
        }</result>
      else ()
    }</test>
};

(:~ run a single test and record the results of its assertions
 : @param $test Test to run
 : @param $count A number to assign to the test
 :)
declare function local:run-xquery-test(
  $test as element(test), 
  $count as xs:integer
  ) {
	let $context := t:init-prolog($test)
	let $null := 
	   if ($test/@trace eq 'yes') then 
	       (system:clear-trace(), system:enable-tracing(true(), false()))
     else ()
  let $full-code := concat($context, $test/code/string())
  let $queryOutput :=
	  trace(
  	  try {
  	    util:eval($full-code)
  	  }
  	  catch * {
  	    local:error("evaluation", 
  	      $err:line-number, $err:column-number, 
  	      $err:code, $err:description, $err:value,
  	      $full-code)
  	  }
  	, ". . . test run . . .")
	let $output := 
	  if ($test/@trace eq 'yes') 
	  then system:trace() 
	  else $queryOutput
  return 
    local:evaluate-assertions($test, $output, $count)
};

declare function local:run-xslt-test(
  $test as element(test),
  $count as xs:integer
  ) as element(test) {
  let $output := 
    try {
      transform:transform(
        let $context := 
          $test/ancestor-or-self::*[context][1]/context
        return
          if ($context/@href)
          then doc(resolve-uri($context/@href,base-uri($context)))
          else $context/node(), 
        if ($test/xslt/@href)
        then doc(resolve-uri($test/xslt/@href, base-uri($test/xslt)))
        else 
          <xsl:stylesheet version="2.0">
            {
              $test/ancestor-or-self::*/xsl:*,
              $test/xslt/node()
            }
          </xsl:stylesheet>,
        (: the parameters are not passed without util:expand().
         : I don't know why. eXist 2.0.x r16344
         :)
        util:expand(
          <parameters>
            <param name="exist:stop-on-error" value="yes"/>
            {
              for $param in $test/ancestor-or-self::*/parameters/param
              let $n := $param/@name
              group by $n
              return
                ($param/.)[last()]
            }
          </parameters>
        )
      )
    }
    catch * {
      local:error("transform", 
        $err:line-number, $err:column-number, 
        $err:code, $err:description, $err:value, 
        $test)
    }
  return
    local:evaluate-assertions($test, $output, $count)
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
	let $xpath-element := 
	  if ($xpath instance of element()) 
	  then $xpath 
	  else $xpath/..
  let $prolog := t:init-prolog($xpath-element)
  let $expr := $xpath/string()
  let $test-element := $xpath/ancestor::test
  let $code :=
   concat($prolog, 
      if ($test-element/@output=("text", "mixed"))
      then "("
      else " $output/(", 
      $expr, ")")
  return
    util:eval($code)
};

(:~ run a number of test suites and return a single element
 : with all the results 
 : @param $suites List of test suites, as paths, document-node()s or element(TestSuite)  
 :)
declare function t:run-testSuite(
  $suites as item()+,
  $run-user as xs:string?,
  $run-password as xs:string?
  ) as element() {
  <TestSuites>{
    for $suite in $suites
    return
      t:run-testSuite(
        typeswitch($suite)
        case xs:anyAtomicType
        return doc($suite)/TestSuite
        case document-node()
        return $suite/TestSuite
        default return $suite,
        $run-user,
        $run-password
      )
  }</TestSuites>
};

(:~ Front-end to run a test suite :)
declare function t:run-testSuite(
  $suite as element(TestSuite),
  $run-user as xs:string?,
  $run-password as xs:string?
  ) as element() {
	let $copy := util:expand($suite)
	let $if := t:if($copy/if)
	return
		<TestSuite>
			{$copy/suiteName}
			{$copy/description/p}
			{
			  for $set in $suite/TestSet
			  return
			    if (not($if) and $set/(empty(@ignore) or @ignore = "no"))
			    then t:run-testSet($set, $run-user, $run-password)
			    else if ($if instance of element(error))
			    then t:fail-testSet($set, $if)
			    else t:ignore-testSet($set)
			}
		</TestSuite>
};

declare function t:ignore-testSet(
  $set as element(TestSet)
  ) as element(TestSet) {
  <TestSet pass="ignore">{
    $set/testName,
    $set/description/p,
    for $test at $p in $set/test
    return t:ignore-test($test, $p)
  }</TestSet>
};

declare function t:fail-testSet(
  $set as element(TestSet),
  $error as element(error)+
  ) as element(TestSet) {
  <TestSet pass="false">{
    $set/testName,
    $set/description/p,
    for $test at $p in $set/test
    return t:fail-test($test, $p, $error)
  }</TestSet>
};

declare function t:fail-test(
  $test as element(test),
  $p as xs:integer,
  $error as element(error)+
  ) as element(test) {
  <test n="{$p}" pass="false">{
    attribute desc {$test/task},
    for $condition in $test/(expected|xpath|error|t:expand-class(class))
    return 
      element { name($condition) }{
        $condition/@desc,
        attribute pass { "false" },
        $condition
      },
    <result>{$error}</result>
  }</test>
};


declare function t:run-testSuite(
  $suite as element(TestSuite)
  ) as element() {
  t:run-testSuite($suite, (), ())
};

declare function local:run-tests-helper(
  $copy as element(TestSet),
  $suite as element(TestSuite),
  $run-user as xs:string?,
  $run-password as xs:string?
  ) as element(TestSet) {
  let $suite-user := ($suite/asUser/string(), $run-user)[1]
  let $suite-password := ($suite/password/string(), $run-password)[1]
  let $test-user := ($copy/asUser/string(), $suite-user, $run-user)[1]
  let $test-password := ($copy/password/string(), $suite-password, $run-password)[1]
  return
    util:expand( 
      <TestSet>{
        trace($copy/testName, "Running test set: "),
        $copy/description/p,
        for $test at $p in $copy/test
        let $if := t:if($test/if)
        return 
          if ($test/((empty(@ignore) or @ignore = "no") and not($if)))
          then
            let $setup as element(error)* := (   
              trace(
                try {
                  if ($suite-user)
                  then
                    system:as-user($suite-user, $suite-password, t:setup($suite/setup))
                  else t:setup($suite/setup)
                }
                catch * {
                  local:error("setup", 
                    $err:line-number, $err:column-number, 
                    $err:code, $err:description, $err:value,
                    $suite/setup)
                }
              ,"> > > suite setup > > >"),
              trace(
                try {
                  if ($test-user)
                  then 
                    system:as-user($test-user, $test-password, t:setup($copy/setup))
                  else t:setup($copy/setup)
                }
                catch * {
                  local:error("setup", 
                    $err:line-number, $err:column-number, 
                    $err:code, $err:description, $err:value, 
                    $copy/setup)
                },
              "> > > test set setup > > >"
              )
            )
            let $result :=
              if ($setup instance of element(error))
              then ( (: setup failed, do nothing, but do try to tear down :) )
              else 
                  if ($test-user)
                  then system:as-user($test-user, $test-password, t:run-test($test, $p))
                  else t:run-test($test, $p)
            let $teardown as element(error)* := (
              trace(
                try {
                  if ($test-user)
                  then 
                    system:as-user($test-user, $test-password, t:tearDown($copy/tearDown))
                  else t:tearDown($copy/tearDown)
                }
                catch * {
                  local:error("tearDown", 
                    $err:line-number, $err:column-number, 
                    $err:code, $err:description, $err:value, 
                    $copy/tearDown)
                }
              , "< < < test set tearDown < < <"
              ),
              trace(
                try {
                  if ($suite-user)
                  then
                    system:as-user($suite-user, $suite-password, t:tearDown($suite/tearDown))
                  else t:tearDown($suite/tearDown)
                }
                catch * {
                  local:error("tearDown", 
                    $err:line-number, $err:column-number, 
                    $err:code, $err:description, $err:value, 
                    $suite/tearDown)
                }
              ,"< < < suite tearDown < < <")            
            )
            return
              if (exists($setup))
              then t:fail-test($test,$p,$setup)
              else if (exists($teardown))
              then t:fail-test($test,$p,$teardown)
              else $result
          else if ($if instance of element(error))
          then t:fail-test($test, $p, $if)
          else t:ignore-test($test, $p) 
      }</TestSet>
    )
};

(:~ Front-end to run a single test set :)
declare function t:run-testSet(
  $set as element(TestSet),
  $run-user as xs:string?,
  $run-password as xs:string?
  ) as element(TestSet)? {
    let $suite := $set/parent::TestSuite
    let $copy := 
    	if ($suite)
    	then $set
    	else util:expand($set)
    let $if := t:if($copy/if)
    return
      if (not($if))
      then local:run-tests-helper($copy, $suite, $run-user, $run-password)
      else if ($if instance of element(error))
      then t:fail-testSet($copy, $if)
      else t:ignore-testSet($copy)
};

declare function t:ignore-test(
  $test as element(test),
  $count as xs:integer
  ) as element(test) {
  <test n="{$count}" pass="ignore">{
    attribute desc {$test/task},
    for $condition in $test/(expected|xpath|error|t:expand-class(class))
    return 
      element { name($condition) }{
        attribute pass { "ignore" },
        $condition/@desc
      }
  }</test>
};

declare function t:run-testSet(
  $set as element(TestSet)
  ) {
  t:run-testSet($set, (), ())
};

declare function local:pass-string(
  $pass as xs:string
  ) as xs:string {
	switch ($pass)
	case "true"
	return "PASS"
	case "false"
	return "FAIL"
	default
	return "IGNORE"
};

declare function local:result-summary-table(
  $result as element(TestSet)*
  ) as element(table) {
  <table border="1" class="summary">
    <tr>
      <th>Tests</th>
      <th>Passed</th>
      <th>Failed</th>
      <th>Ignored</th>
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
      <td>{
        let $ct := count($result//test/*[@pass='ignore'])
        return (
          if ($ct)
          then
            attribute class {'IGNORE'}
          else (),
            $ct
        )
      }</td>
    </tr>
  </table>
};

declare function local:result-summaries(
  $result as element()
  ) {
  <h1>Summary</h1>,
  if ($result instance of element(TestSuites))
  then ( 
    <h2>All</h2>,
    local:result-summary-table($result//TestSet)
  )
  else (),
  for $testSuite in $result/(self::TestSuite|TestSuite|self::TestSet)
  return (
    element { 
      if ($result instance of element(TestSuites))
      then "h3"
      else "h2"
    }{
      if ($testSuite instance of element(TestSuite))
      then
        <a href="#{encode-for-uri($testSuite/suiteName)}">{$testSuite/suiteName/node()}</a>
      else $testSuite/testName/node()
    },
    local:result-summary-table($testSuite/(self::TestSet|TestSet))   
  )
};

declare function local:result-details(
  $result as element()
  ) {
  <h1>Details</h1>,
  for $suite in $result/(self::TestSet|TestSuite|self::TestSuite)
  return (
    if ($suite instance of element(TestSuite))
    then (
      <h2 id="{encode-for-uri($suite/suiteName)}">{$suite/suiteName/node()}</h2>,
      $suite/description/p
    )
    else (),
    <table border="1">{
      for $set in $suite//TestSet
      return (
        <tr>
          <th>{
            if ($set/description)
            then ()
            else attribute colspan { 5 },
            $set/testName/node()
          }</th>
          {
          if ($set/description)
          then
            <th colspan="4">{$set/description/p/node()}</th>
          else ()
          }
        </tr>,
        for $test in $set//test
        let $pass := local:pass-string(string($test/@pass))
        let $subtests := $test/(* except (code, task, result))
        let $n-subtests := count($subtests)
        return (
          for $subtest at $pos in $subtests
          let $subpass := local:pass-string(string($subtest/@pass))
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
                      serialize($test/result/node(), map {"indent": "yes", "method": "xml" })
                    }</pre>
                  else ()
                }</td>
              else ()
            }</tr>
        )
      )
    }</table>
  )  
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
    			<title>{
    			  if ($result instance of element(TestSuite)
    			    or $result instance of element(TestSet)
    			    )
    			  then
    			    $result/(testName|suiteName)/node()
    			  else "Test Results"
    			}</title>
    			<style type="text/css">
    			.PASS {{
    				background-color:green;
    			}}
    			
    			.FAIL {{
    				background-color:red;
    			}}
    			
    			.IGNORE {{
    			  background-color:darkgrey;
    			}}
    			</style>
    		</head>
        <body>{
          local:result-summaries($result),
          local:result-details($result)
        }</body>
     </html>
};

(: clean up empty text nodes from XML :)
declare %private function t:clean-xml(
        $nodes as node()*
) as node()* {
  for $node in $nodes
  return
    typeswitch($node)
      case text() return
        if (normalize-space($node))
        then $node
        else ()
      case document-node() return
        document {
          t:clean-xml($node/node())
        }
      case element() return
        element { QName(namespace-uri($node), name($node)) }{
          $node/@*,
          t:clean-xml($node/node())
        }
      default return $node
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
  let $n1 := t:clean-xml($node1)
  let $n2 := t:clean-xml($node2)
  return
	(
	  count($n1) = count($n2)
	  and
		(every $result in 
			(
			for $n at $pos in $n1
			return
				typeswitch ($n)
				case document-node() return t:deep-docnode($n, $n2[$pos])
				case comment() return t:deep-comment($n, $n2[$pos])
				case text() return t:deep-text($n, $n2[$pos])
				case attribute() return t:deep-attribute($n, $n2)
				case element() return t:deep-element($n, $n2[$pos])
				default return false()
			)
			satisfies $result
		)
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
