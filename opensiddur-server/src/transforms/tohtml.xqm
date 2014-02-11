xquery version "3.0";
(:~
 : Transform for combined JLPTEI to HTML 
 :
 : Parameters:
 :    tohtml:style (temporary) -> pointer to API for CSS styling
 :
 : Open Siddur Project
 : Copyright 2013 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 :)
module namespace tohtml = 'http://jewishliturgy.org/transform/html';

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";
declare namespace error="http://jewishliturgy.org/errors";
declare default element namespace "http://www.w3.org/1999/xhtml";

import module namespace api="http://jewishliturgy.org/modules/api"
  at "../modules/api.xqm";
import module namespace common="http://jewishliturgy.org/transform/common"
  at "../modules/common.xqm";

declare variable $tohtml:default-style := "/api/data/styles/generic.css";

(:~ entry point :)
declare function tohtml:tohtml-document(
  $doc as document-node(),
  $params as map
  ) as document-node() {
  tohtml:tohtml($doc, $params)
};

declare function tohtml:tohtml(
  $nodes as node()*,
  $params as map
  ) as node()* {
  for $node in $nodes
  return
    typeswitch ($node)
    case document-node() 
    return document { tohtml:tohtml($node/node(), $params) }
    case element(tei:TEI)
    return tohtml:tei-TEI($node, $params)
    case element(tei:teiHeader)
    return ()
    case element(tei:forename)
    return tohtml:span-element($node, $params)
    case element(tei:item)
    return tohtml:span-element($node, $params)
    case element(tei:list)
    return tohtml:span-element($node, $params)
    case element(tei:ref)
    return tohtml:tei-ref($node, $params)
    case element(tei:roleName)
    return tohtml:span-element($node, $params)
    case element(tei:surname)
    return tohtml:span-element($node, $params)
    case element(tei:w)
    return tohtml:span-element($node, $params)
    case element(j:divineName)
    return tohtml:span-element($node, $params)
    case element(tei:pc)
    return tohtml:tei-pc($node,$params)
    case element()
    return tohtml:element($node, $params)
    default 
    return $node
};

(:~ add space between elements where necessary 
 : @param $e preceding element
 :)
declare function tohtml:space(
  $e as element(),
  $params as map
  ) as node()? {
  if (
    $e/following::*[1] instance of element(tei:pc) or
    $e/self::tei:pc[.='־'] (: maqef is a connector on both sides :)
    )
  then ()
  else text { "&#x20;" }
};

declare function tohtml:span-element(
  $e as element(),
  $params as map
  ) as node()+ {
  element span {
    tohtml:attributes($e, $params),
    tohtml:tohtml($e/node(), $params),
    tohtml:space($e, $params)
  }
};

declare function tohtml:tei-pc(
  $e as element(tei:pc),
  $params as map
  ) as node()+ {
  element span {
    let $attributes := tohtml:attributes($e, $params)
    return (
      $attributes[name(.) != 'class'],
      attribute class {
        string-join((
          $attributes[name(.)="class"]/string(),
          switch ($e/string())
          case 'פ'
          return "pe"
          case 'ס'
          return "samekh"
          default
          return ()
        ), ' ')
      }, 
      tohtml:tohtml($e/node(), $params)
    ),
    tohtml:space($e, $params)
  }
};

declare function tohtml:tei-ref(
    $e as element(tei:ref),
    $params as map
    ) as node()+ {
    element a {
        attribute href { $e/@target },
        tohtml:attributes($e, $params),
        if ($e/ancestor::tei:div[@type="license-statement"])
        then tohtml:tei-ref-license($e, $params)
        else (),
        tohtml:tohtml($e/node(), $params)
    },
    tohtml:space($e, $params)
};

declare function tohtml:tei-ref-license(
    $e as element(tei:ref),
    $params as map
    ) as node()+ {
    let $icons := map {
        "zero" := "/api/static/cc-zero.svg",
        "by" := "/api/static/cc-by.svg",
        "by-sa" := "/api/static/cc-by-sa.svg"
    }
    let $license-type := tokenize($e/@target, "/")[5]
    let $img :=
        if ($license-type)
        then
            element object {
                attribute data { $icons($license-type) },
                attribute type { "image/svg+xml" },
                text { if ($license-type="zero") then "No rights reserved" else "Some rights reserved" }
            }
        else ()
    return (
        attribute rel { "license" },
        $img
    )
};

