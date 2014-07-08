xquery version "3.0";
(:~
 : Act on conditional links:
 : This must be run on the original data because it relies on having the reference index
 : If the condition applies inside the streamText, make a new phony layer of jf:conditional elements per condition
 : If the condition applies inside j:layer or on j:streamText, put an @jf:conditional attribute on the element
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
        case element() return phony:element($node, $params)
        default return phony:phony-layer($node/node(), $params) 
};

(:~ return the condition links that apply to the document :)
declare function phony:doc-condition-links(
    $n as node()
    ) as element(tei:link)* {
    root($n)//j:links/tei:link[@type="condition"]|
        root($n)//j:links/tei:linkGrp[@type="condition"]/tei:link[not(@type)]
};

declare function phony:j-streamText(
    $e as element(j:streamText),
    $params as map
    ) as element(j:streamText) {
    let $conditions := ridx:query(phony:doc-condition-links($e), $e, 1, false())
    return
        element j:streamText {
            $e/@*,
            if (exists($conditions))
            then ( 
                attribute jf:conditional {
                    string-join(
                        for $link in $conditions
                        return tokenize($link/@target, '\s+')[2],
                        ' '
                    )
                },
                let $instructions := 
                    for $link in $conditions
                    return tokenize($link/@target, '\s+')[3]
                where exists($instructions)
                return
                    attribute jf:conditional-instruction {
                        string-join($instructions, ' ')
                    }
            )
            else (),
            $e/node()
        }
};

(:~ activates on elements inside layers :)
declare function phony:element(
    $e as element(),
    $params as map
    ) as element() {
    let $layer-ancestor := $e/ancestor::j:layer
    let $concurrent-ancestor := $layer-ancestor/parent::j:concurrent
    let $conditions := 
        if (exists($layer-ancestor))
        then 
            (: if a condition applies to the whole layer/concurrent section, it applies to all its constituents :)
            ridx:query(phony:doc-condition-links($e), 
                $e|(
                    if ($e/parent::j:layer) then ($concurrent-ancestor, $layer-ancestor) else ()
                ), 1, false())
        else ()
    return
        element {QName(namespace-uri($e), name($e))}{
            $e/@*,
            if (exists($conditions))
            then
                attribute jf:conditional {
                    string-join(
                        for $link in $conditions
                        return tokenize($link/@target, '\s+')[2],
                        ' '
                    )
                }
            else (),
            phony:phony-layer($e/node(), $params)
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
            let $phony-layers := 
                phony:phony-layer-from-conditionals(
                    phony:doc-condition-links($e), $params)
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
        phony:phony-layer-from-conditionals(phony:doc-condition-links($e), $params)
    }
};

declare function phony:phony-layer-from-conditionals(
    $e as element(tei:link)*,
    $params as map
    ) as element(j:layer)* {
    for $link at $n in $e
    where $link/@type="condition"
    return
        let $targets := tokenize($link/@target, '\s+')
        let $dest := uri:fast-follow($targets[1], $link, uri:follow-steps($link))
        where exists($dest[1]/ancestor::j:streamText)
        return
            element j:layer {
                attribute type { "phony" },
                attribute xml:id { "phony-conditional-" || string($n) },
                element jf:conditional {
                    attribute jf:conditional { $targets[2] },
                    if ($targets[3])
                    then attribute jf:conditional-instruction { $targets[3] }
                    else (),
                    element tei:ptr { attribute target { $targets[1] } }
                }
            } 
};
