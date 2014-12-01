xquery version "3.0";
(:~ effect schema upgrades 
 : 
 : Open Siddur Project
 : Copyright 2014 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace upg="http://jewishliturgy.org/modules/upgrade";

declare namespace tei="http://www.tei-c.org/ns/1.0";

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
    for $document in collection("/db/data")[matches(util:document-name(.), "%(24|2C|3A|3B|3D)")]
    let $collection := util:collection-name($document)
    let $resource := util:document-name($document)
    let $new-name := replace($resource, "(%(24|2C|3A|3B|3D))+", "-")
    return
        xmldb:rename($collection, $resource, $new-name)
};

declare function upg:all-schema-changes() {
    upg:schema-changes-0-7-5(),
    upg:schema-changes-0-8-0()
};
