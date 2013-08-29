xquery version "3.0";
(:~ give each element in a hierarchy a numeric priority.  
 : Higher numbers indicate more likelihood of being an 
 : outer hierarchy when combined with others.
 :
 : @author Efraim Feinstein
 : Copyright 2009-2010,2012 Efraim Feinstein 
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace setp="http://jewishliturgy.org/transform/set-priorities";

import module namespace common="http://jewishliturgy.org/transform/common"
  at "/code/modules/common.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";
  
declare variable $setp:maximum-priority as xs:decimal := 10000;
  
(: Increase in priority if the element has descendants in the stream
 :  but no children in the stream
 :)
declare variable $setp:priority-boost as xs:decimal := 0.01;

(:~ Return the sorting priority of an element in multiple hierarchies :)
(: <ul>
 :     <li>Elements involved in parallelism have $maximum-priority</li>
 :     <li>Elements in the selection have empty priority</li> 
 :     <li>Elements that have no descendants in the selection have 
 :     a priority</li>
 :     <li>Elements not in the selection that have children in the selection
 :     have a priority equal to the total number of descendants in the selection.</li>
 :     <li>Elements not in the selection that have no children in the selection
 :     have a priority equal to the total number of descendants in the selection +
 :     $priority-boost * max(number of descendants with )</li>
 :   </ul>
 :
 : @param $context The element
 :)
declare function setp:get-sort-priority(
  $context as element()
  ) as xs:decimal {
  let $descendants-from-stream as element()* :=
    $context/descendant::*[@jf:stream]
  let $children-from-stream as element()* :=
    $context/*[@jf:stream]
  return    
    if ($context/@jf:stream)
    then ()
    else if (
        $context instance of element(j:parallelGrp) or 
        $context instance of element(jf:parallel)
      ) 
    then $setp:maximum-priority
    else if (empty($descendants-from-stream)) 
    then setp:get-sort-priority($context/parent::*)
    else if (empty($children-from-stream))
    then ($setp:priority-boost * setp:levels-to-stream($context) + count($descendants-from-stream) )
    else count($descendants-from-stream)
};
  
(:~ Return the largest number of hierarchic levels required 
 : to get from $context to an element that is a direct parent of a 
 : stream element
 :)
declare function setp:levels-to-stream(
  $context as element()
  ) as xs:integer {
  if ($context/@jf:stream or $context/*/@jf:stream) 
  then 0
  else 1 + (
    max(
      for $child in $context/* 
      return setp:levels-to-stream($child)
    ),0
    )[1] 
};

declare function setp:set-priorities(
  $nodes as node()*
  ) {
  for $n in $nodes
  return
    typeswitch($n)
    case element(jf:placeholder) return setp:jf-placeholder($n)
    case element() return setp:element($n)
    default return setp:set-priorities($n/node())
};

(:~ Do identity transform for elements within a stream.
 : Elements in streams are unmovable and don't have priorities.
 :)
declare function setp:jf-placeholder(
  $e as element(jf:placeholder)
  ) {
  $e
};

(:~ Set an element priority, if the element is not already in a stream :)
declare function setp:element(
  $e as element()
  ) {
  element { QName(namespace-uri($e), name($e)) }{
    if (empty($e/parent::*))
    then
      common:copy-attributes-and-context($e, $e/@*)
    else $e/@*,
    attribute jf:priority { setp:get-sort-priority($e) },
    setp:set-priorities($e/node())
  }
};
