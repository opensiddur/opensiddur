xquery version "3.1";
(:~ Transformation for JLPTEI files to 0.12.0+
 : Major changes:
 : 1. Remove `tei:seg` from inside `j:streamText`.
 : 2. All segments with references to them as the beginning of the range (or the only reference) should be replaced with `tei:anchor` before them.
 : 3. All segments with references to them as the end of the range (or only reference) should be replaced with `tei:anchor` after them;
 :    the range pointer should be changed to point to the end instead of the beginning.
 : 4. all internal and external pointers in `j:streamText` must point to `tei:anchor`
 :
 :)
module namespace upg12 = "http://jewishliturgy.org/modules/upgrade12";

import module namespace ridx="http://jewishliturgy.org/modules/refindex"
    at "refindex.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

declare function upg12:upgrade(
        $nodes as node()*
) {
    for $node in $nodes
    return
        typeswitch($node)
        case element(j:streamText) return upg12:j-streamText($node)
        case element() return
            element { xs:QName(namespace-uri($node), name($node)) }{
                $node/@*,
                upg12:upgrade($node/node())
            }
        case text() return $node
        default return $node
};

declare function upg12:j-streamText(
    $e as element(j:streamText)
) as element(j:streamText) {
    element { j:streamText }{
        for $node in $e/node()
        return
            typeswitch($node)
            case element(tei:seg) return upg12:tei-seg($node)
            default return $node
    }
};

declare function upg12:tei-seg(
    $node as element(tei:seg)
) as item()+ {
    let $xmlid := $node/@xml:id
    let $end-xmlid := concat($xmlid, "_end")
    return (
        element tei:anchor {
            attribute xml:id { $xmlid }
        },
        $node/node(),
        element tei:anchor {
            attribute xml:id { $end-xmlid }
        }
    )
};

declare function upg12:tei-ptrlike(
    $node as element()
) {
    element { xs:QName(namespace-uri($node), name($node)) }{
        $node/@* except $node/@target,
        attribute target {

        }
    }
};
