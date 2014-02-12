xquery version "3.0";
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

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

declare function compile:compile-document(
  $doc as document-node(),
  $params as map
  ) as document-node() {
  compile:compile($doc, $params)
};

declare function compile:compile(
  $nodes as node()*,
  $params as map
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
  $params as map
  ) as element() {
  element {QName(namespace-uri($e), name($e))}{
    $e/@*,
    compile:compile($e/node() ,$params)
  }
};

(: add back matter that's derived from the text's metadata :)
declare function compile:tei-text(
  $e as element(tei:text),
  $params as map
  ) as element(tei:text) {
  let $text-output := compile:element($e, $params)
  return 
    element tei:text {
      $text-output/@*,
      $text-output/(* except tei:back),
      element tei:back {
        $text-output/tei:back/(@*|node()),
        let $api-documents := $text-output//@jf:document
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
            compile:license-statements($unique-documents) 
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
