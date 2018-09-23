xquery version "3.1";
(:~
 : Modes to reverse the flattening of a hierarchy.
 :
 : Open Siddur Project
 : Copyright 2013-2014 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 :)
module namespace reverse="http://jewishliturgy.org/transform/reverse";

import module namespace common="http://jewishliturgy.org/transform/common"
  at "../modules/common.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "../modules/debug.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

declare function reverse:reverse-document(
  $doc as document-node(),
  $params as map(*)
  ) as document-node() {
  common:apply-at(
    $doc,
    $doc//(jf:merged|jf:concurrent),
    reverse:reverse#2,
    $params
  )
};

declare function reverse:copy-attributes(
  $e as element()
  ) as attribute()* {
  if ($e/@jf:id)
  then
    attribute xml:id { $e/@jf:id/string() }
  else (),
  $e/(@* except 
    (@jf:start, @jf:continue, 
     @jf:suspend, @jf:end, 
     @jf:id, @jf:layer-id, @jf:stream,
     @jf:position, @jf:relative,  
     @jf:nchildren, @jf:nlevels, @jf:nprecedents
    ))
};

declare function reverse:reverse(
  $n as node(),
  $params as map(*)
  ) as node()* {
  typeswitch($n)
  case element(jf:merged)
  return reverse:jf-merged($n, $params)
  default return ( (: jf:concurrent goes away :) )
};

declare function reverse:jf-merged(
  $e as element(jf:merged),
  $params as map(*)
  ) as element()+ {
  reverse:construct-streamText($e, $params),
  reverse:construct-layers($e, $params)
};

declare function reverse:construct-streamText(
  $e as element(jf:merged),
  $params as map(*)
  ) as element(j:streamText)* {
  for $stream in distinct-values($e//@jf:stream)
  return
    element j:streamText {
      attribute xml:id { 
        if (contains($stream, "#")) 
        then substring-after($stream, "#") 
        else $stream 
      },
      for $elem in $e/*[@jf:stream=$stream]
      return
        element { QName(namespace-uri($elem), name($elem)) }{
          reverse:copy-attributes($elem),
          $elem/node()
        }
    }
};

declare function reverse:construct-layers(
  $e as element(jf:merged),
  $params as map(*)
  ) as element (j:concurrent)? {
  let $jf-concurrent := $e/../jf:concurrent
  let $layers := 
    for $layer in $jf-concurrent/jf:layer
    return 
      element j:layer {
        reverse:copy-attributes($layer),
        reverse:construct-layer(
          $e/*[1], 
          map:new(($params, 
            map {
              "reverse:layer-id" := $layer/@jf:layer-id/string()
            })))
      }
  where $layers
  return
    element j:concurrent {
      reverse:copy-attributes($jf-concurrent),
      $layers
    }
};

(:~ construct a layer hierarchy
 : @param $params map parameters, which include: 
 :  "reverse:layer-id" = the id of the layer being constructed
 :  "reverse:start" = the start element that is being processed, if any
 :  "reverse:end" = the end element to return at, if any
 :)
declare function reverse:construct-layer(
  $node as node()?,
  $params as map(*)
  ) as node()* {
  typeswitch($node)
  case empty-sequence()
  return ()
  case element()
  return
    let $this-layer := $params("reverse:layer-id")
    let $this-parent := $params("reverse:start")
    let $this-end := $params("reverse:end")
    let $suspended := $params("reverse:suspended")
    return (
      if ($node/@jf:layer-id=$this-layer)
      then
        (: new hierarchic element in this layer :)
        if ($node is $this-end)
        then (
          (: no-op -- do not recurse :)
        )
        else if ($node/@jf:start)
        then
          (: start a new element :)
          let $end := $node/following-sibling::*[@jf:end=$node/@jf:start][1]
          return (
            element { QName(namespace-uri($node), name($node)) }{
              reverse:copy-attributes($node),
              reverse:construct-layer(
                $node/following-sibling::node()[1],
                map:new((
                  $params,
                  map {
                    "reverse:start" := $node,
                    "reverse:end" := $end
                  }))
              )
            },
            reverse:construct-layer(
              $end/following-sibling::node()[1],
              $params
            )
          )
        else if ($node/@jf:suspend)
        then (
          (: recurse forward, suspending the current :)
          reverse:construct-layer(
            $node/following-sibling::node()[1], 
            map:new((
              $params,
              map { 
                "reverse:suspended" := ($params("reverse:suspended"), $node/@jf:suspend)
              } 
            ))
          )
        )
        else if ($node/@jf:continue)
        then (
          (: recurse forward, undo the suspension :)
          reverse:construct-layer(
            $node/following-sibling::node()[1], 
            map:new((
              $params,
              map { 
                "reverse:suspended" := ($params("reverse:suspended")[not(.=$node/@jf:continue)])
              } 
            ))
          )
        )
        else (
          (: this is a literal element :)
          element { QName(namespace-uri($node), name($node)) }{
            reverse:copy-attributes($node),
            $node/node()
          },
          reverse:construct-layer(
            $node/following-sibling::node()[1],
            $params
          )
        )
      else if ($node/@jf:stream)
      then (
        (: node in the stream :)
        if (
          exists($this-parent) and
          not($suspended = $this-parent/@jf:start)
        ) 
        then
          element tei:ptr {
            attribute target { "#" || $node/@jf:id/string() } 
          }
        else (),
        reverse:construct-layer(
          $node/following-sibling::node()[1],
          $params)
      )
      else (
        (: just go ahead, nothing to do here :)
        reverse:construct-layer($node/following-sibling::node()[1], $params)
      )
    )
  default 
  return (
    if (exists($params("reverse:start")))
    then $node
    else (),
    reverse:construct-layer($node/following-sibling::node()[1], $params)
  )
};
