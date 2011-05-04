xquery version "1.0";
(: dbg.xqm
 : Debugging helper functions
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: dbg.xqm 775 2011-05-01 06:46:55Z efraim.feinstein $
 :)
module namespace dbg="http://jewishliturgy.org/apps/lib/dbg"; 

declare variable $dbg:QMSG := xs:QName('dbg:MESSAGE');

declare variable $dbg:ERROR := 1;
declare variable $dbg:WARNING := 2;
declare variable $dbg:INFO := 3;
declare variable $dbg:DETAIL := 4;
declare variable $dbg:TRACE := 5;

declare function dbg:error($qname as xs:QName, $messages as item()*) {
	dbg:message($qname, $messages, $dbg:ERROR)
};

(:~ output an error message :)
declare function dbg:message($qname as xs:QName, $messages as item()*, $level as xs:integer) {
	let $msg-type :=
		if ($level = $dbg:ERROR)
		then 'ERROR'
		else if ($level = $dbg:WARNING)
		then 'WARNING'
		else if ($level = $dbg:INFO)
		then 'INFO'
		else if ($level = $dbg:DETAIL)
		then 'DETAIL'
		else if ($level = $dbg:TRACE)
		then 'TRACE'
		else 'GREAT DETAIL'
	let $msg-items := ($msg-type, ': ', $messages)
	let $error-message := string-join(
		for $m in $msg-items return string($m), '')
	return (
		util:log-system-out($msg-items),
		if ($level le $dbg:ERROR)
		then error($qname, $error-message)
		else ()
	)
};