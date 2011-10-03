xquery version "1.0";
(:~
 : debug functions
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 : $Id: grammar2.xsl2 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
module namespace debug="http://jewishliturgy.org/transform/debug";

declare variable $debug:error := 1;
declare variable $debug:warn := 2;
declare variable $debug:info := 3;
declare variable $debug:detail := 4;
declare variable $debug:level := $debug:detail;

declare function debug:debug(
	$level as xs:integer,
	$source as item()*,
	$message as item()*
	) as empty() {
	let $level-strings := ('error', 'warning', 'info', 'detail', 'trace')
	let $xmsg :=
		element { $level-strings[min(($level, count($level-strings)))] } {
			element source { $source},
			element message { $message }
		}
	return
	if ($level = $debug:error)
	then error(xs:QName('debug:ERROR'), $xmsg)
	else if ($level <= $debug:level)
	then util:log-system-out($xmsg)
	else ()
};

(:~ Debugging function to turn a long string into a short one :)
declare function debug:abbr-string(
	$string as xs:string?
	) as xs:string {
	let $strlen := string-length($string)
	let $quote := "`"
	return
		string-join(
      ($quote,
      if ($strlen < 25)
      then $string
      else ( substring($string, 1, 10), '...', 
        substring($string, $strlen - 10, 10)),
      $quote),
      '')
};

declare function debug:list-attributes(
	$attrs as attribute()*
	) as xs:string {
	string(
		string-join(
			for $a in $attrs
			return ($a/name(), '=', string($a)),
			' '
		)
	)
};

