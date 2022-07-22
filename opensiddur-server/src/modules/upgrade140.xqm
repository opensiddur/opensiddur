xquery version "3.1";
(: Upgrade to 0.14.0
 :
 : Major changes:
 : 1. Single-reference rule: All anchors must be referenced only once
 : 2. External anchors must be declared 'external' or 'canonical'
 :)

module namespace upg14 = "http://jewishliturgy.org/modules/upgrade140";

import module namespace ridx = 'http://jewishliturgy.org/modules/refindex'
    at "xmldb:///db/apps/opensiddur-server/modules/refindex.xqm";
import module namespace didx="http://jewishliturgy.org/modules/docindex"
    at "xmldb:///db/apps/opensiddur-server/modules/docindex.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

(:~ determine if this database likely needs upgrade (true) or not (false)
 : Determined by having a minimum number of anchors that are marked external or canonical :)
declare function upg14:needs-upgrade(
    $root-collection as xs:string
) as xs:boolean {
    let $anchors := collection($root-collection)//tei:anchor
    return count($anchors) > 1 and (: there is some data:)
            count($anchors[@type=("external", "canonical")]) < 10 (: there are not enough canonical/external anchors :)
};

(:~ heuristic to determine if the link should be called canonical :)
declare function upg14:is-canonical($anchor as element(tei:anchor)) as xs:boolean {
    matches($anchor/@xml:id, "v\d+_seg\d+(_end)?")
};

declare function upg14:get-upgrade-changes-map(
    $root-collection as xs:string
    ) as map(*) {
    map:merge(
        for $anchor in collection($root-collection)//tei:anchor
        let $is-canonical := upg14:is-canonical($anchor)
        let $source-doc := document-uri(root($anchor))
        let $all-references := ridx:query-all($anchor, (), false())
        (: we need to know:
         : what type is each anchor? (internal, external or canonical)
         : which anchors need to be split up?
         : for the anchors that get split up: for each reference, what will the target be rewritten to?
         : anchor_doc#xmlid -> map { type : str, old_id: original id, id: new_xml_id, reference_doc: reference_doc reference_id: node_id }+
         :)
        let $anchor-id := $source-doc || "#" || $anchor/@xml:id/string()
        let $reference-elements :=
            for $reference in $all-references
            (: this will not touch anchors that are unreferenced! :)
            where exists(
                (: this picks up the actual elements that reference the anchor :)
                for $token in tokenize($reference/(@target|@targets|@ref|@domains|@who), "\s+")
                let $fragment := substring-after($token, "#")
                where (
                    if (starts-with($fragment, "range("))
                    then tokenize(substring-before(substring-after($fragment, "("), ")"), ",")=$anchor/@xml:id
                    else $fragment=$anchor/@xml:id
                )
                return $token
            )
            return $reference
        return
            if ($is-canonical)
            then
                (: canonical elements are allowed to be multiply referenced, so the references need not be rewritten :)
                map:entry($anchor-id, map {
                    "type" : "canonical",
                    "id" : $anchor/@xml:id/string(),
                    "old_id" : "",
                    "reference_doc": (),
                    "reference_id" :()
                })
            else
                map:entry($anchor-id,
                    for $reference-element at $ctr in $reference-elements
                    let $type :=
                        if (root($reference-element) is root($anchor))
                        then "internal"
                        else "external"
                    return
                        map {
                            "type": $type,
                            "id" : (
                                if (count($reference-elements) = 1)
                                then $anchor/@xml:id/string()
                                else ($anchor/@xml:id/string() || "_" || string($ctr))
                            ),
                            "old_id" : $anchor/@xml:id/string(),
                            "reference_doc" : document-uri(root($reference-element)),
                            "reference_id" : util:node-id($reference-element)
                        }
                )
        )
};

declare function upg14:do-upgrade-changes($changes as map(*)) {
    for $anchor-id in map:keys($changes)
    let $doc-uri := substring-before($anchor-id, "#")
    let $anchor-doc := doc($doc-uri)
    let $anchor-xml-id := substring-after($anchor-id, "#")
    let $anchor := $anchor-doc//tei:anchor[@xml:id=$anchor-xml-id]
    let $map-entry := $changes($anchor-id)
    let $deletions :=
        for $change in $map-entry
        let $new-type := $change("type")
        let $new-id := $change("id")
        let $old-id := $change("old_id")
        return
            if ($new-type = "canonical" or $new-id = $old-id)
            then update insert attribute type { $new-type } into $anchor
            else (
                let $reference := util:node-by-id(doc($change("reference_doc")), $change("reference_id"))
                let $reference-target-attribute := $reference/(@target|@targets|@ref|@domains|@who)
                return (
                    update insert element tei:anchor {
                        attribute type { $new-type },
                        attribute xml:id { $new-id }
                    } following $anchor,
                    update replace $reference-target-attribute with attribute { name($reference-target-attribute) } {
                        replace($reference-target-attribute/string(), $old-id || ("($|,|\))"), $new-id || "$1")
                    }
                ),
                $anchor
            )
    for $deletion in ($deletions | ())
    return update delete $deletion
};

(: eventually, we want a list like this:
 : document -> anchor xml:id -> list of new anchors (xml:id, type)
 :          -> reference element -> (old target-> new target)
 :)
declare function upg14:do-upgrade($root-collection as xs:string) {
    (: find references to anchors and determine if the anchor supports an external reference :)
    let $log := util:log("info", "Upgrade to 0.14.0: Finding upgrade changes")
    let $changes := upg14:get-upgrade-changes-map($root-collection)
    let $log := util:log("info", "Upgrade to 0.14.0: Found changes: " || string(count(map:keys($changes))))
    return upg14:do-upgrade-changes($changes)
};

declare function upg14:upgrade() {
    if (upg14:needs-upgrade("/db/data"))
    then
        let $log := util:log("info", "Prewriting indexes")
        let $didx-reindex := didx:reindex(collection("/db/data"))
        let $ridx-reindex := ridx:reindex(collection("/db/data"))
        let $log := util:log("info", "Upgrading to 0.14.0")
        let $upgraded := upg14:do-upgrade("/db/data")
        let $log := util:log("info", "Rewriting indexes")
        let $didx-reindex := didx:reindex(collection("/db/data"))
        let $ridx-reindex := ridx:reindex(collection("/db/data"))
        return ()
    else util:log("info", "Upgrading to 0.14.0: No upgrade needed.")
};