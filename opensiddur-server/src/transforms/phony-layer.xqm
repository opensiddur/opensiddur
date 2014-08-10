xquery version "3.0";
(:~
 : Act on "condition" and "set" links:
 : This must be run on the original data because it relies on having the reference index
 : If the condition/setting applies inside the streamText, make a new phony layer of jf:conditional/jf:set elements per condition
 : If the condition applies inside j:layer or on j:streamText, put an @jf:conditional/@jf:set attribute on the element
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

(:~ return the condition/set links that apply to the document :)
declare function phony:doc-condition-links(
    $n as node()
    ) as element(tei:link)* {
    root($n)//j:links/tei:link[@type=("condition","set")]|
        root($n)//j:links/tei:linkGrp[@type=("condition","set")]/tei:link[not(@type)]
};

declare function phony:j-streamText(
    $e as element(j:streamText),
    $params as map
    ) as element(j:streamText) {
    let $conditions := ridx:query(phony:doc-condition-links($e), $e, 1, false())
    let $conditionals := $conditions[@type="condition"]
    let $settings := $conditions[@type="set"]
    return
        element j:streamText {
            $e/@*,
            if (exists($conditionals))
            then ( 
                attribute jf:conditional {
                    string-join(
                        for $link in $conditionals
                        return tokenize($link/@target, '\s+')[2],
                        ' '
                    )
                },
                let $instructions := 
                    for $link in $conditionals
                    return tokenize($link/@target, '\s+')[3]
                where exists($instructions)
                return
                    attribute jf:conditional-instruction {
                        string-join($instructions, ' ')
                    }
            )
            else (),
            if (exists($settings))
            then
                attribute jf:set {
                    string-join(
                        for $link in $settings
                        return tokenize($link/@target, '\s+')[2],
                        ' '
                    )
                }
            else (),
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
    let $conditions := 
        if (exists($layer-ancestor) or exists($stream-ancestor) or $e instance of element(j:option))
        then 
            (: if a condition applies to the whole layer/concurrent section, it applies to all its constituents :)
            ridx:query(phony:doc-condition-links($e), 
                $e|(
                    if ($e/parent::j:layer) then ($concurrent-ancestor, $layer-ancestor) else ()
                ), 1, false())
        else ()
    let $conditionals := $conditions[@type="condition"]
    let $settings := $conditions[@type="set"]
    return
        element {QName(namespace-uri($e), name($e))}{
            $e/@*,
            if (exists($conditionals))
            then (
                attribute jf:conditional {
                    string-join(
                        for $link in $conditionals
                        return tokenize($link/@target, '\s+')[2],
                        ' '
                    )
                },
                let $instructions := 
                    for $link in $conditionals 
                    return tokenize($link/@target, '\s+')[3]
                where exists($instructions[.])
                return
                    attribute jf:conditional-instruction {
                        string-join($instructions, ' ')
                    }
            )
            else (),
            if (exists($settings))
            then
                attribute jf:set {
                    string-join(
                        for $link in $settings
                        return tokenize($link/@target, '\s+')[2],
                        ' '
                    )
                }
            else (),
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
            let $condition-links := phony:doc-condition-links($e)
            let $phony-layers := ( 
                phony:phony-layer-from-conditionals(
                    $condition-links[@type="condition"], $params, "conditional"),
                phony:phony-layer-from-conditionals(
                    $condition-links[@type="set"], $params, "set")
            )
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
        let $condition-links := phony:doc-condition-links($e)
        let $conditional-links := $condition-links[@type="condition"]
        let $settings-links := $condition-links[@type="set"]
        return (
            phony:phony-layer-from-conditionals($conditional-links, $params, "conditional"),
            phony:phony-layer-from-conditionals($settings-links, $params, "set")
        )
    }
};

declare function phony:phony-layer-from-conditionals(
    $e as element(tei:link)*,
    $params as map,
    $phony-type as xs:string
    ) as element(j:layer)* {
    for $link at $n in $e
    where $link/@type=("condition","set")
    return
        let $targets := tokenize($link/@target, '\s+')
        let $dest := uri:fast-follow($targets[1], $link, 0) (: follow only 1 step -- dest might be a ptr :)
        where exists($dest[1]/parent::j:streamText) 
        return
            element j:layer {
                attribute type { "phony-" || $phony-type },
                attribute xml:id { "phony-" || $phony-type || "-" || string($n) },
                element {"jf:" || $phony-type } {
                    attribute { "jf:" || $phony-type } { $targets[2] },
                    if ($phony-type="conditional" and $targets[3])
                    then attribute jf:conditional-instruction { $targets[3] }
                    else (),
                    element tei:ptr { attribute target { $targets[1] } }
                }
            } 
};
