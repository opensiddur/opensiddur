xquery version "3.1";
(:~ effect schema upgrades 
 : 
 : Open Siddur Project
 : Copyright 2014-2015,2018-2019 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace upg="http://jewishliturgy.org/modules/upgrade";

import module namespace data="http://jewishliturgy.org/modules/data"
    at "data.xqm";
import module namespace crest="http://jewishliturgy.org/modules/common-rest"
    at "common-rest.xqm";
import module namespace notes="http://jewishliturgy.org/api/data/notes"
    at "../api/data/notes.xqm";
import module namespace outl="http://jewishliturgy.org/api/data/outlines"
    at "../api/data/outlines.xqm";
import module namespace src="http://jewishliturgy.org/api/data/sources"
    at "../api/data/sources.xqm";
import module namespace tran="http://jewishliturgy.org/api/transliteration"
    at "../api/data/transliteration.xqm";
import module namespace upg12="http://jewishliturgy.org/modules/upgrade12"
    at "upgrade12.xqm";
import module namespace upg13="http://jewishliturgy.org/modules/upgrade130"
    at "upgrade130.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri"
    at "follow-uri.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

(:~ schema changes for 0.7.5
 : * tei:availability/@status was removed
 : * tei:sourceDesc/tei:link becomes tei:bibl/tei:ptr; 
 :)
declare function upg:schema-changes-0-7-5(
    ) {
    update delete collection("/db/data")//tei:availability/@status,
    for $sourceDescLink in collection("/db/data")//tei:sourceDesc/tei:link
    return
        update replace $sourceDescLink with 
            element tei:bibl {
                element tei:ptr {
                    attribute type { "bibl" },
                    attribute target { tokenize($sourceDescLink/@target, '\s+')[2] } 
                },
                element tei:ptr {
                    attribute type { "bibl-content" },
                    attribute target { tokenize($sourceDescLink/@target, '\s+')[1] } 
                }
            }
};

declare function upg:rename-resources-for-upgrade(
) as map(xs:string, xs:string) {
    map:merge(
        for $document in collection("/db/data")
        let $collection := util:collection-name($document)
        let $resource := util:document-name($document)
        let $decoded := xmldb:decode($resource)
        let $resource-number :=
            let $n := tokenize($decoded, '-')[last()]
            where matches($decoded, "-\d+\.xml$") and matches($n, "\d+\.xml")
            return substring-before($n, '.xml')
        let $log1 := util:log("info", "10:" || $collection || "/" || $resource)
        let $title :=
            data:normalize-resource-title(
                if (starts-with($collection, "/db/data/user"))
                then "ignored"
                else if (starts-with($collection, "/db/data/sources"))
                then src:title-function($document)
                else if (starts-with($collection, "/db/data/transliteration"))
                then tran:title-function($document)
                else if (starts-with($collection, "/db/data/outlines"))
                then outl:title-function($document)
                else crest:tei-title-function($document)
            , false())
        let $log2 := util:log("info", "11:" || $title )
        let $new-name :=
            encode-for-uri($title) || (
                if ($resource-number) then ("-" || $resource-number) else ""
            )
        let $new-resource-name := $new-name || ".xml"
        where not(starts-with($collection,"/db/data/user"))
            and not($resource = $new-resource-name)
        return (
            let $internal-collection := "/" || string-join(subsequence(tokenize($collection, "/"), 3, 2), "/") || "/"
            let $old-internal-uri := $internal-collection || substring-before($resource, '.xml')
            let $new-internal-uri := $internal-collection || $new-name
            let $log := util:log("info","Renaming: " || $collection || "/" || $resource || " -> " || $new-resource-name || "&#x0a;using title=" || $title)
            let $rename := xmldb:rename($collection, $resource, $new-resource-name)
            return map:entry($old-internal-uri, $new-internal-uri)
        )
    )
};

declare function upg:rewrite-resource-links(
    $resource-name-map as map(xs:string, xs:string)
) {
    upg:rewrite-resource-links($resource-name-map, collection("/db/data")//(@target|@targets|@domains|@ref))
};

declare function upg:rewrite-resource-links(
    $resource-name-map as map(xs:string, xs:string),
    $link-data as attribute()*
) {
    for $link-attribute in $link-data
    let $tokenized := tokenize($link-attribute, "\s+")
    let $rewritten := string-join(
        for $token in $tokenized
        let $resource := string(uri:uri-base-resource($token))
        let $fragment := string(uri:uri-fragment($token))
        let $rewritten-resource :=
            if (map:contains($resource-name-map, $resource))
            then $resource-name-map($token)
            else $resource
        return
            string-join(($rewritten-resource, $fragment), '#')
        , " "
    )
    let $log := util:log("info", "21:" || $link-attribute/string() || "->" || $rewritten)
    return
        update replace $link-attribute with (
            attribute { local-name($link-attribute) } { $rewritten }
        )
};

(: not strictly speaking a schema change:
 : any resource in /db/data with a name containing ,;= will be renamed.
 : NOTE: if we expected any links to such files, the links would also have to be changed.
 : Fortunately, we do not expect external links. If they are found, they will have to 
 : be manually corrected.
 : NOTE 2: This will also update for 0.13.0
 :)
declare function upg:schema-changes-0-8-0() {
    let $log1 := util:log("info", 1)
    let $name-map := upg:rename-resources-for-upgrade()
    let $log1 := util:log("info", 2)
    return upg:rewrite-resource-links($name-map)
};

(:~ removal of tei:relatedItem/@type='scan',
 : replaced with tei:idno -- supports Google Books (@type='books.google.com') and Internet Archive (@type='archive.org')
 :)
declare function upg:schema-changes-0-8-1() {
    for $source in collection("/db/data/sources")[descendant::tei:relatedItem]
    let $relatedItem := $source//tei:relatedItem["scan"=@type]
    let $archive := 
        if (contains($relatedItem/(@target || @targetPattern), "books.google.com"))
        then "books.google.com"
        else if (contains($relatedItem/(@target || @targetPattern), "archive.org"))
        then "archive.org"
        else "scan"
    let $id := 
        if ($archive = "archive.org")
        then analyze-string(
                ($relatedItem/@target, $relatedItem/@targetPattern)[1],
                "/(details|stream)/([A-Za-z0-9_]+)")/fn:match/fn:group[@nr=2]/string()
        else if ($archive = "books.google.com")
        then analyze-string(
                ($relatedItem/@target, $relatedItem/@targetPattern)[1],
                "id=([A-Za-z0-9_]+)")/fn:match/fn:group[@nr=1]/string()
        else $relatedItem/@target
    return 
        update replace $relatedItem with 
            element tei:idno {
                attribute type { $archive },
                $id
            }
};

(:~ removal of tei:idno in annotations files, change names of annotation files to be xsd:Names
 :)
declare function upg:schema-changes-0-9-0() {
    update delete collection("/db/data/notes")//j:annotations/tei:idno,
    for $document in collection("/db/data/notes")
    let $collection := util:collection-name($document)
    let $resource := util:document-name($document)
    let $uri-title := crest:tei-title-function($document)
    let $resource-number := 
        let $n := tokenize($resource, '-')[last()]
        where matches($resource, "-\d+\.xml$") and matches($n, "\d+\.xml")
        return substring-before($n, '.xml')
    let $new-name := 
        string-join((
            encode-for-uri(replace(replace(normalize-space($uri-title), "\p{M}", ""), "[,;:$=@]+", "-")),
            $resource-number), "-") || ".xml"
    where not($new-name=$resource)
    return (
        util:log-system-out("Renaming annotation file: " || $collection || "/" || $resource || " -> " || $new-name || "&#x0a;using uri title=" || $uri-title),
        xmldb:rename($collection, $resource, $new-name)
    )
    
};

declare function upg:schema-changes-0-12-0() {
    util:log("info","You must run the schema upgrade to 0.12.0 manually!...")
};

declare function upg:schema-changes-0-13-0() {
    upg13:upgrade-all()
};

declare function upg:all-schema-changes() {
    upg:schema-changes-0-7-5(),
    upg:schema-changes-0-8-0(),
    upg:schema-changes-0-8-1(),
    upg:schema-changes-0-9-0(),
    upg:schema-changes-0-12-0(),
    upg:schema-changes-0-13-0()
};
