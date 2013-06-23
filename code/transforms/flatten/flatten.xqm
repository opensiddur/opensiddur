xquery version "3.0";
(:~
 : Modes to flatten a hierarchy.
 : To run:
 : flatten:flatten-document -> flatten:merge-document -> flatten:resolve-stream
 : At each step, a save is recommended. 
 :  resolve-stream REQUIRES that the document root be accessible.
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

(:~ order the given flattened nodes, using the information in 
 : the ordering attributes
 :)
declare function flatten:order-flattened(
  $flattened-nodes as node()*
  ) as node()* {
  for $n in $flattened-nodes
  order by 
    $n/@jf:position/number(), 
    $n/@jf:relative/number(), 
    $n/@jf:nchildren/number(), 
    $n/@jf:nlevels/number(), 
    $n/@jf:nprecedents/number(), 
    $n/@jf:layer-id
  return $n
};

(:~ entry point for the merge transform :)
declare function flatten:merge-document(
  $doc as document-node(),
  $params as map
  ) as document-node() {
  common:apply-at(
    $doc, 
    $doc//j:concurrent, 
    flatten:merge-concurrent#2,
    $params  
  )
};

declare function flatten:merge-concurrent(
  $e as element(j:concurrent),
  $params as map
  ) as element(j:concurrent) {
  element { QName(namespace-uri($e), name($e)) }{
    $e/@*,
    flatten:merge(
      flatten:flatten-streamText($e/j:streamText, $params),
      $e/jf:layer,
      $params
    ),
    $e/(node() except jf:layer)
  }
};

(:~ merge flattened layers and a flattened streamText 
 : @return an ordered structure containing all the elements of the layers and the streamText
 :)
declare function flatten:merge(
  $streamText as element(jf:streamText),
  $layers as element(jf:layer)*,
  $params as map
  ) as element(jf:merged) {
  element jf:merged {
    flatten:order-flattened(
      (
      $layers/(node() except jf:placeholder),
      $streamText/node()
      )
    )
  }
};

(:~ replace all references to jf:placeholder with 
 : their stream elements 
 :)
declare function flatten:resolve-stream(
  $nodes as node()*,
  $params as map
  ) as node()* {
  for $node in $nodes
  return
    typeswitch ($node)
    case element (jf:placeholder)
    return 
      let $stream-element := root($s)/id($s/@jf:id)
      return
        element { QName(namespace-uri($stream-element), name($stream-element)) }{
          $stream-element/(@* except @xml:id),
          if ($stream-element/@xml:id)
          then
            attribute jf:id { $stream-element/@xml:id }
          else (),
          $s/@jf:stream,
          $stream-element/node()
        }
    case element()
    return 
      element { QName(namespace-uri($node), name($node)) }{
        $node/@*,
        flatten:resolve-stream($node/node(), $params)
      }
    case document-node()
    return 
      document { 
        flatten:resolve-stream($node/node(), $params) 
      }
    default return $node
};

(:~ entry point to run flatten transform on an entire document,
 : returning the document with flattened layers
 :)
declare function flatten:flatten-document(
  $doc as document-node(),
  $params as map
  ) as document-node() {
  common:apply-at(
    $doc, 
    $doc//j:concurrent, 
    flatten:flatten#2,
    $params
  ) 
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
		case element(j:concurrent) return flatten:identity($n, $params)
		case element(j:streamText) return flatten:j-streamText($n, $params)
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

(:~ streamText within the transform: 
 : assure that the streamText has an xml:id
 :)
declare function flatten:j-streamText(
  $e as element(j:streamText),
  $params as map
  ) {
  element j:streamText {
    if (empty($e/@xml:id))
    then 
      attribute xml:id { flatten:generate-id($e) }
    else (),
    $e/@*,
    $e/node()
  }
};

(:~ flatten a streamtext. 
 : This is not part of the transform, rather, it should be used before merge
 : to obtain placeholders for all streamText elements, whether or not they are
 : referenced by layers
 :)
declare function flatten:flatten-streamText(
  $st as element(j:streamText),
  $params as map
  ) as element(jf:streamText) {
  element jf:streamText {
    attribute jf:id { $st/(@xml:id, flatten:generate-id(.))[1] },
    $st/(@* except @xml:id), 
    for $node in $st/node()
    return
      typeswitch($node)
      case element() return flatten:write-placeholder($node, $st)
      default return $node
  }
};

declare function flatten:write-placeholder(
  $e as element(),
  $stream as element(j:streamText)
  ) as element(jf:placeholder) {
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
    jf:id="{$e/(@xml:id, flatten:generate-id(.))[1]}" 
    jf:position="{count($e/preceding-sibling::*) + 1}"
    jf:relative="0"
    jf:nchildren="0"
    jf:nlevels="0"
    jf:nprecedents="0"
    jf:stream="{$stream/(@xml:id, @jf:id, flatten:generate-id(.))[1]}"/> 
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
      flatten:write-placeholder($target, $stream)
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

(:~ helper function: rewrite the @nchildren parameter following
 : application of flatten:suspend-or-continue
 :)
declare function flatten:rewrite-suspend-or-continue(
  $nodes as node()*
  ) as node()* {
  if (empty($nodes[@jf:suspend]))
  then
    (: no suspend: this is a no-op :)
    $nodes
  else
    let $temp :=
      (: required to make *-sibling::* work :)
      <jf:temp>{
        $nodes
      }</jf:temp>
    let $start-node := $nodes[1]
    let $start-node-id := $start-node/@jf:id/string()
    let $start-level := $start-node/@jf:nlevels/number()
    for $node in $temp/*
    return 
      if ($node/(@jf:start, @jf:continue) = $start-node-id)
      then
        (: this is a start or continue node, look forwards :)
        element { QName(namespace-uri($node), name($node)) }{
          $node/(@* except @jf:nchildren),
          attribute jf:nchildren { 
            - count(
              $node/
                following-sibling::*
                  [@jf:stream]
                  [. << $node/following-sibling::*[(@jf:suspend, @jf:end)=$start-node-id][1]]
            )
          },
          $node/node() 
        }
      else if ($node/(@jf:end, @jf:suspend) = $start-node-id)
      then
        (: this is an end or suspend node, look backwards :)
        element { QName(namespace-uri($node), name($node)) }{
          $node/(@* except @jf:nchildren),
          attribute jf:nchildren { 
            count(
              $node/
                preceding-sibling::*
                  [@jf:stream]
                  [. >> $node/preceding-sibling::*[(@jf:start, @jf:continue)=$start-node-id][1]]
            )
          },
          $node/node() 
        }
      else if (
          empty($node/(@jf:start|@jf:continue|@jf:suspend|@jf:end)) and
          abs($node/@jf:nlevels) = ($start-level + 1) and
          $node/preceding-sibling::*[@jf:start|@jf:continue][@jf:nlevels = $start-level][1]/(@jf:start, @jf:continue) = $start-node-id
      )
      then
        (: this is a child node of the parent with no streamText children :)
        let $parent-node := 
          $node/preceding-sibling::*[(@jf:start, @jf:continue)=$start-node-id][@jf:nlevels = $start-level][1]
        return
          element { QName(namespace-uri($node), name($node)) }{
            $node/(@* except @jf:nchildren),
            attribute jf:nchildren {
              (
                if (number($node/@jf:nchildren/number() < 0))
                then -1
                else 1
              ) *
              count(
                $parent-node/                
                  following-sibling::*
                    [@jf:stream]
                    [. << $parent-node/following-sibling::*[(@jf:suspend, @jf:end)=$start-node-id][1]]
              )
            },
            $node/node() 
          }
      else
        (: nothing specific -- pass through :)
        $node
};

(:~ add suspend or continue elements for the given context 
 : node to a set of flattened elements 
 :)
declare function flatten:suspend-or-continue(
  $context as element(),
  $node-id as xs:string, 
  $flattened-nodes as node()*,
  $start-node as element()
  ) as node()* {
  let $stream-children := $flattened-nodes[@jf:stream]
  let $positions := $stream-children/@jf:position/number()
  for $fnode at $pos in $flattened-nodes
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
            $start-node/(
              @jf:nchildren,
              @jf:nlevels,
              @jf:nprecedents,
              @jf:layer-id
            )
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
            attribute jf:nchildren { - number($start-node/@jf:nchildren) },
            attribute jf:nlevels { - number($start-node/@jf:nlevels) },
            $start-node/@jf:nprecedents,
            $start-node/@jf:layer-id
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
  		let $start-node :=
  		  element { QName(namespace-uri($context), local-name($context)) }{
          $attributes,
          attribute jf:start { $node-id },
          $stream-children[1]/@jf:position,
          attribute jf:relative { -1 },
          attribute jf:nchildren { -$nchildren },
          attribute jf:nlevels { $level },
          attribute jf:nprecedents { $nprecedents },
          attribute jf:layer-id { $params("flatten:layer-id") }
        }
  		return flatten:rewrite-suspend-or-continue((
      	$start-node,
  			flatten:set-missing-attributes(
  			  $context,
  			  flatten:suspend-or-continue(
  			    $context, $node-id, $children, $start-node
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
      ))
};

declare function flatten:set-missing-attributes(
  $context as element(),
  $nodes as node()*,
  $nchildren as xs:integer
  ) as node()* {
  let $temp := 
    (: required for siblinghood :)
    <jf:temp>{
      $nodes
    }</jf:temp>
  for $node at $pos in $temp/*
  return
    typeswitch($node)
    case element() return
      if ($node/@jf:position)
      then $node
      else 
        let $position-number := 
          count($node/preceding-sibling::jf:placeholder) + 1
        let $position := 
          $node/(
            preceding-sibling::jf:placeholder[1], 
            following-sibling::jf:placeholder[1]
          )[1]
        let $relative := 
          if ($position << $node)
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
      flatten:order-flattened(
        flatten:flatten(
          $context/node(), 
          map:new(($params, map { "flatten:layer-id" := $id } ))
        )
      )
    }
};