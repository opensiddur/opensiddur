xquery version "1.0";
(:~
 : grammar clean mode
 :
 : Open Siddur Project
 : Copyright 2010-2011 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 : $Id: grammar2.xsl2 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
module namespace clean="http://jewishliturgy.org/transform/grammar/clean";

declare namespace p="http://jewishliturgy.org/ns/parser";
declare namespace r="http://jewishliturgy.org/ns/parser-result";

declare function clean:identity(
	$node as element()
	) as element() {
	element { node-name($node) } {
		$node/@*,
		clean:clean($node/node())
	}
};

declare function clean:r-anonymous(
	$node as element(r:anonymous)
	) as node()* {
	if ($node/.. is root($node))
	then
		clean:identity($node)
	else
		clean:clean($node/node())
};

(:~ clean anonymous return values from the grammar :)
declare function clean:clean(
	$node as node()*
	) as item()* {
	for $n in $node
	return
		typeswitch ($n)
		case $n as text() return $n
		case $n as comment() return $n
		case $n as element(r:empty) return ()
		case $n as element(r:end) return ()
		case $n as element(r:anonymous) return clean:r-anonymous($n)
		default return clean:identity($n)
};
