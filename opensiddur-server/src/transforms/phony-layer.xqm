xquery version "3.0";
(:~
 : Act on "condition", "set", "note", "instruction", "interp", and "annotation" links:
 : This must be run on the original data because it relies on having the reference index
 : If the condition/setting applies inside the streamText, make a new phony layer of jf:conditional/jf:set elements per condition
 : If the condition applies inside j:layer or on j:streamText, put an @jf:conditional/@jf:set/@jf:note/@jf:instruction/... attribute on the element
 :
 : This transform only makes sense on original text documents. Otherwise, it acts as an identity transform.
 : 
 : Copyright 2014 Efraim Feinstein, efraim@opensiddur.org
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace phony="http://jewishliturgy.org/transform/phony-layer";

import module namespace common="http://jewishliturgy.org/transform/common"
  at "../modules/common.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "../modules/follow-uri.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "../modules/refindex.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

(: keys are the link types, values are the attribute/element they produce :)
declare variable $phony:link-types := map {
    "condition" := "conditional",
    "set" := "set",
    "note" := "annotation",
    "instruction" := "annotation",
    "interp" := "annotation",
    "annotation" := "annotation"
};

declare function phony:phony-layer-document(
    $doc as document-node(),
    $params as map
    ) as document-node() {
    common:apply-at(
        $doc,
        $doc//tei:text[j:streamText],
        phony:phony-layer#2,
        $params
    )
};

declare function phony:phony-layer(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch ($node)
        case document-node() return document { phony:phony-layer($node/node(), $params) }
        case text() return $node
        case comment() return $node
        case element(tei:text) return phony:tei-text($node, $params)
        case element(j:concurrent) return phony:j-concurrent($node, $params)
        case element(j:streamText) return phony:j-streamText($node, $params)
        case element() return phony:element($node, $params, phony:phony-layer#2)
        default return phony:phony-layer($node/node(), $params) 
};

(:~ return the phony-layer eligible links that apply to the document :)
declare function phony:doc-phony-links(
    $n as node()
    ) as element(tei:link)* {
    let $link-types := map:keys($phony:link-types)
    return
        root($n)//j:links/tei:link[$link-types=@type]|
            root($n)//j:links/tei:linkGrp[$link-types=@type]/tei:link[not(@type)]
};

declare function phony:links-to-attributes(
    $phonies as element(tei:link)*
    ) as attribute()* {
    for $phony-link in $phonies
    group by 
        $phony-type := $phony-link/@type/string()
    return (
        attribute { "jf:" || $phony:link-types($phony-type) }{
            string-join(
                for $link in $phony-link
                return tokenize($link/@target, '\s+')[2]
            , ' ')
        },
        let $instructions :=
            for $link in $phony-link["condition"=@type]
            return tokenize($link/@target, '\s+')[3]
        where exists($instructions)
        return
            (: TODO: this is really just an annotation, but it needs to be added to other annotations :) 
            attribute jf:conditional-instruction {
                string-join($instructions, ' ')
            }
    )
};

declare function phony:j-streamText(
    $e as element(j:streamText),
    $params as map
    ) as element(j:streamText) {
    let $phonies := ridx:query(phony:doc-phony-links($e), $e, 1, false())[self::tei:link]
    return
        element j:streamText {
            $e/@*,
            phony:links-to-attributes($phonies),
            phony:inside-streamText($e/node(), $params)
        }
};

declare function phony:inside-streamText(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch ($node)
        case element(j:option) return phony:element($node, $params, phony:inside-streamText#2)
        case element() return
            if ($node/parent::j:streamText)
            then 
                element { QName(namespace-uri($node), name($node)) }{
                    $node/@*,
                    phony:inside-streamText($node/node(), $params)
                }
            else phony:element($node, $params, phony:inside-streamText#2)
        case text() return $node
        case comment() return $node
        case document-node() return document { phony:inside-streamText($node/node(), $params) }
        default return phony:inside-streamText($node/node(), $params)
};

(:~ activates on elements inside layers or j:option inside streamText, which is treated the same way :)
declare function phony:element(
    $e as element(),
    $params as map,
    $caller as function(node()*, map) as node()*
    ) as element() {
    let $layer-ancestor := $e/ancestor::j:layer
    let $stream-ancestor := $e/ancestor::j:streamText[not(. is $e/parent::*)]
    let $concurrent-ancestor := $layer-ancestor/parent::j:concurrent
    let $phonies := 
        if (exists($layer-ancestor) or exists($stream-ancestor) or $e instance of element(j:option))
        then 
            (: if a condition applies to the whole layer/concurrent section, it applies to all its constituents :)
            ridx:query(phony:doc-phony-links($e), 
                $e|(
                    if ($e/parent::j:layer) then ($concurrent-ancestor, $layer-ancestor) else ()
                ), 1, false())[self::tei:link]
        else ()
    return
        element {QName(namespace-uri($e), name($e))}{
            $e/@*,
            phony:links-to-attributes($phonies),
            $caller($e/node(), $params)
        }
};

(:~ add a concurrent section if any additional layers should be added
 : and no concurrent section exists
 :)
declare function phony:tei-text(
    $e as element(tei:text),
    $params as map
    ) as element(tei:text) {
    element tei:text {
        $e/@*,
        phony:phony-layer($e/node(), $params),
        if (empty($e/j:concurrent))
        then
            let $phonies := phony:doc-phony-links($e)
            let $phony-layers := phony:phony-layer-from-links($phonies, $params)
            where exists($phony-layers)
            return 
                element j:concurrent {
                    $phony-layers
                }
        else ()
    }
};

(:~ add a additional layers, if necessary 
 :)
declare function phony:j-concurrent(
    $e as element(j:concurrent),
    $params as map
    ) as element(j:concurrent) {
    element j:concurrent {
        $e/@*,
        phony:phony-layer($e/node(), $params),
        let $phonies := phony:doc-phony-links($e)
        return phony:phony-layer-from-links($phonies, $params)
    }
};

declare function phony:phony-layer-from-links(
    $e as element(tei:link)*,
    $params as map
    ) as element(j:layer)* {
    for $link at $n in $e
    let $phony-type := $phony:link-types(($link/@type,$link/parent::tei:linkGrp/@type)[1]/string())
    return
        let $targets := tokenize($link/@target, '\s+')
        let $dest := uri:fast-follow($targets[1], $link, 0) (: follow only 1 step -- dest might be a ptr :)
        where exists($dest[1]/parent::j:streamText) 
        return
            element j:layer {
                attribute type { "phony-" || $phony-type },
                attribute xml:id { "phony-" || $phony-type || "-" || string($n) },
                element { "jf:" || $phony-type } {
                    attribute { "jf:" || $phony-type } { $targets[2] },
                    if ($phony-type="conditional" and $targets[3])
                    then attribute jf:conditional-instruction { $targets[3] }
                    else (),
                    element tei:ptr { attribute target { $targets[1] } }
                }
            } 
};
