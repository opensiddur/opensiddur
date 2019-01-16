xquery version "3.1";
(:~
 : Modes to unflatten a flattened hierarchy.
 :
 : Open Siddur Project
 : Copyright 2013-2014 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 :)
module namespace unflatten='http://jewishliturgy.org/transform/unflatten';

import module namespace common="http://jewishliturgy.org/transform/common"
  at "../modules/common.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

(:~ exclude attributes added by flattening :)
declare %private function unflatten:attributes-except-flatten(
    $e as element()
    ) as node()* {
    $e/@* except (
        $e/@jf:start, $e/@jf:end, $e/@jf:continue, $e/@jf:suspend,
        $e/@jf:position, $e/@jf:relative, $e/@jf:nchildren, 
        $e/@jf:nlevels, $e/@jf:nprecedents
    )
};

(:~ a list of elements that are closed in $sequence, 
 : but not opened :)
declare function unflatten:unopened-tags(
  $sequence as node()*
  ) as element()* {
  for $node in $sequence[@jf:suspend|@jf:end]
  let $id := $node/(@jf:suspend, @jf:end)
  let $prec := common:preceding($node, $sequence)
  where empty(
    $prec[(@jf:start,@jf:continue)=$id]
    )
  return $node
};

(:~ a sequence of elements that are open in $sequence,
 : but never closed
 :)
declare function unflatten:unclosed-tags(
  $sequence as node()*
  ) as element()* {
  for $node in $sequence[@jf:start|@jf:continue]
  let $id := $node/(@jf:start, @jf:continue)
  let $fol := common:following($node, $sequence) 
  where empty(
    $fol[(@jf:suspend,@jf:end)=$id]
  )
  return $node
};

(: if the merged element contains a parallel structure, 
 : initiate a transform to suspend open elements at parallel boundaries
 : and continue them inside
 :)
declare function unflatten:parallel-suspend-and-continue(
    $e as element(jf:merged),
    $params as map(*)
    ) as element(jf:merged) {
    if (exists($e/jf:parallelGrp))
    then 
        element jf:merged {
            $e/@*,
            unflatten:iterate-parallel-suspend-and-continue(
                $e/node(),
                (),
                (),
                $params
            )
        }
    else $e
};

declare function unflatten:iterate-parallel-suspend-and-continue(
    $sequence as node()*,
    $opened-elements as element()*,
    $suspended-elements as element()*,
    $params as map(*)
    ) as node()* {
    let $s := $sequence[1]
    where exists($s)
    return (
        typeswitch($s)
        case element()
        return 
            if ($s/self::jf:parallelGrp[@jf:start|@jf:continue]
                or $s/self::jf:parallel[@jf:end|@jf:suspend])
            then (
                unflatten:continue-or-suspend($opened-elements, "suspend"),
                $s,
                unflatten:iterate-parallel-suspend-and-continue(
                    subsequence($sequence, 2),
                    (),
                    $opened-elements,   (: open elements are now suspended :)
                    $params
                )
            )
            else if ($s/self::jf:parallelGrp[@jf:end|@jf:suspend]
                    or $s/self::jf:parallel[@jf:start|@jf:continue])
            then (
                $s,
                unflatten:continue-or-suspend($suspended-elements, "continue"),
                unflatten:iterate-parallel-suspend-and-continue(
                    subsequence($sequence, 2),
                    $suspended-elements,    (: suspended elements are now open :)
                    (),
                    $params
                )
            )
            else (: other element :)
                let $next-opened-elements :=
                    if ($s/@jf:start|$s/@jf:continue) 
                    then ($opened-elements, $s) 
                    else if ($s/@jf:end|$s/@jf:suspend)
                    then 
                        $opened-elements[not((@jf:start,@jf:continue)=$s/(@jf:suspend, @jf:end))]
                    else $opened-elements
                return ($s,
                    unflatten:iterate-parallel-suspend-and-continue(
                        subsequence($sequence, 2),
                        $next-opened-elements,
                        $suspended-elements,
                        $params
                    )
                )
        default 
        return ($s, 
            unflatten:iterate-parallel-suspend-and-continue(
                subsequence($sequence, 2),
                $opened-elements,
                $suspended-elements,
                $params
            )
        )
    )
};

