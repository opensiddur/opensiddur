xquery version "3.1";
(:~ parallel to layer transform
 : convert j:parallelText/tei:linkGrp into layers that can be flattened and merged 
 : assumes that external dependencies are flattened/phony-layered 
 :
 : Open Siddur Project
 : Copyright 2014 Efraim Feinstein, efraim@opensiddur.org
 : Licensed under the GNU Lesser General Public License, version 3.0
 :)
module namespace pla="http://jewishliturgy.org/transform/parallel-layer";

import module namespace common="http://jewishliturgy.org/transform/common"
    at "../modules/common.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
    at "../modules/data.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
    at "../modules/format.xqm";
import module namespace mirror="http://jewishliturgy.org/modules/mirror"
    at "../modules/mirror.xqm";
import module namespace flatten="http://jewishliturgy.org/transform/flatten"
    at "flatten.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

declare function pla:parallel-layer-document(
    $doc as document-node(),
    $params as map(*)
    ) as document-node() {
    document {
        let $pt := $doc//j:parallelText
        return
            if (exists($pt))
            then
                element jf:parallel-document {
                    attribute jf:id { ($pt/@xml:id, flatten:generate-id($pt))[1] },
                    $pt/(@* except @xml:id, tei:idno),
                    for $domain in tokenize($doc//j:parallelText/tei:linkGrp/@domains, '\s+')
                    let $domain-doc-orig := data:doc(substring-before($domain, '#'))
                    let $domain-document := format:phony-layer($domain-doc-orig, $params, $domain-doc-orig)
                    let $params := map { "pla:domain" := $domain }
                    let $layer := pla:tei-linkGrp($pt/tei:linkGrp, $params)
                    return pla:add-layer($domain-document, $layer, $params)
                }
            else $doc/*
    }
};

declare function pla:add-layer(
    $nodes as node()*,
    $layer as element(j:layer),
    $params as map(*)
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case document-node() return pla:add-layer($node/node(), $layer, $params)
        case element() return
            element { QName(namespace-uri($node), name($node)) } {
                $node/(@* except @xml:id),
                if ($node/@xml:id)
                then attribute jf:id { $node/@xml:id/string() }
                else (),
                if ($node instance of element(tei:TEI))
                then 
                    let $domain-doc := substring-before($params("pla:domain"), '#') 
                    return ( 
                        attribute jf:document { $domain-doc },
                        attribute xml:base { $domain-doc }
                    )
                else (),
                pla:add-layer($node/node(), $layer, $params),
                if ($node instance of element(j:concurrent)) 
                then $layer
                else if ($node instance of element(tei:text)
                        and empty($node/j:concurrent))
                then
                    element j:concurrent {
                        $layer
                    }
                else ()
            }
        default return $node
};

declare function pla:tei-linkGrp(
    $e as element(tei:linkGrp),
    $params as map(*)
    ) as element(j:layer) {
    element j:layer {
        attribute type { "parallel" },
        attribute jf:id { ($e/@xml:id, flatten:generate-id($e))[1]  },
        $e/(@* except @xml:id),
        let $domains := tokenize($e/@domains, "\s+")
        let $this-domain := index-of($domains, $params("pla:domain"))
        for $link in $e/tei:link
        return 
            element jf:parallelGrp {
                flatten:copy-attributes($link),
                for $target at $nt in tokenize($link/@target, "\s+")
                where $nt = $this-domain
                return
                    element jf:parallel {
                        attribute domain { $domains[$nt] },
                        element tei:ptr {
                            attribute target { '#' || substring-after($target, '#') }
                        }
                    }
            }
    }
};
