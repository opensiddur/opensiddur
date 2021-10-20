(: implementation of a merge algorithm for two JLPTEI files
 :
 : Copyright 2021 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
xquery version '3.1';

module namespace merge="http://jewishliturgy.org/modules/merge";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

(:~ merge two XML documents, assuming that we need to preserve $old-doc :)
declare function merge(
    $old-doc as document-node(),
    $new-doc as document-node()
) as document-node() {

};

declare function merge:stream-sequence(
    $nodes as node()*
) {
    for $node in $nodes
    return
        typeswitch($node)
        case text() return
            for $word in tokenize($node, '\s+')
            return text { $word }
        default return $node
};

declare function merge:j-streamText(
    $old-streamText as element(j:streamText)?,
    $new-streamText as element(j:streamText)?
) as element(j:streamText)? {
    if (empty($old-streamText|$new-streamText))
    then ()
    else (
        element j:streamText {
            ($old-streamText/@xml:id, $new-streamText/@xml:id)[1]
            let $old-stream-sequence := stream-sequence($old-streamText/node())
        }
    )
};