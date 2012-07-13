xquery version "3.0";
(:~
 : Modes to flatten a hierarchy.
 :
 : Open Siddur Project
 : Copyright 2009-2012 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 :)
module namespace flatten="http://jewishliturgy.org/transform/flatten";

import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "/code/modules/follow-uri.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "/code/modules/debug.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

(:~ main entry point for the flatten mode :)
declare function flatten:flatten(
	$node as node()*
	) as node()* {
	for $n in $node
	return (
		typeswitch($n)
		case text() return $n
		case comment() return $n
		case processing-instruction() return $n
		case element(j:layer) return flatten:j-layer($n)
		case element(tei:ptr) return flatten:tei-ptr($n)
		case element() return flatten:element($n)
		case document-node() return document { flatten:flatten($n/node()) }
		default return flatten:flatten($n/node())
	)
};

(:~ flatten a ptr. 
 : evaluate ranges into multiple pointers
 : if it points into the local streamText, turn it into a 
 : jf:placeholder and mark it with @jf:stream
 :) 
declare function flatten:tei-ptr(
  $e as element(tei:ptr)
  ) {
  for $target in uri:follow-tei-link($e, 1, (), true())
  let $stream := $target/ancestor::j:streamText 
  return 
    if ($stream)
    then 
      <jf:placeholder 
        jf:id="{$target/@xml:id}" 
        jf:stream="{flatten:generate-id($stream)}"/>
    else flatten:flatten($target)
};

declare function flatten:copy-attributes(
  $context as element()
  ) as attribute()* {
  if ($context/ancestor-or-self::j:layer)
  then (
    $context/(@* except @xml:id),
    if ($context/@xml:id)
    then
      attribute jf:id { $context/@xml:id }
    else ()
  )
  else $context/@*
};

(:~ flatten element :)
declare function flatten:element(
	$context as element()
	) as node()+ {
	let $children := flatten:flatten($context/node())
	let $attributes := flatten:copy-attributes($context)
	return
	  if (
	    ($context is root($context)/*) or
	    ($context/empty(./*|./text())) or
      empty($children[@jf:stream])
    )
    then
  	 	(: Turn a root element of any type into a root element of a flat
       : hierarchy too or
       : element is childless [at least for nodes we care about] or has no pointers from 
       : the current selection :)
    	element { QName(namespace-uri($context), local-name($context)) }{
    		$attributes, 
    		$children
      }	
    else  
	    (: element has children :)
    	let $node-id := 
  		  string(
  		    $context/(
  		      @xml:id,
  		      @jf:uid, 
  		      flatten:generate-id(.)
  		    )[1]
  		  )
  		return (
      	element { QName(namespace-uri($context), local-name($context)) }{
      		$attributes,
  				attribute jf:start { $node-id }
  			},
  			$children,
  			element { QName(namespace-uri($context), local-name($context)) }{
        	attribute jf:end { $node-id }
        }
      )
};

declare function flatten:generate-id(
  $context as element()
  ) {
  concat(
    $context/local-name(), "-",  
    util:node-id($context)
  )
};

(:~ Convert j:layer (which may be a root element) 
 : to jf:layer :)
declare function flatten:j-layer(
	$context as element()
	) as element(jf:layer) {
  element jf:layer {
    $context/(@* except @xml:id),
    attribute jf:id { 
      $context/(
        @xml:id, 
        flatten:generate-id(.)
      )[1] 
    },
    flatten:flatten($context/node())
  }
};