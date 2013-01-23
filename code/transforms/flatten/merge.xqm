xquery version "3.0";
(:~
 : Modes to merge flattened hierarchical layers
 :
 : Open Siddur Project
 : Copyright 2009-2012 Efraim Feinstein 
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
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";

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

(:~ set the @jx:parents and @jx:ancestors attributes of elements in
 :  a flat hierarchy to the xml:ids of the parent and ancestor elements
 :  Uses the parent-id and ancestor-ids tunnel parameters
 :)
declare function merge:set-parents(
	$context as element(),
	$tunnel as element()?
	) as attribute()* {
	let $parent-id as xs:string? := $tunnel/flatten:parent-id/string()
	let $ancestor-ids as xs:string* := $tunnel/flatten:ancestor-ids/string()
	return (
		(:debug:debug($debug:detail, ('set-parents:tunnel in ', $context), ($tunnel, ' parent-id =', $parent-id, ' ancestor-ids=', string-join($ancestor-ids,' '))),:)
		if (exists($parent-id))
		then attribute jx:parents { $parent-id }
		else (),
		if (exists($ancestor-ids))
		then attribute jx:ancestors { string-join($ancestor-ids,' ') }
		else ()
	)
};

(:~ main entry point for the merge mode, which operates on 
 : streamText
 :)
declare function merge:merge-j-streamText(
  $e as element(j:streamText),
  $layers as element(jf:layer)*
  ) as element(jf:merged-layers) {
  element jf:merged-layers {
    if ($e/@xml:id)
    then attribute jf:id { $e/@xml:id }
    else (),
    common:copy-attributes-and-context($e, $e/(@* except @xml:id)),
    merge:merge($e/*, $layers)
  }
};

declare function merge:merge(
	$node as node()*,
	$layers as element(jf:layer)*
	) as node()* {
	for $n in $node
	return (
		typeswitch($n)
		case text() return $n
		case comment() return $n
		case processing-instruction() return $n
		case element(j:streamText) return merge:merge-j-streamText($n, $layers)
		case element() return merge:element($n)
		case document-node() return document { merge:merge($n/node()) }
		default return merge:merge($n/node())
	)
};

(:~ The "meat" of the merge operation, to be run on
 : the elements in the streamText
 : Combine and dump all of the flat hierarchies, 
 : avoid duplicates
 :)
declare function merge:element(
  $e as element(),
  $layers as element(jf:layer)*
  ) {
  let $xmlid := $e/(@jf:id, @xml:id)[1]
  let $stream := $e/parent::j:streamText
  let $stream-id := $stream/(@jf:uid, common:generate-id(.))[1]
  let $equivs := $layers/jf:placeholder[@jf:id=$e/@xml:id]
  let $before := 
    for $equiv in $equivs
    let $previous-sibling := $equiv/preceding-sibling::jf:placeholder[1]
    let $all-preceding := $equiv/preceding-sibling::node() 
    return 
      if ($previous-sibling)
      then 
        (: a previous sibling exists, get 
         : the nodes between the siblings
         :)
        $all-preceding
        intersect
        $previous-sibling/following-sibling::node()
      else
        $all-preceding
  let $after :=
    for $equiv in $equivs
    let $following-sibling := $equiv/following-sibling::jf:placeholder[1]
    let $all-following := $equiv/preceding-sibling::node()
    return 
      if ($following-sibling)
      then
        $all-following
        intersect
        $following-sibling/preceding-sibling::node()
      else
        (: if this is the last in a layer :)
        $all-following
  return (
    $before,
    element { QName(namespace-uri($e), name($e)) } {
      attribute jf:id { $e/@xml:id },
      attribute { jf:uid }{ $e/(@jf:uid, common:generate-id($e))[1] },
      attribute { jf:stream} { $stream-id },
      $e/(@* except @xml:id, node())
    },
    $after
  )
};
