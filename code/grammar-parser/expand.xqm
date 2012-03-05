xquery version "1.0";
(:~
 : grammar expand mode
 :
 : Open Siddur Project
 : Copyright 2010-2011 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 : $Id: grammar2.xsl2 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
module namespace expand="http://jewishliturgy.org/transform/grammar/expand";

declare namespace p="http://jewishliturgy.org/ns/parser";
declare namespace r="http://jewishliturgy.org/ns/parser-result";

(:~ expand grammar parser index pointers over the whole string 
 : @param $string The string
 : @param $to-expand Grammar result
 :)
declare function expand:expand(
	$node as node()*,
	$string as xs:string
	) as item()* {
	for $n in $node
	return
		typeswitch ($n)
		case $n as element() 
		return 
			if ($n/@expand)
			then expand:at-expand($n, $string)
			else expand:no-at-expand($n, $string)
		default return expand:expand($n/node(), $string)
};

declare function expand:no-at-expand(
	$node as element(),
	$string as xs:string?
	) as node() {
	element {node-name($node)} {
		expand:expand($node/node(), $string) 
	}
};

declare function expand:at-expand(
	$node as element(),
	$string as xs:string?
	) as element() {
	element {node-name($node) }{
		substring($string, $node/@begin, $node/@end - $node/@begin + 1)
	}
};