declare function unflatten:continue-or-suspend(
  $tags as element()*,
  $type as xs:string
  ) as element()* {
  for $tag in $tags
  return
    element { QName(namespace-uri($tag), name($tag)) }{
      attribute { "jf:" || $type }{ 
        $tag/(@jf:start, @jf:continue, @jf:suspend, @jf:end)  
      },
      $tag/(@* except (@jf:start, @jf:end, @jf:continue, @jf:suspend))
    }
};

declare function unflatten:unflatten-document(
  $doc as document-node(),
  $params as map(*)
  ) as document-node() {
  common:apply-at(
    $doc, 
    $doc//jf:merged, 
    unflatten:unflatten#2,
    $params
  ) 
  
};

(:~ unflatten a flattened hierarchy that is contained inside
 : a container element
 : @param $flattened container element
 : @return unflattened hierarchy 
 :)
declare function unflatten:unflatten(
  $flattened as element(),
  $params as map(*)
  ) as element(jf:unflattened) {
  element jf:unflattened {
    $flattened/@*,
    unflatten:sequence(
        unflatten:parallel-suspend-and-continue($flattened, $params)/node(), 
        $params
    )
  }
};

declare function unflatten:sequence(
  $sequence as node()*,
  $params as map(*)
  ) as node()* {
  let $s := $sequence[1]
  let $seq := $sequence
  return
    if (empty($s))
    then ()
    else if ($s/(@jf:start|@jf:continue))
    then 
      let $start-return := unflatten:start($s, $sequence, $params)
      return (
        $start-return("start"),
        unflatten:sequence(
          (
            if (exists($start-return("end")))
            then $start-return("continue")
            else (),
            common:following($start-return("end"), $sequence)
          ),
          $params
        )
      )
    else (
      if ($s/(@jf:end|@jf:suspend))
      then ()
      else 
        if ($s instance of element())
        then unflatten:lone-element($s, $params)
        else $s, 
      unflatten:sequence(
        subsequence($sequence, 2),
        $params
      )
    )
};

(:~ element with no start, continue, end, suspend :)
declare function unflatten:lone-element(
  $s as element(),
  $params as map(*)
  ) as element() {
  element { QName(namespace-uri($s), name($s)) }{
    unflatten:attributes-except-flatten($s),
    $s/node()
  }
};

(:~ process a start element.
 : return value: A map containing:
 :  "start" := The start element, processed
 :  "end" := The end element
 :  "continue" := Any continued unclosed tags
 :)
declare function unflatten:start(
  $s as element(),
  $sequence as node()*,
  $params as map(*)
  ) as map(*) {
  let $following as node()* := common:following($s, $sequence)
  let $end as node()? :=
    $following[(@jf:end|@jf:suspend)=$s/(@jf:start, @jf:continue)][1]
  let $inside-sequence as node()* :=
    if (exists($end))
    then
        let $preceding as node()* := common:preceding($end, $sequence)
        return
            $following intersect $preceding
    else
      $following
  let $unopened-tags := unflatten:unopened-tags($inside-sequence)
  let $unclosed-tags := unflatten:unclosed-tags($inside-sequence)
  return 
    let $processed-inside-sequence := 
      unflatten:sequence(
        (
          unflatten:continue-or-suspend($unopened-tags, "continue"),
          $inside-sequence,
          unflatten:continue-or-suspend(reverse($unclosed-tags), "suspend")
        ),
        $params
      )
    return map {
      "start" := 
        if (empty($processed-inside-sequence))
        then () 
        else
          element { QName(namespace-uri($s), name($s)) }{
            (
              (unflatten:attributes-except-flatten($s) except $s/@jf:id)
              |($s/@jf:id[exists($s/@jf:start)])
            ),
            if (
              exists($s/@jf:continue) or 
              exists($end/@jf:suspend) or 
              empty($end) (: automatic suspend :) )
            then
              attribute jf:part {
                ($s/@jf:continue, $end/@jf:suspend, $s/@jf:start)[1]
              }
            else (),
            $processed-inside-sequence
          },
      "end" :=
        ($end, $inside-sequence[last()])[1],
      "continue" :=
        unflatten:continue-or-suspend($unclosed-tags, "continue")
    }
};
