xquery version "3.0";
(:~
 : Modes to unflatten a flattened hierarchy.
 :
 : Open Siddur Project
 : Copyright 2013 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 :)
module namespace unflatten='http://jewishliturgy.org/transform/unflatten';

import module namespace common="http://jewishliturgy.org/transform/common"
  at "../modules/common.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

(:~ a list of elements that are closed in $sequence, 
 : but not opened :)
declare function unflatten:unopened-tags(
  $sequence as node()*
  ) as element()* {
  for $node in $sequence[@jf:suspend|@jf:end]
  let $id := $node/(@jf:suspend, @jf:end)
  where empty(
    $node/preceding-sibling::*[(@jf:start, @jf:continue)=$id][1]
    intersect $sequence
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
  where empty(
    $node/following-sibling::*[(@jf:suspend, @jf:end)=$id][1]
    intersect $sequence
  )
  return $node
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
  $params as map
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
  $params as map
  ) as element(jf:unflattened) {
  element jf:unflattened {
    $flattened/@*,
    unflatten:sequence($flattened/node(), $params)
  }
};

declare function unflatten:sequence(
  $sequence as node()*,
  $params as map
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
        if ($start-return[1] instance of element())
        then $start-return[1]
        else (),
        unflatten:sequence(
          (
            subsequence($start-return, 3),
            common:following($start-return[2], $sequence)
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
  $params as map
  ) as element() {
  element { QName(namespace-uri($s), name($s)) }{
    $s/(
      (@* except @*[namespace-uri(.)="http://jewishliturgy.org/ns/jlptei/flat/1.0"])|
      (@jf:id, @jf:layer-id, @jf:stream)),
    $s/node()
  }
};

(:~ process a start element.
 : return value: 
 :  [1] The start element or a text node
 :  [2] The end element
 :  [3+] Any continued unclosed tags
 :)
declare function unflatten:start(
  $s as element(),
  $sequence as node()*,
  $params as map
  ) as node()* {
  let $following := common:following($s, $sequence)
  let $end := 
    $following[(@jf:end|@jf:suspend)=$s/(@jf:start, @jf:continue)][1]
  let $inside-sequence := 
    if (exists($end))
    then
      $following 
        intersect common:preceding($end, $sequence)
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
    return (
      if (empty($processed-inside-sequence))
      then text { "Intentionally left blank" }
      else
        element { QName(namespace-uri($s), name($s)) }{
          $s/(
            (@* except @*[namespace-uri(.)="http://jewishliturgy.org/ns/jlptei/flat/1.0"])
            |(@jf:id[exists($s/@jf:start)], @jf:layer-id)
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
        ($end, $inside-sequence[last()])[1],
        unflatten:continue-or-suspend($unclosed-tags, "continue")
      )
};