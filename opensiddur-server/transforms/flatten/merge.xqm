xquery version "3.0";
(:~
 : Modes to merge flattened hierarchical layers
 :
 : Open Siddur Project
 : Copyright 2009-2013 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 :)
module namespace merge="http://jewishliturgy.org/transform/merge";

import module namespace common="http://jewishliturgy.org/transform/common"
  at "/db/code/modules/common.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "/db/code/modules/follow-uri.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "/db/code/modules/debug.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

(:~ Given a sequence of elements from a flattened hierarchy,
 :  produce equivalent open or closed tags.
 : 
 : If activity is suspend, the tags become suspend tags,
 : if it is continue, they become continue tags.
 :
 : @param $sequence Sequence of opening elements
 : @param $activity May be one of `suspend` or `continue`
 :)
declare function merge:continue-or-suspend(
  $sequence as element()*,
  $activity as xs:string
	) as element()* {
	for $seq in $sequence
	(: this variable is here to flag an error if there is no @jf:*activity* on the element or more than one :)
	let $current-activity as attribute() :=
  	$seq/(@jf:start,@jf:continue,@jf:end,@jf:suspend)
  return
  	element { node-name($seq) }{
    	$seq/(@* except (@jf:start,@jf:continue,@jf:suspend,@jf:end)),
      attribute {concat('jf:', $activity)}{ $current-activity },
      $seq/node()
    }
};
  
(:~ Find the tags that are closed, but not opened,
 :  in a group of flattened hierarchy.
 :
 : @param $inside-group Group of tags to search within.
 :)
declare function merge:unopened-tags(
  $inside-group as element()*
  ) as element()* {
  for $closed in ($inside-group[@jf:suspend|@jf:end])
  where not(
  	some $open-id in ($closed/@jf:suspend, $closed/@jf:end)
    satisfies $open-id=($inside-group/@jf:start, $inside-group/@jf:continue)
  )
  return $closed
};
  
(:~ Find tags that are opened, but not closed, in a flattened hierarchy
 : @param $inside-group Group of tags to search within.
 :)
declare function merge:unclosed-tags(
  $inside-group as element()*
	) as element()* {
  for $opened in ($inside-group[@jf:start|@jf:continue])
  where not(
  	some $open-id in ($opened/@jf:start, $opened/@jf:continue)
    satisfies $open-id=($inside-group/@jf:end, $inside-group/@jf:suspend)
  )
  return $opened
};

(:~ merge layers :)
declare function merge:merge-layers(
  $layers as element(jf:layer)*
  ) as element(jf:merged-layers) {
  element jf:merged-layers {
    for $node in $layers/*
    let $this-position := $n/@jf:position/number()
    order by 
      $n/@jf:position/number(), 
      $n/@jf:relative/number(), 
      $n/@jf:nchildren/number(), 
      $n/@jf:nlevels/number(), 
      $n/@jf:layer-id, 
      $n/@jf:nprecedents/number()
    return 
      if (
        $node instance of element(jf:placeholder)
        and exists(preceding-sibling::jf:placeholder[@jf:position=$this-position]) 
        )
      then
        ((: avoid duplicating placeholders :))
      else $node
  }
};

(:~ main entry point for the merge mode, which operates on 
 : streamText
 :)
declare function merge:merge-streamText-to-layers(
  $e as element(j:streamText),
  $layers as element(jf:layer)*
  ) as element(jf:merged-layers) {
  element jf:merged-layers {
    if ($e/@xml:id)
    then attribute jf:id { $e/@xml:id }
    else (),
    common:copy-attributes-and-context($e, $e/(@* except @xml:id)),
    merge:merge-streamText(
      merge:merge-layers($layers)
    )
  }
};

declare function merge:merge-streamText(
  $e as element(j:streamText),
  $merged-layer as element(jf:merged-layers)
  ) as node()* {
  for $node in $merged-layer/*
  return
    typeswitch($node)
    case element(jf:placeholder)
    return 
      let $stream-element := $e/*[$node/@jf:position/number()]
      return
        element {QName(namespace-uri($stream-element), name($stream-element))}{
          $stream-element/(@* except @xml:id),
          if ($stream-element/@xml:id)
          then attribute jf:id { $stream-element/@xml:id/string() }
          else (),
          $node/(@jf:* except @jf:id),
          $stream-element/node()
        }
    default return $node
};


