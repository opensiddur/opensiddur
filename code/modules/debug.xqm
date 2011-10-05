xquery version "1.0";
(:~
 : debug functions
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 :)
module namespace debug="http://jewishliturgy.org/transform/debug";

declare variable $debug:error := 1;
declare variable $debug:warn := 2;
declare variable $debug:info := 3;
declare variable $debug:detail := 4;
declare variable $debug:level := $debug:detail;

declare variable $debug:settings-file := "/db/code/debug.xml";
declare variable $debug:settings := doc($debug:settings-file);

(:~ debugging output function
 : if the source is listed in /db/code/debug.xm
 :)
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
	let $source-level := 
	  (
	  $debug:settings//debug:settings/@override/number(),
	  $debug:settings//debug:module[@name=$source]/@level/number(),
	  $debug:settings//debug:settings/@level/number(),
	  $debug:level
	  )[1]
	return
  	if ($level = $debug:error)
  	then error(xs:QName('debug:ERROR'), $xmsg)
  	else if ($level <= $source-level)
  	then util:log-system-out($xmsg) (: TODO: this should replace with a custom logger :)
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

