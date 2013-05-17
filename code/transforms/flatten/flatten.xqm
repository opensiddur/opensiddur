xquery version "3.0";
(:~
 : Modes to flatten a hierarchy.
 :
 : Open Siddur Project
 : Copyright 2009-2013 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 :)
module namespace flatten="http://jewishliturgy.org/transform/flatten";

import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "/db/code/modules/follow-uri.xqm";
import module namespace common="http://jewishliturgy.org/transform/common"
  at "/db/code/modules/common.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "/db/code/modules/debug.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

(:~ entry point to run flatten transform on an entire document,
 : returning the document with flattened layers
 :)
declare function flatten:flatten-document(
  $doc as document-node(),
  $params as map
  ) as document-node() {
  common:apply-at(
    $doc, 
    $doc//j:layer, 
    flatten:flatten-layer#2,
    $params
  ) 
}; 

(:~ main entry point for the flatten mode :)
declare function flatten:flatten-layer(
  $node as node()*,
  $params as map
  ) as node()* {
  flatten:flatten($node, $params)
};

declare function flatten:flatten(
	$node as node()*,
	$params as map
	) as node()* {
	for $n in $node
	return (  
		typeswitch($n)
		case text() return $n
		case comment() return $n
		case processing-instruction() return $n
		case element(j:layer) return flatten:j-layer($n, $params)
		case element(tei:ptr) return flatten:tei-ptr($n, $params)
		case element() return 
		  if ($n is root($n)/*) 
		  then flatten:identity($n, $params) (: special treatment for root elements :)
		  else flatten:element($n, $params)
		case document-node() return document { flatten:flatten($n/node(), $params) }
		default return flatten:flatten($n/node(), $params)
	)
};

(:~ identity :)
declare function flatten:identity(
  $e as element(),
  $params as map
  ) as element() {
  element { QName(namespace-uri($e), name($e))}{
    flatten:copy-attributes($e),
    flatten:flatten($e/node(), $params)
  }
};

(:~ flatten a ptr. 
 : evaluate ranges into multiple pointers
 : if it points into the local streamText, turn it into a 
 : jf:placeholder and mark it with @jf:stream
 :) 
declare function flatten:tei-ptr(
  $e as element(tei:ptr),
  $params as map
  ) as element()+ {
  for $target in uri:follow-tei-link($e, 1, (), true())
  let $stream := $target/ancestor::j:streamText 
  return 
    if ($stream)
    then 
      (: 
        position = position in streamText, starting from 1
        relative = position relative to placeholder 
          (-1 for before, 0 for at, 1 for after)
        nchildren = number of children in streamText
        nlevels = distance in levels from the streamText
        nprecedents = number of preceding siblings in layer (0 for streamText)
        stream = which stream derived from
        layer-id = which layer derived from
       :)
      <jf:placeholder 
        jf:id="{$target/@xml:id}" 
        jf:position="{count($target/preceding-sibling::*) + 1}"
        jf:relative="0"
        jf:nchildren="0"
        jf:nlevels="0"
        jf:nprecedents="0"
        jf:stream="{$stream/(@xml:id, @jf:id, flatten:generate-id(.))[1]}"/>
    else flatten:element($target, $params)
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

(:~ add suspend or continue elements for the given context 
 : node to a set of flattened elements 
 :)
declare function flatten:suspend-or-continue(
  $context as element(),
  $node-id as xs:string, 
  $flattened-nodes as node()*
  ) as node()* {
  let $stream-children := $flattened-nodes[@jf:stream]
  let $positions := $stream-children/@jf:position/number()
  let $nchildren := count($stream-children)
  for $fnode in $flattened-nodes
  return 
    if ($fnode instance of element(jf:placeholder))
    then 
      let $position := $fnode/@jf:position/number()
      return (
        if ($position = $positions[1] or ($position - 1) = $positions)
        then ()
        else (
          (: previous position was skipped, resume the context element :)
          element {QName(namespace-uri($context), name($context))}{
            attribute jf:continue { $node-id },
            $fnode/@jf:position,
            attribute jf:relative { -1 },
            attribute jf:nchildren { -$nchildren }
          }
        ),
        $fnode,
        if ($position = $positions[last()] or ($position + 1) = $positions)
        then ()
        else (
          (: next position will be skipped, suspend the context element :)
          element {QName(namespace-uri($context), name($context))}{
            attribute jf:suspend { $node-id },
            $fnode/@jf:position,
            attribute jf:relative { 1 },
            attribute jf:nchildren { $nchildren }
          }
        )
      )
    else $fnode
};

(:~ flatten element 
 : @param $params Expects "flatten:layer-id"
 :)
declare function flatten:element(
	$context as element(),
	$params as map
	) as node()+ {
	let $node-id := 
        string(
          $context/(
            @xml:id,
            @jf:id, 
            flatten:generate-id(.)
          )[1]
        )
	let $children := 
	  flatten:flatten(
	    $context/node(), 
	    map:new(($params, map { "flatten:unit-id" := $node-id }))
	  )
	let $layer := $context/ancestor::j:layer
	let $level := count($context/ancestor::*) - count($layer/ancestor::*)
	let $nprecedents := count($context/preceding-sibling::*) + 1
	let $attributes := flatten:copy-attributes($context)
	return
	  if (
	    ($context/empty(./*|./text())) or
      empty($children[@jf:stream])
    )
    then
  	 	(: If an element is empty or has no children in the streamText
  	 	 :)
    	element { QName(namespace-uri($context), local-name($context)) }{
    		$attributes,
    		((: position and relative are filled in later :)),
        attribute jf:nlevels { $level },
        attribute jf:nprecedents { $nprecedents },
        attribute jf:layer-id { $params("flatten:layer-id") },
    		$context/node()
      }	
    else  
	    (: element has children in the streamText :)
  		let $stream-children := $children[@jf:stream]
  		let $nchildren := count($stream-children)
  		return (
      	element { QName(namespace-uri($context), local-name($context)) }{
      		$attributes,
  				attribute jf:start { $node-id },
  				$stream-children[1]/@jf:position,
  				attribute jf:relative { -1 },
  				attribute jf:nchildren { -$nchildren },
  				attribute jf:nlevels { $level },
  				attribute jf:nprecedents { $nprecedents },
  				attribute jf:layer-id { $params("flatten:layer-id") }
  			},
  			flatten:set-missing-attributes(
  			  $context,
  			  flatten:suspend-or-continue(
  			    $context, $node-id, $children
  			  ),
  			  $nchildren
  			),
  			element { QName(namespace-uri($context), local-name($context)) }{
        	attribute jf:end { $node-id },
        	$stream-children[last()]/@jf:position,
          attribute jf:relative { 1 },
          attribute jf:nchildren { $nchildren },
          attribute jf:nlevels { -$level },
          attribute jf:nprecedents { $nprecedents },
          attribute jf:layer-id { $params("flatten:layer-id") }
        }
      )
};

declare function flatten:set-missing-attributes(
  $context as element(),
  $nodes as node()*,
  $nchildren as xs:integer
  ) as node()* {
  let $placeholder-positions := 
    for $node at $pos in $nodes
    where $node instance of element(jf:placeholder)
    return $pos
  for $node at $pos in $nodes
  return
    typeswitch($node)
    case element() return
      if ($node/@jf:position)
      then $node
      else 
        let $position-number := 
          number((
              $placeholder-positions[. < $pos][last()],
              $placeholder-positions[. > $pos][1]
            )[1])
        let $position := 
          (: equivalent of (preceding::jf:placeholder[1], following::jf:placeholder[1])[1] :)
          $nodes[$position-number]
        let $relative := 
          if ($position-number < $pos)
          then +1
          else -1 
        return
          (: need to enter position, relative, and nchildren :)
          element {QName(namespace-uri($node), name($node))}{
            $node/(@* except @jf:nlevels),
            $position/@jf:position,
            attribute jf:nlevels { -$relative * $node/@jf:nlevels/number() },
            attribute jf:relative { $relative },
            attribute jf:nchildren {  $relative * $nchildren },
            $node/node()
          }
    default return $node
};

declare function flatten:generate-id(
  $context as element()
  ) as xs:string {
  concat(
    $context/local-name(), "-",  
    util:node-id($context)
  )
};

(:~ Convert j:layer (which may be a root element) 
 : to jf:layer.
 : Start sending the "flatten:layer-id" parameter
 :)
declare function flatten:j-layer(
	$context as element(),
	$params as map
	) as element(jf:layer) {
	let $id := 
	  $context/(
      @xml:id, 
      flatten:generate-id(.)
    )[1]
	return 
    element jf:layer {
      $context/(@* except @xml:id),
      attribute jf:id { 
        $id 
      },
      flatten:flatten(
        $context/node(), 
        map:new(($params, map { "flatten:layer-id" := $id } ))
      )
    }
};