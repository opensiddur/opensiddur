xquery version "3.1";
(:~
 : Combine multiple documents into a single all-encompassing 
 : JLPTEI document
 : Also add late-binding concerns, like transliteration
 :
 : Open Siddur Project
 : Copyright 2013-2014,2016 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 :)
module namespace combine="http://jewishliturgy.org/transform/combine";

import module namespace common="http://jewishliturgy.org/transform/common"
  at "../modules/common.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "../modules/data.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "../modules/follow-uri.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "../modules/format.xqm";
import module namespace mirror="http://jewishliturgy.org/modules/mirror"
  at "../modules/mirror.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "../modules/refindex.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "../modules/debug.xqm";
import module namespace cond="http://jewishliturgy.org/transform/conditionals"
  at "conditionals.xqm";
import module namespace flatten="http://jewishliturgy.org/transform/flatten"
  at "flatten.xqm";
import module namespace translit="http://jewishliturgy.org/transform/transliterator"
  at "translit/translit.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";
declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";

declare function combine:combine-document(
  $doc as document-node(),
  $params as map(*)
  ) as document-node() {
  combine:combine($doc, $params)
};

declare function combine:combine(
  $nodes as node()*,
  $params as map(*)
  ) as node()* {
  for $node in $nodes
  return
    typeswitch($node)
    case document-node() 
    return document { combine:combine($node/node(), $params)}
    case element(tei:teiHeader)
    return $node
    case element()
    return
        let $updated-params := combine:update-settings-from-standoff-markup($node, $params, false())
        let $updated-params := combine:evaluate-conditions($node, $updated-params)
        let $conditional-layer-id := combine:get-conditional-layer-id($node, $updated-params)
        let $instruction := $updated-params("combine:conditional-instruction")
        let $updated-params := map:remove($updated-params, "combine:conditional-instruction")
        (: handling conditionals:
            if $e/@jf:layer-id and combine:conditional-layers = OFF, NO, combine:combine($node/node(), $updated-params)
            else if combine:conditional-result = OFF, NO -> () MAYBE -> evaluate instruction and add it
        :)
        return
            if (
                $node/@jf:layer-id 
                and $updated-params("combine:conditional-layers")($conditional-layer-id)=("NO", "OFF")
            )
            then
                if ($node/descendant::*[@jf:stream])
                then combine:combine($node/node(), $updated-params)
                else ()
            else if (not($updated-params("combine:conditional-result") = ("OFF", "NO")))
            then
                let $ret := 
                    typeswitch($node)
                    case element(tei:TEI)
                    return combine:tei-TEI($node, $params)
                    case element(tei:ptr)
                    return combine:tei-ptr($node, $updated-params)
                    (: TODO: add other model.resourceLike elements above :)
                    case element(jf:unflattened)
                    return combine:jf-unflattened($node, $updated-params)
                    case element(jf:parallelGrp)
                    return combine:jf-parallelGrp($node, $updated-params)
                    case element(j:segGen)
                    return combine:j-segGen($node, $updated-params)
                    case element(tei:seg)
                    return combine:tei-seg($node, $updated-params)
                    default (: other element :) 
                    return combine:element($node, $updated-params)
                let $annotation-sources := (
                    $instruction,
                    $node/@jf:annotation,
                    $node/self::jf:unflattened/ancestor::jf:parallel-document//jf:unflattened[not(. is $node)]/@jf:annotation
                )
                return
                    if (exists($annotation-sources) and 
                        not($node[@jf:part]/preceding::*[@jf:part=$node/@jf:part]))
                    then
                        element {QName(namespace-uri($ret), name($ret))}{
                            $ret/@*,
                            for $al in $annotation-sources,
                                $an in tokenize($al, "\s+")
                            return 
                                combine:follow-pointer(
                                    $al/parent::*, 
                                    $an, $updated-params, 
                                    element jf:annotated { () },
                                    if ($al is $instruction) 
                                    then () 
                                    else combine:include-annotation#3
                                ),
                            $ret/node()
                        }
                    else $ret 
            else ()
    default return $node
};

