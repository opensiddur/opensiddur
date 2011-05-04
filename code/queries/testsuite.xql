xquery version "1.0";
(:~ Run a given test suite, given by the suite parameter.
 :	Format in HTML if format=html parameter is given
 : 
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: testsuite.xql 732 2011-04-11 12:57:50Z efraim.feinstein $
 :)
import module namespace request="http://exist-db.org/xquery/request";
import module namespace test2="http://exist-db.org/xquery/testing/modified"
	at "/code/modules/test2.xqm";
import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";

let $suite := request:get-parameter('suite', ())
let $format := request:get-parameter('format', ())
let $results := test2:run-testSuite(doc($suite)//TestSuite)
return
	if ($format = 'html')
	then (
		api:serialize-as('xhtml'),
		test2:format-testResult($results)
	)
	else $results
	