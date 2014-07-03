xquery version "3.0";
(:~
 : Combine multiple documents into a single all-encompassing 
 : JLPTEI document
 :
 : Open Siddur Project
 : Copyright 2013-2014 Efraim Feinstein 
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

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

declare function combine:combine-document(
  $doc as document-node(),
  $params as map
  ) as document-node() {
  combine:combine($doc, $params)
};

declare function combine:combine(
  $nodes as node()*,
  $params as map
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
        return
            typeswitch($node)
            case element(tei:TEI)
            return combine:tei-TEI($node, $params)
            case element(tei:ptr)
            return combine:tei-ptr($node, $updated-params)
            (: TODO: add other model.resourceLike elements above :)
            case element(jf:unflattened)
            return combine:jf-unflattened($node, $updated-params)
            default (: other element :) 
            return combine:element($node, $updated-params) 
    default return $node
};

(:~ TEI is the root element :)
declare function combine:tei-TEI(
  $e as element(tei:TEI),
  $params as map
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

(:~ equivalent of a streamText, check for redirects :)
declare function combine:jf-unflattened(
  $e as element(jf:unflattened),
  $params as map
  ) as element(jf:combined) {
  element jf:combined {
    $e/@*,
    if ($e/@type="parallel")
    then
        (: parallel texts cannot be redirected :) 
        combine:combine($e/node(), $params)
    else 
        (: determine if we need a translation redirect
         : this code will only result in a redirect if the translation settings are 
         : set in the same file as the streamText
         :)
        let $redirect := combine:translation-redirect($e, $e, $params)
        return
            if (exists($redirect))
            then $redirect
            else combine:combine($e/node(), $params)
  } 
};

declare function combine:element(
  $e as element(),
  $params as map
  ) as element() {
  element {QName(namespace-uri($e), name($e))}{
    $e/(@* except (@uri:*, @xml:id)),
    if ($e/@xml:id)
    then attribute jf:id { $e/@xml:id/string() }
    else (),
    combine:combine($e/node() ,$params)
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
  let $document-uri := 
    mirror:unmirror-path(
      $format:unflatten-cache,
      ( 
        document-uri(root($new-doc-nodes[1])), 
        ($new-doc-nodes[1]/@uri:document-uri)
      )[1]
    )
  return (
    (: document (as API source ), base URI?, language, source(?), 
     : license, contributors :)
    attribute jf:document { data:db-path-to-api($document-uri) },
    attribute jf:license { root($new-doc-nodes[1])//tei:licence/@target },
    combine:new-context-attributes($context, $new-doc-nodes)
  )
};

declare function combine:new-document-params(
    $new-doc-nodes as node()*,
    $params as map
    ) as map {
    combine:new-document-params($new-doc-nodes, $params, false())
};

(:~ change parameters as required for entry into a new document
 : manages "combine:unmirrored-doc", "combine:setting-links" 
 : 
 : @param $new-doc-nodes The newly active document
 : @param $params Already active parameters
 : @param $is-redirect If a redirect is going into force, then 2 documents' params will be simulataneously active.  : In that case, combine:unmirrored-doc is added to, not replaced. The redirect is always second.
 :)
declare function combine:new-document-params(
  $new-doc-nodes as node()*,
  $params as map,
  $is-redirect as xs:boolean
  ) as map {
    let $unmirrored-path := 
        mirror:unmirror-path(
            $format:unflatten-cache, 
            document-uri(root($new-doc-nodes[1])))
    let $unmirrored-doc := doc($unmirrored-path)
    let $new-setting-links := $unmirrored-doc//tei:link[@type="set"]
    let $all-setting-links := ($params("combine:setting-links"), $new-setting-links)
    let $new-params := map:new((
        $params,
        map { 
            "combine:unmirrored-doc" := 
                if ($is-redirect)
                then ($params("combine:unmirrored-doc"), $unmirrored-doc)
                else $unmirrored-doc,
            "combine:setting-links" := $all-setting-links
        }
    ))
    return
        combine:update-params($new-doc-nodes[1], $new-params)
}; 

(:~ update parameters are required for any new context :)
declare function combine:update-params(
  $node as node()?,
  $params as map
  ) as map {
  combine:update-settings-from-standoff-markup($node, $params, true())
};

(:~ update parameters with settings from standoff markup.
 : feature structures are represented by type->name := value
 : @param $params uses the combine:setting-links parameter, maintains the combine:settings parameter
 : @param $new-context true() if this is a new context 
 :)
declare function combine:update-settings-from-standoff-markup(
    $e as node(),
    $params as map,
    $new-context as xs:boolean
    ) as map {
    let $base-context :=
        if ($new-context)
        (: this is more complex --
            need to handle overrides, so each of these ancestors has to be treated separately, and in document order
         :)
        then $e/ancestor-or-self::*[@jf:id|@xml:id][1]
        else if (exists($e/(@jf:id|@xml:id)))
        then $e
        else ()
    return
        if (exists($base-context))
        then
            map:new((
                $params,
                map {
                    "combine:settings" := map:new((
                        $params("combine:settings"),
                        let $unmirrored := 
                            if (
                                exists($base-context/self::jf:unflattened[@type="parallel"]) 
                                or exists($base-context/self::jf:parallelGrp)
                                or exists($base-context/self::jf:parallel)
                            ) 
                            then
                                (: use the settings from the linkage file :) 
                                $params("combine:unmirrored-doc")[2]//id($base-context/(@xml:id, @jf:id)[1]) 
                            else
                                (: use the settings from the original file :) 
                                $params("combine:unmirrored-doc")[1]//id($base-context/(@xml:id, @jf:id)[1])
                        for $standoff-link in 
                            ridx:query($params("combine:setting-links"), $unmirrored, 1, $new-context)
                        let $link-target := tokenize($standoff-link/(@target|@targets), '\s+')[2]
                        let $link-dest := uri:fast-follow($link-target, $unmirrored, uri:follow-steps($unmirrored))
                        where $link-dest instance of element(tei:fs)
                        return combine:tei-fs-to-map($link-dest, $params)
                    ))
                } 
            ))
        else $params 
};

declare %private function combine:tei-featureVal-to-map(
    $fnodes as node()*,
    $params as map
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
        case text() return element tei:string { string($node) }
        default return ()
}; 

(:~ convert a tei:fs to an XQuery map
 : The key is fsname->fname. The value is always one or more tei:string elements.
 :)
declare function combine:tei-fs-to-map(
    $e as element(tei:fs),
    $params as map
    ) as map {
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
    $params as map
    ) as node()* {
    let $active-translation := 
        let $s := $params("combine:settings")
        where exists($s)
        return $s("opensiddur->translation")
    let $destination-stream-mirrored := $destination[1]/ancestor-or-self::jf:unflattened
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
        let $destination-domain := 
            replace(
                data:db-path-to-api(document-uri(root($destination-stream))) || "#" || 
                    ($destination-stream/(@xml:id, @jf:id, flatten:generate-id(.)))[1],
                "(/exist/restxq)?/api", "")
        let $mirrored-translation-doc := 
            let $translated-stream-root := root($translated-stream-unmirrored)
            let $deps := format:unflatten-dependencies($translated-stream-root, map {})
            return format:unflatten($translated-stream-root, map {}, $translated-stream-root)
        let $destination-stream-domain := $mirrored-translation-doc//jf:unflattened[@jf:domain=$destination-domain]
        let $redirect-begin :=
            if ($destination[1] instance of element(jf:unflattened))
            then $destination-stream-domain
            else $destination-stream-domain//jf:parallel[@domain=$destination-domain]/*[@jf:id=$destination/@jf:id][1]/ancestor::jf:parallelGrp
        let $redirect-end :=
            if ($destination[last()] instance of element(jf:unflattened))
            then $destination-stream-domain
            else $destination-stream-domain//jf:parallel[@domain=$destination-domain]/*[@jf:id=$destination/@jf:id][last()]/ancestor::jf:parallelGrp
        let $redirect := 
            $redirect-begin | 
            $redirect-begin/following-sibling::* intersect $redirect-end/preceding-sibling::* |
            $redirect-end
        return (
            combine:new-document-attributes($e, $destination),
            combine:combine(
                $redirect,
                (: new document params looks to the unmirrored doc, so it should go to the unredirected destination too :)
                combine:new-document-params(
                    $redirect, combine:new-document-params($destination, $params)
                )
            )
        )
};

(:~ handle a pointer :)
declare function combine:tei-ptr(
  $e as element(tei:ptr),
  $params as map
  ) as element()+ {
  if ($e/@type = "url")
  then combine:element($e, $params)
  else
    (: pointer to follow. 
     : This will naturally result in more than one jf:ptr per
     : tei:ptr if it has more than one @target, but that's OK.
     :)
    let $targets := tokenize($e/@target, '\s+')
    for $target in $targets
    let $destination := 
      uri:fast-follow(
        $target,
        $e,
        uri:follow-steps($e),
        (),
        true(),
        if (substring-before($target, "#") or not(contains($target, "#")))
        then $format:unflatten-cache
        else ( 
          (: Already in the cache, no need to try to 
          find a cache of a cached document :) 
        )
      )
    return
      element jf:ptr {
        $e/(@* except @target),  (: @target can be inferred :)
        if (
          combine:document-uri($e) = combine:document-uri($destination[1])
        )
        then 
          ((: internal pointer, partial context switch necessary:
            : lang, but not document-uri
           :)
           combine:new-context-attributes($e, $destination),
           combine:combine($destination,
              combine:update-params($destination, $params)
           )
          )
        else (
            (: external pointer... determine if we need to redirect :)
            let $redirected := combine:translation-redirect($e, $destination, $params)
            return
                if (exists($redirected))
                then $redirected
                else
                    (: no translation redirect :) 
                    (
                        combine:new-document-attributes($e, $destination),
                        combine:combine(
                            $destination,
                            combine:new-document-params($destination, $params)
                        )
                    )
            )
      }
};