(:~ TEI is the root element :)
declare function combine:tei-TEI(
  $e as element(tei:TEI),
  $params as map(*)
  ) as element(tei:TEI) {
  element { QName(namespace-uri($e), name($e)) }{
    $e/@*,
    combine:new-document-attributes((), $e),
    combine:combine(
      $e/node(), 
      combine:new-document-params($e, $params)
    )
  }
}; 

(:~ styles are set using the opensiddur->style parameter
 : the content points to a style document
 : @return a @jf:style attribute if the opensiddur->style parameter is set and 
 : something to prevent every element from having jf:style
 :)
declare function combine:associate-style(
    $e as element(),
    $params as map(*)
    ) as node()? {
    let $s := $params("combine:settings")
    where empty($params("combine:styled")) and exists($s) and $s("opensiddur->style")
    return
        attribute jf:style { normalize-space($s("opensiddur->style")) }
};

(: call this after associate-style :)
declare function combine:unset-style(
    $params as map(*)
    ) as map(*) {
    map:new(($params, map { "combine:styled" : 1 }))
};

(:~ equivalent of a streamText, check for redirects, add style if necessary :)
declare function combine:jf-unflattened(
  $e as element(jf:unflattened),
  $params as map(*)
  ) as element(jf:combined) {
  let $new-params := combine:unset-style($params)
  return
    element jf:combined {
      $e/@*,
      combine:associate-style($e, $params),
      if ($e/ancestor::jf:parallel-document)
      then
          (: parallel texts cannot be redirected :)
          combine:combine($e/node(), $new-params)
      else 
          (: determine if we need a translation redirect
           : this code will only result in a redirect if the translation settings are 
           : set in the same file as the streamText
           :)
          let $redirect := combine:translation-redirect($e, $e, $new-params)
          return
              if (exists($redirect))
              then $redirect
              else combine:combine($e/node(), $new-params)
    } 
};

(:~ seg handling: if the segment is inside a stream (or parallelGrp) directly and transliteration is on, 
 : it should be turned into a jf:transliterated/(tei:seg , tei:seg[@type=transliterated])
 :)
declare function combine:tei-seg(
  $e as element(tei:seg),
  $params as map(*)
  ) as element() {
  let $combined := combine:element($e, $params)
  let $transliterated := 
    if ($e/@jf:stream)
    then combine:transliterate-in-place($combined, $e, $params)
    else ()
  return
    if (exists($transliterated))
    then 
      element jf:transliterated {
        $combined,
        element tei:seg {
          $transliterated/(@* except (@type, @jf:id, @jf:stream)),
          attribute type { "transliterated" },
          $transliterated/node()
        }
      }
    else $combined
};

declare function combine:j-segGen(
  $e as element(j:segGen),
  $params as map(*)
  ) as element() {
  let $combined := combine:element($e, $params)
  let $transliterated := combine:transliterate-in-place($combined, $e, $params)
  return
    ($transliterated, $combined)[1]
};

declare function combine:element(
  $e as element(),
  $params as map(*)
  ) as element() {
  element {QName(namespace-uri($e), name($e))}{
    $e/(@* except (@uri:*, @xml:id)),
    if ($e/@xml:id)
    then attribute jf:id { $e/@xml:id/string() }
    else (),
    combine:combine($e/node() ,$params)
  }
};

