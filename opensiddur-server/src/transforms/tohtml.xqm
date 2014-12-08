xquery version "3.0";
(:~
 : Transform for combined JLPTEI to HTML 
 :
 : Parameters:
 :    tohtml:style (temporary) -> pointer to API for CSS styling
 :
 : Open Siddur Project
 : Copyright 2013-2014 Efraim Feinstein 
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
import module namespace compile="http://jewishliturgy.org/transform/compile"
  at "compile.xqm";

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
    case element(tei:listBibl)
    return tohtml:tei-listBibl($node, $params)
    case element(tei:div)
    return
        if ($node/@type="licensing")
        then tohtml:div-with-header((
                tohtml:add-additional-license-notes($node, $params)
            ), $params, "Licensing")
        else if ($node/@type="contributors")
        then tohtml:div-with-header($node, $params, "Contributors")
        else tohtml:element($node, $params)
    case element(tei:forename)
    return tohtml:span-element($node, $params)
    case element(tei:item)
    return tohtml:span-element($node, $params)
    case element(tei:list)
    return tohtml:span-element($node, $params)
    case element(tei:ptr)
    return tohtml:tei-ptr($node, $params)
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
    case element(j:contributor)
    return tohtml:j-contributor($node, $params)
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

(:~ convert any remaining tei:ptr after processing to an a[href] :)
declare function tohtml:tei-ptr(
    $e as element(tei:ptr),
    $params as map
    ) as node()+ {
    element a {
        attribute href { $e/@target },
        tohtml:attributes($e, $params),
        if ($e/ancestor::tei:note[@type="audio"])
        then tohtml:tei-ref-audio($e, $params)
        else text { "." } (: give the ptr some substance :),
        tohtml:tohtml($e/node(), $params)
    },
    tohtml:space($e, $params)
};

declare function tohtml:tei-ref(
    $e as element(tei:ref),
    $params as map
    ) as node()+ {
    element a {
        attribute href { $e/@target },
        tohtml:attributes($e, $params),
        if (exists($e/ancestor::tei:note["audio"=@type]))
        then tohtml:tei-ref-audio($e, $params)
        else if (exists($e/ancestor::tei:div[@type="license-statement"]))
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
                attribute width { "300px" },
                text { if ($license-type="zero") then "No rights reserved" else "Some rights reserved" }
            }
        else ()
    return (
        attribute rel { "license" },
        $img
    )
};

(:~ add an audio icon :)
declare function tohtml:tei-ref-audio(
    $e as element(),
    $params as map
    ) as node()+ {
    element object {
        attribute data { "/api/static/Speaker_Icon.svg" },
        attribute type { "image/svg+xml" },
        attribute width { "20px" },
        attribute text { "Play audio" }
    }
};

declare function tohtml:wrap-in-link(
    $item as item()*,
    $link as xs:string?
    ) as item()* {
    if ($link)
    then 
        element a {
            attribute href { $link },
            $item
        }
    else $item
};

(:~ @return contributor list entry :)
declare function tohtml:j-contributor(
    $e as element(j:contributor),
    $params as map
    ) as element() {
    let $name := 
        let $name := tohtml:tohtml(($e/tei:name,$e/tei:orgName,$e/tei:idno)[1], $params)
        let $website := $e/tei:ptr[@type="url"]/@target/string()
        return tohtml:wrap-in-link($name, $website)
    let $affiliation := 
        if ($e/tei:affiliation)
        then
            let $name := tohtml:tohtml($e/tei:affiliation, $params)
            let $website := $e/tei:affiliation/tei:ptr[@type="url"]/@target/string()
            return tohtml:wrap-in-link($name, $website)
        else ()
    return
        element div {
            tohtml:attributes($e, $params),
            $name,
            $affiliation
        }
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
        attribute href { api:uri-of(($e//@jf:style/string()[.], $tohtml:default-style)[1]) },
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

declare function tohtml:div-with-header(
    $e as element(tei:div),
    $params as map,
    $header as item()*
    ) as element() {
    element div {
        tohtml:attributes($e, $params),
        element h2 {
            $header
        },
        tohtml:tohtml($e/node(), $params)
    }
};

(:~ add additional license notes, if necessary :)
declare function tohtml:add-additional-license-notes(
    $e as element(),
    $params as map
    ) as element() {
    element { QName(namespace-uri($e), name($e)) } {
        $e/@*,
        $e/node(),
        if (exists(root($e)//tei:note[@type="audio"]))
        then
            element tei:div {
                attribute type { "license-statement" },
                text { "Audio icon downloaded from " },
                element tei:ref {
                    attribute target { "http://commons.wikimedia.org/wiki/File:Speaker_Icon.svg" },
                    text { "Wikimedia Commons" }
                },
                text { " dedicated to the public domain by its authors." }
            }
        else (
            (: any more external credits? :) 
        )
    }
};

declare function tohtml:tei-listBibl(
    $e as element(tei:listBibl),
    $params as map
    ) as element() {
    element div {
        tohtml:attributes($e, $params),
        element h2 {
            tohtml:tohtml($e/tei:head/node(), $params)
        },
        tohtml:bibliography($e/tei:biblStruct, $params)
    }
};

declare function tohtml:bibliography(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case element(tei:edition)
        return tohtml:bibl-tei-edition($node, $params)
        case element(tei:imprint)
        return tohtml:bibl-tei-imprint($node, $params)
        case element(tei:author)
        return tohtml:bibl-tei-author-or-editor($node, $params)
        case element(tei:editor)
        return tohtml:bibl-tei-author-or-editor($node, $params)
        case element(tei:respStmt)
        return tohtml:bibl-tei-author-or-editor($node, $params)
        case element(tei:surname)
        return tohtml:bibl-tei-surname($node, $params)
        case element(tei:forename)
        return ()
        case element(tei:nameLink)
        return ()
        case element(tei:roleName)
        return ()
        case element(tei:title)
        return tohtml:bibl-tei-title($node, $params)
        case element(tei:meeting)
        return tohtml:bibl-tei-meeting($node, $params)
        case element(tei:date)
        return tohtml:bibl-tei-date($node, $params)
        case element(tei:pubPlace)
        return tohtml:bibl-tei-pubPlace($node, $params)
        case element(tei:publisher)
        return tohtml:bibl-tei-publisher($node, $params)
        case element(tei:idno)
        return tohtml:bibl-tei-idno($node, $params)
        case element(tei:note)
        return tohtml:bibl-tei-note($node, $params)
        case element(tei:distributor)
        return tohtml:bibl-tei-distributor($node, $params)
        case element(tei:biblStruct)
        return tohtml:bibl-tei-biblStruct($node, $params)
        (: regular processing :)
        case element(tei:ref)
        return tohtml:tohtml($node, $params)
        case element(tei:ptr)
        return tohtml:tohtml($node, $params)
        case text()
        return tohtml:bibl-text($node, $params)
        default return tohtml:bibliography($node/node(), $params)
};

declare function tohtml:bibl-tei-edition(
    $e as element(tei:edition),
    $params as map
    ) as node()+ {
    element div {
        tohtml:attributes($e, $params),
        tohtml:bibliography($e/node(), $params)
    }, text { "." }
};

declare function tohtml:bibl-tei-imprint(
    $e as element(tei:imprint),
    $params as map
    ) as node()* {
    element div {
        tohtml:attributes($e, $params),
        tohtml:bibliography((
            $e/tei:date, 
            $e/tei:pubPlace,
            $e/tei:publisher,
            $e/tei:distributor,
            $e/tei:biblScope), $params)
    }
};

declare function tohtml:bibl-tei-author-or-editor(
    $e as element(),
    $params as map
    ) as node()* {
    if (not($e/@corresp)) 
    then    (: do not include translations :)
        let $n-following := 
            if ($e instance of element(tei:respStmt))
            then count($e/following-sibling::tei:respStmt[tei:resp/@key=$e/tei:resp/@key][not(@corresp)])
            else count($e/following-sibling::*[name()=$e/name()][not(@corresp)])
        return (
            element div {
                tohtml:attributes($e, $params),
                tohtml:bibliography(
                    if ($e instance of element(tei:respStmt)) then $e/(node() except tei:resp) 
                    else $e/node(), $params)
            },
            text {
                if ($e instance of element(tei:author) and $n-following=0)
                then "." (: last name in a list :)
                else if ($e instance of element(tei:editor) and $n-following=0)
                then string-join((
                    " (ed",
                    if ($e/preceding-sibling::tei:editor) then "s" else (),
                    ".) "), "") (: editor :)
                else if ($e instance of element(tei:respStmt) and $n-following=0) (: other responsibility :)
                then string-join((" (",
                                  lower-case($compile:contributor-types(($e/tei:resp/@key/string(), "edt")[1])),
                                  if ($e/preceding-sibling::tei:respStmt[tei:resp/@key=$e/tei:resp/@key]) 
                                  then "s" else (),
                                  ")"), "") 
                else if ($n-following=1)
                then " and " (: penultimate in list :)
                else ", " (: first or middle name in a list :)
            }
        )
    else ()
};

declare function tohtml:bibl-tei-surname(
    $e as element(tei:surname),
    $params as map
    ) as node()* {
    let $rn := $e/../tei:roleName
    where exists($rn)
    return (tohtml:use-bibl($rn, $params), text { " " }),
    let $fn := $e/../tei:foreName
    where exists($fn)
    return (tohtml:use-bibl($fn, $params), text { " " }),
    let $nl := $e/../tei:nameLink
    where exists($nl)
    return (tohtml:use-bibl($nl, $params), text { " " }),
    element div {
        tohtml:attributes($e, $params),
        tohtml:bibliography($e/node(), $params)
    }
};

declare function tohtml:use-bibl(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case element(tei:forename)
        return tohtml:use-bibl-tei-forename($node, $params)
        case element(tei:nameLink)
        return tohtml:use-bibl-any($node, $params)
        case element(tei:roleName)
        return tohtml:use-bibl-any($node, $params)
        case text()
        return $node
        default return tohtml:use-bibl($node/node(), $params)
};

declare function tohtml:use-bibl-tei-forename(
    $e as element(tei:forename),
    $params as map
    ) as node()* {
    if ($e/preceding-sibling::tei:forename)
    then text { " " }
    else (),
    element span {
        tohtml:attributes($e, $params),
        tohtml:bibliography($e/node(), $params)
    }
};

declare function tohtml:use-bibl-any(
    $e as element(),
    $params as map
    ) as node()* {
    element span {
        tohtml:attributes($e, $params),
        tohtml:bibliography($e/node(), $params)
    }
};

(: TODO: differentiate between different level titles :)
declare function tohtml:bibl-tei-title(
    $e as element(tei:title),
    $params as map
    ) as node()* {
    element div {
        tohtml:attributes($e, $params),
        tohtml:bibliography($e/node(), $params)
    },
    if ($e/@type="sub" and $e/following-sibling::*)
    then text { " " }
    else (),
    text { ". " }
};

declare function tohtml:bibl-tei-meeting(
    $e as element(tei:meeting),
    $params as map
    ) as node()* {
    text { " (" },
    element div {
        tohtml:attributes($e, $params),
        tohtml:bibliography($e/node(), $params)
    },
    text { ")" },
    if (exists($e/following-sibling::*))
    then text { " " }
    else ()
};

declare function tohtml:bibl-tei-date(
    $e as element(tei:date),
    $params as map
    ) as node()* {
    if ($e/@type="access")
    then text { "Accessed " }
    else (),
    element div {
        tohtml:attributes($e, $params),
        tohtml:bibliography($e/node(), $params)
    },
    if (exists($e/following-sibling::*))
    then text { ". " }
    else ()
};

declare function tohtml:bibl-tei-pubPlace(
    $e as element(tei:pubPlace),
    $params as map
    ) as node()* {
    element div {
        tohtml:attributes($e, $params),
        tohtml:bibliography($e/node(), $params)
    },
    text {
        if ($e/following-sibling::tei:pubPlace)
        then ", "
        else if ($e/../tei:publisher)
        then ": "
        else ". "
    }
};

declare function tohtml:bibl-tei-publisher(
    $e as element(tei:publisher),
    $params as map
    ) as node()+ {
    element div {
        tohtml:attributes($e, $params),
        tohtml:bibliography($e/node(), $params)
    },
    text { ". " }
};

declare function tohtml:bibl-tei-biblScope(
    $e as element(tei:biblScope),
    $params as map
    ) as node()+ {
    if ($e/ancestor::tei:bibl)
    then tohtml:bibliography($e/node(), $params)
    else if ($e/@type="vol")
    then 
        element div {
            tohtml:attributes($e, $params),
            tohtml:bibliography($e/node(), $params)
        }
    else if ($e/@type="chap") 
    then (
        text { "chapter " },
        element div {
            tohtml:attributes($e, $params),
            tohtml:bibliography($e/node(), $params)
        }
    )
    else if ($e/@type="issue")
    then (
        text { " (" },
        element div {
            tohtml:attributes($e, $params),
            tohtml:bibliography($e/node(), $params)
        },  
        text { ") " }
    )
    else if ($e/@type="pp")
    then (
        if (contains($e, "-") or contains($e, "ff") or contains($e, " "))
        then text { "pp. " }
        else text { "p. " },
        element div {
            tohtml:attributes($e, $params),
            tohtml:bibliography($e/node(), $params)
        }
    )
    else
        tohtml:bibliography($e/node(), $params),
    if ($e/@type="vol" and $e/following-sibling::tei:biblScope)
    then text { " " }
    else if ($e/ancestor::tei:biblStruct)
    then text { ". " }
    else ()
};

declare function tohtml:bibl-tei-idno(
    $e as element(tei:idno),
    $params as map
    ) as node()* {
    if ($e/@type=("doi", "isbn", "ISBN"))
    then ()
    else (
        text { " " },
        element div {
            tohtml:attributes($e, $params),
            tohtml:bibliography($e/node(), $params)
        }
    )
};

declare function tohtml:bibl-tei-biblStruct(
    $e as element(tei:biblStruct),
    $params as map
    ) as element() {
    element div {
        tohtml:attributes($e, $params),
        element div {
            attribute class { "bibl-authors" },
            tohtml:bibliography($e/tei:*/tei:author, $params)
        },
        element div {
            attribute class { "bibl-editors" },
            tohtml:bibliography($e/tei:*/tei:editor, $params)
        },
        element div {
            attribute class { "bibl-titles" },
            tohtml:bibliography($e/(tei:analytic, tei:monogr, tei:series)/tei:title, $params)
        },
        tohtml:bibliography($e/tei:*/(tei:edition, tei:imprint), $params),
        element div {
            attribute class { "bibl-notes" },
            tohtml:bibliography($e/tei:note, $params)
        }
    }
};

declare function tohtml:bibl-tei-note(
    $e as element(tei:note),
    $params as map
    ) as element() {
    element div {
        tohtml:attributes($e, $params),
        (: apply in default mode :)
        tohtml:tohtml($e/node(), $params)
    }
};

declare function tohtml:bibl-tei-distributor(
    $e as element(tei:distributor),
    $params as map
    ) as node()+ {
    text { "Distributed by " },
    element div {
        tohtml:attributes($e, $params),
        tohtml:bibliography($e/node(), $params),
        text { "." }
    }
};

declare function tohtml:bibl-text(
    $e as text(),
    $params as map
    ) as text()? {
    if ($e/ancestor::tei:name/descendant::text()[last()])
    then $e (: last name in a list :)
    else if (
        some $text 
        in $e/(ancestor::tei:monogr|ancestor::tei:imprint|ancestor::tei:series|ancestor::tei:analytic)/*/
            descendant::text()[last()]
        satisfies $text is $e
    )
    then
        (: last text node in any item of imprint :)
        $e
    else 
        tohtml:tohtml($e, $params)
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
