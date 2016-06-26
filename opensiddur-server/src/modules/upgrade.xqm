xquery version "3.0";
(:~ effect schema upgrades 
 : 
 : Open Siddur Project
 : Copyright 2014-2015 Efraim Feinstein
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

(: not strictly speaking a schema change:
 : any resource in /db/data with a name containing ,;= will be renamed.
 : NOTE: if we expected any links to such files, the links would also have to be changed.
 : Fortunately, we do not expect external links. If they are found, they will have to 
 : be manually corrected.
 :)
declare function upg:schema-changes-0-8-0() {
    for $document in collection("/db/data")
    let $collection := util:collection-name($document)
    let $resource := util:document-name($document)
    let $decoded := xmldb:decode($resource)
    let $resource-number := 
        let $n := tokenize($decoded, '-')[last()]
        where matches($decoded, "-\d+\.xml$") and matches($n, "\d+\.xml")
        return substring-before($n, '.xml')
    let $title := 
        if (starts-with($collection, "/db/data/sources"))
        then src:title-function($document)
        else if (starts-with($collection, "/db/data/transliteration"))
        then tran:title-function($document)
        else if (starts-with($collection, "/db/data/outlines"))
        then outl:title-function($document)
        else crest:tei-title-function($document)
    let $new-name := 
        string-join((
            encode-for-uri(replace(replace(normalize-space($title), "\p{M}", ""), "[,;:$=@]+", "-")),
            $resource-number), "-") || ".xml"
    where not(starts-with($collection,"/db/data/user"))
        and not($resource = $new-name) 
        and not($resource = "Born%20Digital.xml")
    return (
        util:log-system-out("Renaming: " || $collection || "/" || $resource || " -> " || $new-name || "&#x0a;using title=" || $title),
        xmldb:rename($collection, $resource, $new-name)
    )
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
        then text:groups(($relatedItem/@target, $relatedItem/@targetPattern)[1], "/(details|stream)/([A-Za-z0-9_]+)")[3] 
        else if ($archive = "books.google.com")
        then text:groups(($relatedItem/@target, $relatedItem/@targetPattern)[1], "id=([A-Za-z0-9_]+)")[2] 
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
    let $uri-title := notes:uri-title-function($document)
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

declare function upg:all-schema-changes() {
    upg:schema-changes-0-7-5(),
    upg:schema-changes-0-8-0(),
    upg:schema-changes-0-8-1(),
    upg:schema-changes-0-9-0()
};