(:~ a parallelGrp has to align the parallel from here and from the other parallel file :)
declare function combine:jf-parallelGrp(
    $e as element(jf:parallelGrp),
    $params as map(*)
    ) as element(jf:parallelGrp) {
    element jf:parallelGrp {
        $e/@*,
        combine:combine($e/node(), $params),
        let $this-parallelGrp := count($e/preceding-sibling::jf:parallelGrp) + 1
        let $other-parallel-doc := root($e)/*/tei:TEI[not(. is $e/ancestor::tei:TEI)]
        for $parallel in $other-parallel-doc//jf:unflattened/jf:parallelGrp[$this-parallelGrp]/jf:parallel
        return
            element jf:parallel {
                combine:new-document-attributes($e, $parallel),
                $parallel/@*,
                combine:combine($parallel/node(), combine:new-document-params($parallel, $params))
            }
    }
};

(:~ attributes that change on any context switch :)
declare function combine:new-context-attributes(
  $context as node()?,
  $new-context-nodes as node()*
  ) as node()* {
  let $new-lang-node := $new-context-nodes[not(@xml:lang)][1]
  let $new-language := (
    $new-lang-node/@uri:lang/string(),
    if ($new-lang-node) then common:language($new-lang-node) else ()
  )[1]
  return
    if (
      $new-language and 
      ($context and common:language($context) != $new-language))
    then 
      attribute xml:lang { $new-language }
    else ()
};

(:~ return the children (attributes and possibly other nodes)
 : that should be added when a document boundary is crossed 
 :)
declare function combine:new-document-attributes(
  $context as node()?,
  $new-doc-nodes as node()*
  ) as node()* {
  let $document-path := 
    if ($new-doc-nodes[1]/ancestor::jf:parallel-document)
    then
        (: parallel documents are guaranteed to have a @jf:document attribute :)
        $new-doc-nodes[1]/ancestor::*[@jf:document][1]/@jf:document/string()
    else
        let $uri := 
            ( 
              document-uri(root($new-doc-nodes[1])), 
              ($new-doc-nodes[1]/@uri:document-uri)
            )[1]
        return
          replace(
              data:db-path-to-api(
                  mirror:unmirror-path(
                    (: most of the time, the document will be from unflatten; for inline ptr inclusions, it will be from flatten;
                     this is a more or less generic way to get the cache 
                    :)
                    string-join(subsequence(tokenize($uri, "/"), 1, 4), "/"),
                    $uri
                  )
              ), "^(/exist/restxq)?/api", "")
  return (
    (: document (as API source ), base URI?, language, source(?), 
     : license, contributors :)
    attribute jf:document { $document-path },
    attribute jf:license { common:TEI-root($new-doc-nodes[1])//tei:licence/@target },
    combine:new-context-attributes($context, $new-doc-nodes)
  )
};

declare function combine:new-document-params(
    $new-doc-nodes as node()*,
    $params as map(*)
    ) as map(*) {
    combine:new-document-params($new-doc-nodes, $params, false())
};

(:~ change parameters as required for entry into a new document
 : manages "combine:unmirrored-doc", resets "combine:conditional-layers" 
 : 
 : @param $new-doc-nodes The newly active document
 : @param $params Already active parameters
 : @param $is-redirect If a redirect is going into force, then 2 documents' params will be simulataneously active.  : In that case, combine:unmirrored-doc is added to, not replaced. The redirect is always second.
 :)
declare function combine:new-document-params(
  $new-doc-nodes as node()*,
  $params as map(*),
  $is-redirect as xs:boolean
  ) as map(*) {
    let $unmirrored-doc := 
        if ($new-doc-nodes[1]/ancestor::jf:parallel-document)
        then
            data:doc($new-doc-nodes[1]/ancestor::tei:TEI/@jf:document)
        else 
          let $uri :=
                (document-uri(root($new-doc-nodes[1])), 
                $new-doc-nodes[1]/@uri:document-uri)[1]
          return
            doc(
                mirror:unmirror-path(
                    string-join(subsequence(tokenize($uri, "/"), 1, 4), "/"),
                    $uri 
                    )
            )
    let $new-params := map:new((
        $params,
        map { 
            "combine:unmirrored-doc" :
                if ($is-redirect)
                then ($params("combine:unmirrored-doc"), $unmirrored-doc)
                else $unmirrored-doc,
            "combine:conditional-layers" : map {}
        }
    ))
    return
        combine:update-params($new-doc-nodes[1], $new-params)
}; 

(:~ update parameters are required for any new context :)
declare function combine:update-params(
  $node as node()?,
  $params as map(*)
  ) as map(*) {
  combine:update-settings-from-standoff-markup($node, $params, true())
};

(:~ update parameters with settings from standoff markup.
 : feature structures are represented by type->name := value
 : @param $params maintains the combine:settings parameter
 : @param $new-context true() if this is a new context 
 :)
declare function combine:update-settings-from-standoff-markup(
    $e as node(),
    $params as map(*),
    $new-context as xs:boolean
    ) as map(*) {
    let $real-context :=
        (: if there's a @uri:document-uri, we need to load the real context-equivalent :)
        if ($e/@uri:document-uri)
        then doc($e/@uri:document-uri)//*[@jf:id=$e/@jf:id][1] 
        else $e
    let $base-context :=
        if ($new-context)
        (: this is more complex --
            need to handle overrides, so each of these ancestors has to be treated separately, and in document order
         :)
        then $real-context/ancestor-or-self::*[@jf:set]
        else if (exists($real-context/(@jf:set)))
        then $real-context
        else ()
    return
        if (exists($base-context))
        then
            map:new((
                $params,
                map {
                    "combine:settings" : map:new((
                        $params("combine:settings"),
                        for $context in $base-context,
                            $setting in tokenize($context/@jf:set, '\s+')
                        let $link-dest := uri:fast-follow($setting, $context, uri:follow-steps($context))
                        where $link-dest instance of element(tei:fs)
                        return combine:tei-fs-to-map($link-dest, $params)
                    ))
                } 
            ))
        else $params 
};

declare %private function combine:tei-featureVal-to-map(
    $fnodes as node()*,
    $params as map(*)
    ) as element(tei:string)* {
    for $node in $fnodes
    return 
        typeswitch ($node)
        case element(j:yes) return element tei:string { "YES" }
        case element(j:no) return element tei:string { "NO" }
        case element(j:maybe) return element tei:string { "MAYBE" }
        case element(j:on) return element tei:string { "ON" }
        case element(j:off) return element tei:string { "OFF" }
        case element(tei:binary) return element tei:string { string($node/@value=(1, "true")) }
        case element(tei:numeric) return element tei:string { $node/string() }
        case element(tei:string) return $node
        case element(tei:vColl) return combine:tei-featureVal-to-map($node/element(), $params)
        case element(tei:default) return element tei:string { cond:evaluate($node, $params) }
        case element() return element tei:string { $node/@value/string() }
        case text() return
            (: empty text nodes should not produce values :)
            if (normalize-space($node))
            then element tei:string { string($node) }
            else ()
        default return ()
}; 

(:~ convert a tei:fs to an XQuery map
 : The key is fsname->fname. The value is always one or more tei:string elements.
 :)
declare function combine:tei-fs-to-map(
    $e as element(tei:fs),
    $params as map(*)
    ) as map(*) {
    let $fsname := 
        if ($e/@type) 
        then $e/@type/string() 
        else ("anonymous:" || common:generate-id($e))
    return
        map:new(
            for $f in $e/tei:f
            return 
                map:entry(
                    $fsname || "->" ||
                    (
                        if ($f/@name)
                        then $f/@name/string()
                        else ("anonymous:" || common:generate-id($f))
                    ),
                    combine:tei-featureVal-to-map(
                        if ($f/@fVal)
                        then uri:fast-follow($f/@fVal, $f, -1)
                        else $f/node(),
                        $params
                    )[.]
                ) 
        )
};

(:~ transliterate an element in place
 : @param $e already fully processed element
 : @param $context original context
 : @param $params includes transliteration on/off and table if on
 :)
declare function combine:transliterate-in-place(
  $e as element(),
  $context as element(),
  $params as map(*)
  ) as element()? {
  let $settings := $params("combine:settings")
  where exists($settings) and $settings("opensiddur:transliteration->active")=("ON","YES") and $settings("opensiddur:transliteration->table")
  return
    let $table := translit:get-table($context, $settings("opensiddur:transliteration->table"), (), $settings("opensiddur:transliteration->script"))
    let $out-script := $table/tr:lang[common:language($context)=@in]/@out/string()
    where exists($table)
    return 
      let $transliterated := translit:transliterate($e, map { "translit:table" : $table })
      return 
        element {QName(namespace-uri($transliterated), name($transliterated))}{
          $transliterated/(@* except @xml:lang),
          attribute xml:lang { $out-script },
          $transliterated/node()
        }
};

(:~ get the effective document URI of the processing
 : context :)
declare function combine:document-uri(
  $context as node()?
  ) as xs:string? {
  (document-uri(root($context)),
  $context/ancestor-or-self::*
    [(@jf:document-uri|@uri:document-uri)][1]/
      (@jf:document-uri, @uri:document-uri)[1]/string()
  )[1]
};

(: opensiddur->translation contains an ordered list of translations. 
 : return the first existing match of a translation of $destination-stream from that list 
 :)
declare %private function combine:get-first-active-translation(
    $destination-stream as element(),
    $active-translations as element(tei:string)*
    ) as element(tei:linkGrp)? {
    let $this-test := $active-translations[1]/string()
    where exists($this-test)
    return
        let $this-translation :=
            ridx:query(
                collection("/db/data/linkage")//j:parallelText[tei:idno=$this-test]/tei:linkGrp[@domains], 
                $destination-stream)[1]     (: what should happen if more than 1 value is returned?  :)
        return
            if (exists($this-translation))
            then $this-translation
            else combine:get-first-active-translation($destination-stream, subsequence($active-translations, 2))
};

(:~ do a translation redirect, if necessary, from the context $e
 : which may be the same or different from $destination
 :
 : @return the redirected data, or () if no redirect occurred
 :)
declare function combine:translation-redirect(
    $e as element(),
    $destination as node()*,
    $params as map(*)
    ) as node()* {
    let $active-translation := 
        let $s := $params("combine:settings")
        where exists($s)
        return $s("opensiddur->translation")
    let $destination-stream-mirrored := 
        (: check if we're in a copied segment :)
        if ($destination[1]/@uri:document-uri)
        then doc($destination[1]/@uri:document-uri)//jf:unflattened
        else $destination[1]/ancestor-or-self::jf:unflattened
    let $destination-stream := 
        doc(mirror:unmirror-path($format:unflatten-cache, document-uri(root($destination-stream-mirrored))))/
            id($destination-stream-mirrored/@jf:id)
    let $translated-stream-unmirrored :=
        combine:get-first-active-translation($destination-stream, $active-translation)
    where (
        exists($translated-stream-unmirrored) 
        and not($e/parent::jf:parallel) (: special exception for the external pointers in the parallel construct :)
        )
    return
        (: there is a translation redirect :)
        let $destination-doc :=
            replace(
                data:db-path-to-api(document-uri(root($destination-stream))),
                "(/exist/restxq)?/api", "")
        let $destination-domain := 
            replace(
                data:db-path-to-api(document-uri(root($destination-stream))) || "#" || 
                    ($destination-stream/(@xml:id, @jf:id, flatten:generate-id(.)))[1],
                "(/exist/restxq)?/api", "")
        let $translated-stream-root := root($translated-stream-unmirrored)
        let $mirrored-translation-doc := 
            let $deps := format:unflatten-dependencies($translated-stream-root, $params)
            return format:unflatten($translated-stream-root, $params, $translated-stream-root)
        let $destination-stream-domain := $mirrored-translation-doc//tei:TEI[@jf:document=$destination-doc]//jf:unflattened
        let $redirect-begin :=
            if ($destination[1] instance of element(jf:unflattened))
            then $destination-stream-domain
            else $destination-stream-domain//jf:parallel/descendant::*[@jf:id=$destination/@jf:id][1]/ancestor::jf:parallelGrp
        let $redirect-end :=
            if ($destination[last()] instance of element(jf:unflattened))
            then $destination-stream-domain
            else $destination-stream-domain//jf:parallel/descendant::*[@jf:id=$destination/@jf:id][last()]/ancestor::jf:parallelGrp
        let $redirect := 
            $redirect-begin | 
            $redirect-begin/following-sibling::* intersect $redirect-end/preceding-sibling::* |
            $redirect-end
        return (
            combine:new-document-attributes($e, $destination),
            (: make reference to the linkage document :)
            attribute jf:linkage-document { 
                replace(
                    data:db-path-to-api(document-uri($translated-stream-root)),
                    "(/exist/restxq)?/api", ""
                ) },
            combine:combine(
                $redirect,
                (: new document params looks to the unmirrored doc, so it should go to the unredirected destination too :)
                combine:new-document-params(
                    $redirect, combine:new-document-params($destination, $params)
                )
            )
        )
};

(:~ @return true() if the given annotation should be included, false() otherwise :)
declare function combine:include-annotation(
    $node as element(), 
    $annotation as element()*,
    $params as map(*)
    ) as xs:boolean {
    let $a := $annotation[1]
    let $annotation-id := xmldb:decode-uri(xs:anyURI(replace(tokenize(document-uri(root($a)), '/')[last()], '\.xml$', '')))
    let $s := $params("combine:settings")
    return
        exists($s) and (
            $s("opensiddur:annotation->" || $annotation-id)=("YES","ON")
        )
};

declare function combine:follow-pointer(
    $e as element(),
    $destination-ptr as xs:string,
    $params as map(*),
    $wrapping-element as element()
    ) as element() {
    combine:follow-pointer($e, $destination-ptr, $params, $wrapping-element, ())
};


(:~ follow a pointer in the context of the combine operation
 : @param $e The context element from which the pointer is being followed
 : @param $destination-ptr The pointer
 : @param $params Active parameters
 : @param $wrapping-element The element that should wrap the followed pointer and added attributes
 : @param $include-function A function that, given context, a followed pointer, and parameters will determine whether the pointer should indeed be followed (optional) 
 : @return $wrapping-element with attributes and content added or empty sequence if $include-function returns false()
 :)
declare function combine:follow-pointer(
    $e as element(),
    $destination-ptr as xs:string,
    $params as map(*),
    $wrapping-element as element(),
    $include-function as (function(element(), element()*, map(*)) as xs:boolean)?
    ) as element()? {
    (: pointer to follow. 
     : This will naturally result in more than one wrapper per
     : context element if it has more than one @target, but that's OK.
     :)
    let $targets := tokenize($destination-ptr, '\s+')
    for $target in $targets
    let $destination := 
      uri:fast-follow(
        $target,
        $e,
        uri:follow-steps($e),
        (),
        true(),
        if ($e/@type="inline")
        then 
          (: any inline pointer comes from the flatten cache :)
          $format:flatten-cache
        else if (substring-before($target, "#") or not(contains($target, "#")))
        then $format:unflatten-cache
        else ( 
          (: Already in the cache, no need to try to 
          find a cache of a cached document :) 
        )
      )
    where empty($include-function) or $include-function($e, $destination, $params)
    return
      element {QName(namespace-uri($wrapping-element), name($wrapping-element))} {
        $wrapping-element/@*,
        if (
          combine:document-uri($e) = combine:document-uri($destination[1])
        )
        then 
          ((: internal pointer, partial context switch necessary:
            : lang, but not document-uri
           :)
           combine:new-context-attributes($e, $destination[1]),
           combine:combine($destination,
              combine:update-params($destination[1], $params)
           )
          )
        else (
            (: external pointer... determine if we need to redirect :)
            let $unflattened :=
                if ($destination[1]/@uri:document-uri)
                then doc($destination[1]/@uri:document-uri)//jf:unflattened
                else $destination[1]/ancestor-or-self::jf:unflattened
            let $redirected := 
                if ($unflattened)
                then
                    (: only unflattened can have a parallel text :) 
                    combine:translation-redirect($e, $destination, $params)
                else ()
            return
                if (exists($redirected))
                then $redirected
                else
                    (: no translation redirect :) 
                    (
                        combine:new-document-attributes($e, $destination[1]),
                        combine:combine(
                            $destination,
                            combine:new-document-params($destination[1], $params)
                        )
                    )
            )
      }

};

(:~ handle a pointer :)
declare function combine:tei-ptr(
  $e as element(tei:ptr),
  $params as map(*)
  ) as element()+ {
  if ($e/@type = "url")
  then combine:element($e, $params)
  else 
    combine:follow-pointer(
        $e, $e/@target/string(), $params, 
        element jf:ptr {
            $e/(@* except @target)
        }
    )
};

declare function combine:get-conditional-layer-id(
    $e as element(),
    $params as map(*)
    ) as xs:string? {
    $params("combine:unmirrored-doc")[1] || "#" || $e/@jf:layer-id
};

(:~ evaluate any conditions involving the current element, which can occur if:
 :  * the element itself is jf:conditional
 :  * the element has an @jf:conditional attribute
 :  * the element derives from a layer that is subject to a condition 
 :  * the element is j:option/@xml:id and the opensiddur:option/[document]#[xmlid] feature exists 
 :
 : @return an updated parameter map with the following parameters updated:
 :  combine:conditional-result: YES, NO, MAYBE, ON, OFF if the element is subject to a conditional; empty if not
 :  combine:conditional-layers: a map of document#layer-id->conditional result
 :  combine:conditional-instruction: the attribute node that points to the instruction
 :)
declare function combine:evaluate-conditions(
    $e as element(),
    $params as map(*)
    ) as map(*) {
    let $this-element-condition-result :=
        let $conditions := (
            for $condition in tokenize($e/@jf:conditional, '\s+')
            return uri:fast-follow($condition, $e, uri:follow-steps($e)),
            if ($e instance of element(j:option) and $e/@jf:id and not($e/@jf:conditional))
            then 
                let $option-feature-name := $params("combine:unmirrored-document")[1] || "#" || $e/@jf:id/string()
                let $feature-value := cond:get-feature-value($params, "opensiddur:option", $option-feature-name)
                where exists($feature-value)
                return
                    <tei:fs type="opensiddur:option">
                        <tei:f name="{$option-feature-name}"><j:yes/></tei:f>
                    </tei:fs>
            else ()
            )
        where exists($conditions)
        return
            cond:evaluate(
                if (count($conditions) > 1)
                then element j:all { $conditions }
                else $conditions,
                $params
            )
    let $conditional-layer-id := combine:get-conditional-layer-id($e, $params)
    let $conditional-layer-result :=
        if (not($e instance of element(jf:conditional) 
                or $e instance of element(j:option)) 
            and $e/@jf:layer-id)
        then 
            let $conditional-layer := $params("combine:conditional-layers")
            where exists($conditional-layer)
            return $conditional-layer($conditional-layer-id)
        else ()
    return 
        map:new((
            $params,
            map {
                (: if a layer is not ON/YES, then the layer result takes precedence :)
                "combine:conditional-result" : (
                    $conditional-layer-result,
                    $this-element-condition-result
                )[1],
                "combine:conditional-instruction" :
                    $e/@jf:conditional-instruction
            },
            (: record if the layer is being turned off :)
            if (not($e instance of element(jf:conditional) 
                    or $e instance of element(j:option)) 
                and $e/@jf:layer-id)
            then
                map {
                    "combine:conditional-layers" : map:new((
                        $params("combine:conditional-layers"), 
                        map {
                            $conditional-layer-id : (
                                $conditional-layer-result, 
                                $this-element-condition-result[not(.=("YES","ON"))]
                            )[1]
                        }
                    ))
                }
            else ()
        ))
};

