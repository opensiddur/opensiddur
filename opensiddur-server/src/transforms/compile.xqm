xquery version "3.1";
(:~
 : Write lists for a combined document
 :
 : Open Siddur Project
 : Copyright 2014 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 :)
module namespace compile="http://jewishliturgy.org/transform/compile";

import module namespace data="http://jewishliturgy.org/modules/data"
  at "../modules/data.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "../modules/format.xqm";
import module namespace mirror="http://jewishliturgy.org/modules/mirror"
  at "../modules/mirror.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "../modules/debug.xqm";

declare namespace error="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

declare function compile:compile-document(
  $doc as document-node(),
  $params as map(*)
  ) as document-node() {
  compile:compile($doc, $params)
};

declare function compile:compile(
  $nodes as node()*,
  $params as map(*)
  ) as node()* {
  for $node in $nodes
  return
    typeswitch($node)
    case document-node() 
    return document { compile:compile($node/node(), $params)}
    case element(tei:text)
    return compile:tei-text($node, $params)
    case element() 
    return compile:element($node, $params) 
    default return $node
};

declare function compile:element(
  $e as element(),
  $params as map(*)
  ) as element() {
  element {QName(namespace-uri($e), name($e))}{
    $e/@*,
    compile:compile($e/node() ,$params)
  }
};

(: add back matter that's derived from the text's metadata :)
declare function compile:tei-text(
  $e as element(tei:text),
  $params as map(*)
  ) as element(tei:text) {
  let $text-output := compile:element($e, $params)
  return 
    element tei:text {
      $text-output/@*,
      $text-output/(* except tei:back),
      element tei:back {
        $text-output/tei:back/(@*|node()),
        let $api-documents := ($text-output//@jf:document, $text-output//@jf:linkage-document)
        let $unique-documents-db := distinct-values((
                mirror:unmirror-path(       (: this document :)
                  $format:combine-cache,
                  document-uri(root($e))
                ),
                for $doc in $api-documents 
                return data:api-path-to-db($doc)
            ))
        let $unique-documents :=
            for $d in $unique-documents-db
            return doc($d) 
        return (
            (: licensing :)
            compile:license-statements($unique-documents),
            (: contributor list :)
            compile:contributor-list($unique-documents),
            (: bibliography :)
            compile:source-list($unique-documents) 
        )
      }
    }
};

declare function compile:license-statements(
    $documents as document-node()*
    ) as element(tei:div)? {
    let $text-licenses := 
        distinct-values($documents//tei:licence/@target/string())
    let $supported-licenses := (
        "http://www.creativecommons.org/publicdomain/zero/",
        "http://www.creativecommons.org/licenses/by/",
        "http://www.creativecommons.org/licenses/by-sa/"
    )
    let $supported-license-names := map {
        "http://www.creativecommons.org/publicdomain/zero/" := "Creative Commons Zero",
        "http://www.creativecommons.org/licenses/by/" := "Creative Commons Attribution",
        "http://www.creativecommons.org/licenses/by-sa/" := "Creative Commons Attribution-ShareAlike"
    }
    return
        if (count($text-licenses)>0)
        then 
            element tei:div {
                attribute type { "licensing" },
                attribute xml:lang { "en" },
                if (count($text-licenses)=1) 
                then "This text is licensed under the terms of the following license:"
                else "This text is derived from works under the following licenses:",
                for $license in $supported-licenses, 
                    $text-license in $text-licenses
                where starts-with($text-license, $license)
                return
                    let $lic-version := replace($text-license, "http://[^/]+/[^/]+/[^/]+/", "") 
                    return
                        <tei:div type="license-statement">
                            <tei:ref target="{$text-license}">{
                                string-join((
                                    $supported-license-names($license), 
                                    $lic-version
                                    ), " ")}</tei:ref>
                        </tei:div>
            }
        else ()
};

declare variable $compile:contributor-types := 
    map {
        "aut" := "Author",
        "ann" := "Annotator",
        "ctb" := "Contributor",
        "cre" := "Creator",
        "edt" := "Editor",
        "fac" := "Facsimilist",
        "fnd" := "Funder",
        "mrk" := "Markup editor",
        "oth" := "Other",
        "pfr" := "Proofreader",
        "spn" := "Sponsor",
        "trc" := "Transcriber",
        "trl" := "Translator"
    };

declare function compile:contributor-list(
    $documents as document-node()*
    ) as element(tei:div)? {
    let $responsibility-statements := $documents//tei:respStmt
    let $change-statements := $documents//tei:change
    let $all-responsibilities := $responsibility-statements | $change-statements
    where exists($all-responsibilities)
    return
        element tei:div {
            attribute type { "contributors" },
            attribute xml:lang { "en" },
            for $contributor in $all-responsibilities
            group by 
                $key := ($contributor/tei:resp/@key/string(), "edt")[1]
            order by $key
            return ( 
                let $contributor-uris :=
                    distinct-values($contributor/(*/@ref,@who)[1]/string()[.])
                let $n := count($contributor-uris)
                where $n > 0
                return
                    element tei:list {
                        element tei:head {
                           text { $compile:contributor-types($key) || "s" } 
                        },
                        for $contributor-uri in $contributor-uris
                        let $contributor-doc :=
                            if ($contributor-uri)
                            then data:doc($contributor-uri) 
                            else () 
                        let $contributor-name := $contributor-doc/*/(tei:name, tei:orgName, tei:idno)[1]
                        where $contributor-doc
                        order by $contributor-name
                        return
                            element tei:item {
                                $contributor-doc
                            }
                    }
            )
                 
        }
};

declare function compile:name-sort-key(
    $name as element()
    ) as xs:string? {
    (string-join($name/(tei:nameLink, tei:surname, tei:genName, tei:forename), " "), string($name))[1]
};

declare function compile:source-list(
    $documents as document-node()*
    ) as element(tei:div)? {
    let $source-link-elements := $documents//tei:sourceDesc/tei:bibl/tei:ptr[@type="bibl"]
    let $source-links := 
        distinct-values(
            for $link-element in $source-link-elements
            return tokenize($link-element/@target, '\s+')
        )
    where exists($source-links)
    return
        element tei:div {
            attribute type { "bibliography" },
            attribute xml:lang { "en" },
            element tei:listBibl {
                element tei:head {
                   text { "Bibliography" } 
                },
                for $source-link in $source-links
                let $source-doc := data:doc($source-link) 
                let $source-key := lower-case(string-join((
                    $source-doc/*/(
                        for $e in (
                            tei:analytic/tei:author/tei:name,
                            tei:analytic/tei:editor/tei:name,
                            tei:analytic/tei:respStmt/tei:name,
                            tei:monogr/tei:author/tei:name,
                            tei:monogr/tei:editor/tei:name, 
                            tei:monogr/tei:respStmt/tei:name,
                            tei:series/tei:author/tei:name,
                            tei:series/tei:editor/tei:name,
                            tei:series/tei:respStmt/tei:name
                        ) 
                        return compile:name-sort-key($e),
                        tei:analytic/tei:title,
                        tei:monogr/tei:title,
                        tei:series/tei:title,
                        tei:monogr/tei:imprint/tei:date
                    )), " "))
                order by $source-key
                return $source-doc
            } 
        }
};
