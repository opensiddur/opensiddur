(: Simple script to run tests from the database.  To run, use a ?test=xspec_file parameter

Copyright 2010 Efraim Feinstein
Open Siddur Project
Licensed under the GNU Lesser General Public License, version 3 or later

$Id: run-db-tests.xql 687 2011-01-23 23:36:48Z efraim.feinstein $

:)
import module namespace xspec="http://jewishliturgy.org/modules/xspec" at "/code/modules/xspec.xqm";

declare option exist:serialize "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes";

let $test := request:get-parameter('test','')
let $xspec := 
  if ($test) 
  then concat('/code/transforms/', $test)
  else '/code/tests/identity.xspec'
return
  xspec:test($xspec)