(:~ @return classes :)
declare function tohtml:attributes-to-class(
  $attributes as attribute()*,
  $params as map
  ) as xs:string* {
  for $a in $attributes
  return
    typeswitch ($a)
    case attribute(jf:id)
    return "id-" || $a/string()
    case attribute(type)
    return "type-" || $a/string()
    case attribute(subtype)
    return "subtype-" || $a/string()
    case attribute(n)
    return "n-" || $a/string()
    case attribute(jf:part)
    return "part-" || $a/string()
    default return ()
};

declare function tohtml:attributes(
  $e as element(),
  $params as map
  ) as attribute()* {
  if ($e/@xml:lang and
    ( $e is root($e)/* or
      not($e/../tohtml:lang($e/@xml:lang))
    )
  )
  then (
    attribute lang { $e/@xml:lang },
    $e/@xml:lang,
    attribute dir { common:direction-from-language($e/@xml:lang) }
  )
  else (),
  attribute class { 
    string-join((
      concat(
        switch(namespace-uri($e))
        case "http://www.tei-c.org/ns/1.0"
        return "tei"
        case "http://jewishliturgy.org/ns/jlptei/1.0"
        return "j"
        case "http://jewishliturgy.org/ns/jlptei/flat/1.0"
        return "jf"
        default
        return ("", 
          error(
            xs:QName("error:NAMESPACE_UNKNOWN"), 
            "Unknown namespace for " || name($e) || ":" || namespace-uri($e)
          )
        ),
        "-",
        local-name($e)
      ),
      tohtml:attributes-to-class($e/@*,$params)
    ), " ")
  },
  if ($e/@jf:document)
  then attribute data-document { $e/@jf:document/string() }
  else (),
  if ($e/@jf:license)
  then attribute data-license { $e/@jf:license/string() }
  else ()
};

declare function tohtml:tei-TEI(
  $e as element(tei:TEI),
  $params as map
  ) as element(html) {
  element html {
    tohtml:attributes($e, $params),
    element head {
      element meta { attribute charset { "utf8" } },
      element meta { (: do we need this? :) 
        attribute http-equiv {"Content-Type" },
        attribute content { "text/html; charset=utf-8" }
      }, 
      element link { 
        attribute rel { "stylesheet" },
        attribute href { ($params("tohtml:style"), api:uri-of($tohtml:default-style))[1] },
        attribute type { "text/css" }
      },
      tohtml:header-title($e/tei:teiHeader, $params)
    },
    element body {
      tohtml:tohtml($e/tei:text, $params)
    }
  }
};

(:~ workaround for broken lang() function. Requires a context :)
declare %private function tohtml:lang(
  $lang as xs:string
  ) as xs:boolean {
  starts-with(common:language(.), $lang)
};

(:~ build a title suitable for an HTML header :)
declare function tohtml:header-title( 
  $tei-header as element(tei:teiHeader),
  $params as map
  ) as element(title) {
  element title {
    let $main-lang := common:language($tei-header/..)
    let $title-element as element(tei:title) :=
      $tei-header/tei:fileDesc/tei:titleStmt/(
        tei:title[@type="main"][tohtml:lang($main-lang)],
        tei:title[not(@type)][tohtml:lang($main-lang)],
        tei:title[@type="main"],
        tei:title[not(@type)])[1]
    let $title-element-lang := common:language($title-element)
    let $title-element-dir := common:direction-from-language($title-element-lang)
    return (
      attribute lang { $title-element-lang },
      attribute xml:lang { $title-element-lang },
      attribute dir { $title-element-dir },
      $title-element/string()
    )
  }
};

(:~ generic element :)
declare function tohtml:element(
  $e as element(),
  $params as map
  ) as element() {
  element div {
    tohtml:attributes($e, $params),
    tohtml:tohtml($e/node(), $params)
  }
};
