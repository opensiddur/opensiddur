xquery version "3.0";
(:~ Follow pointers within a j:layer until they point into 
 : a streamText.  
 : Return a j:layer containing the resolved pointers.  
 : The $params should contain:
 : - "full-context" value (xs:boolean), indicating whether
 :    the entire context should be copied
 : - "current-document-uri" (xs:anyURI/xs:string) indicating the 
 :    document-uri() that the data came from
 : - "current-language" (xs:language/xs:string) indicating 
 :    the language context
 : - "current-base-uri" (xs:anyURI/xs:string) indicating
 :    the current base URI
 : whether the full context should be copied 
 : if not changed (default false())
 :   
 : Copyright 2009-2010, 2012 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace rslv="http://jewishliturgy.org/transform/resolve-internal";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "/code/modules/follow-uri.xqm";
import module namespace common="http://jewishliturgy.org/transform/common"
  at "/code/modules/common.xqm";


(:~ main entry point :)
declare function rslv:resolve-internal(
   $nodes as node()*,
   $tunnel as map(xs:string, item()*)
  ) {
  for $n in $nodes
  return
    typeswitch($n)
    case element(tei:ptr) return rslv:tei-ptr($n, $tunnel)
    case element(j:layer) return rslv:j-layer($n, $tunnel)
    case element(j:parallelGrp) return rslv:j-parallelGrp($n, $tunnel)
    case element() return rslv:element($n, $tunnel)
    default return rslv:resolve-internal($n/node(), $tunnel)
};

(:~ Resolve internal pointers until a dead end or a pointer
 : to the streamText is found. Replace them with 
 : jf:placeholder elements 
 :)
declare function rslv:tei-ptr(
  $e as element(tei:ptr),
  $tunnel as map(xs:string, item()*)
  ) {
  for $target in uri:follow-tei-link($e, 1, (), true())
  let $stream := $target/ancestor::j:streamText 
  return 
    if ($stream)
    then 
      element jf:placeholder { 
        attribute jf:id {$target/@xml:id},
        attribute jf:uid {($e/@jf:uid, common:generate-id($e))[1]}, 
        attribute jf:stream {common:generate-id($stream)},
        rslv:resolve-internal-copy-context($e,$tunnel)[not(name(.)="target")]
      }
    else 
      rslv:resolve-internal(
        $target, 
        map:new((
          $tunnel, 
          map {
            "current-document-uri" := common:original-document-uri($e),
            "current-lang" := common:language($e)
          } 
        ))
      )
};
  
declare function rslv:j-layer(
  $e as element(j:layer),
  $tunnel as map(xs:string, item()*)
  ) {
  element j:layer {
    common:copy-attributes-and-context($e, $e/@*, $tunnel),
    attribute jf:uid { ($e/@jf:uid, common:generate-id($e))[1] },
    if ($e/@xml:id)
    then
      attribute jf:id { $e/@xml:id }
    else (),
    rslv:resolve-internal(
      $e/node(), 
      map:new((
        $tunnel, 
        map {
          "current-document-uri" := common:original-document-uri($e),
          "current-lang" := common:language($e)
        } 
      ))
    )
  }
};
  
(:~ Element in resolve-internal mode.  Copy the element and
 :  return it with new attributes:
 :  * @jf:uid containing the attribute's original node ID
 :  * @jf:id containing any original @xml:id
 :  @jf:uid can be used later to find which resolved elements
 :  refer to the same node. "uid" means "unique identifier."
 :)
declare function rslv:element(
  $e as element(),
  $tunnel as map(xs:string, item()*)
  ) {
  element { QName(namespace-uri($e), name($e)) }{
    rslv:resolve-internal-copy-context($e, $tunnel),
    attribute jf:uid { ($e/@jf:uid, common:generate-id($e))[1] },
    if ($e/@xml:id)
    then
      attribute jf:id { $e/@xml:id }
    else (),
    rslv:resolve-internal(
      $e/node(), 
      map:new((
        $tunnel, 
        map {
          "current-document-uri" := common:original-document-uri($e),
          "current-lang" := common:language($e)
        } 
      ))
    )
  }
};
  
(:~ Mark the streams(s) that the parallel group is 
 : derived from with an @jf:stream-origin attribute
 :)
declare function rslv:j-parallelGrp(
  $e as element(j:parallelGrp),
  $tunnel as map(xs:string, item()*)
  ) as element(j:parallelGrp) {
  element j:parallelGrp {
    rslv:resolve-internal-copy-context($e,$tunnel),
    attribute jf:uid { ($e/@jf:uid, common:generate-id($e))[1] },
    for $placeholder in rslv:resolve-internal($e/node(),$tunnel)
    group $placeholder as $ph by $placeholder/@jf:stream/string() as $stream
    return 
      element jf:parallel {
        attribute jf:stream-origin { $stream },
        $ph
      }
  }
};

(:~ Copy the full context if $full-context is true(), 
 : otherwise only copy if it changed.
 : @param $tunnel $tunnel("full-context") indicates whether the 
 :    full context should be copied 
 :)
declare function rslv:resolve-internal-copy-context(
  $e as element(),
  $tunnel as map(xs:string, item()*)
  ) as attribute()* {
  let $attributes as attribute()* := $e/(@* except @xml:id)
  return
    if ($tunnel("full-context"))
    then
      common:copy-attributes-and-context($e, $attributes, $tunnel)
    else 
      common:copy-attributes-and-context-if-changed($e, $attributes, $tunnel)
};  