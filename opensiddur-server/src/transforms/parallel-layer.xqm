xquery version "3.0";
(:~ parallel to layer transform
 : convert j:parallelText/tei:linkGrp into layers that can be flattened and merged 
 :
 : Open Siddur Project
 : Copyright 2014 Efraim Feinstein, efraim@opensiddur.org
 : Licensed under the GNU Lesser General Public License, version 3.0
 :)
module namespace pla="http://jewishliturgy.org/transform/parallel-layer";

import module namespace common="http://jewishliturgy.org/transform/common"
    at "../modules/common.xqm";
import module namespace flatten="http://jewishliturgy.org/transform/flatten"
    at "flatten.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

declare function pla:parallel-layer-document(
    $doc as document-node(),
    $params as map 
    ) as document-node() {
    common:apply-at(
        $doc,
        $doc//j:parallelText,
        pla:parallel-layer#2,
        $params
    )
};

declare function pla:parallel-layer(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $n in $nodes
    return
        typeswitch($n)
        case element(j:parallelText) return pla:j-parallelText($n, $params)
        case element(tei:linkGrp) return pla:tei-linkGrp($n, $params)
        case text() return $n
        default return pla:parallel-layer($n/node(), $params)
};

declare function pla:j-parallelText(
    $e as element(j:parallelText),
    $params as map
    ) as element(j:parallelText) {
    element j:parallelText {
        attribute xml:id { ($e/@xml:id, flatten:generate-id($e))[1] },
        $e/(@* except @xml:id, tei:idno),
        pla:parallel-layer($e/tei:linkGrp, $params)
    }
};

declare function pla:tei-linkGrp(
    $e as element(tei:linkGrp),
    $params as map
    ) as element(j:layer) {
    element j:layer {
        attribute type { "parallel" },
        attribute xml:id { ($e/@xml:id, flatten:generate-id($e))[1]  },
        $e/(@* except @xml:id),
        let $domains := tokenize($e/@domains, "\s+")
        for $link in $e/tei:link
        return 
            element jf:parallel-group {
                flatten:copy-attributes($link),
                for $target at $nt in tokenize($link/@target, "\s+")
                return
                    element jf:parallel {
                        attribute domain { $domains[$nt] },
                        element tei:ptr {
                            attribute target { $target }
                        }
                    }
            }
    }
};
