xquery version "3.0";
(:~ Convert STML to JLPTEI: construct a text stream
 : Note: this stream will have interspersed elements.
 : seg, ptr, and anchor should be retained;
 :  @j:* attributes and all other elements should be removed
 :
 : @author Efraim Feinstein
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace stxt="http://jewishliturgy.org/transform/streamtext";

declare namespace error="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace stml="http://jewishliturgy.org/transform/stml";

(: construct a streamText given temporary-stream (which may have embedded files) :)
declare function stxt:convert(
  $nodes as node()*
  ) {
  for $n in $nodes
  return
    typeswitch ($n)
    case element(stml:temporary-stream)return stxt:temporary-stream($n)
    case element(tei:seg) return stxt:seg($n)
    case element(tei:lb) return stxt:lb($n)
    case text() return stxt:text($n)
    case document-node() return stxt:convert($n/*)
    default return (
      stxt:copy($n)
    )
};

declare function stxt:copy(
  $e as element()
  ) {
  element {QName(namespace-uri($e), name($e))}{
    $e/@*,
    stxt:convert($e/node())
  }
};

(: extract a streamText from the result of stxt:convert() :)
declare function stxt:extract-streamText(
  $e as element(j:streamText)
  ) {
  element j:streamText {
    $e/(@*|tei:seg|tei:anchor|tei:ptr)
  }
};

declare function stxt:lb(
  $e as element(tei:lb)
  ) {
  if (stxt:is-poetry-mode($e))
  then $e
  else ()
};

(: return whether a segment is a continuation of 
 : another segment :)
declare function stxt:is-continuation-segment(
  $e as element(tei:seg)
  ) {
  exists(
    stxt:is-continued-segment(
      $e/preceding-sibling::tei:seg[1]
    )
  )
};

(:~ determine if we're in poetry mode (note:poetry mode may cross files!)
 :)
declare function stxt:is-poetry-mode(
  $n as node()
  ) {
  $n/preceding::tei:milestone[@type="Begin-Poetry-Mode"][1] >>
  $n/preceding::tei:milestone[@type="End-Poetry-Mode"][1] 
};

(: return whether a segment is continued to the next segment 
 : if it is continued, return the segment that continues it 
 :)
declare function stxt:is-continued-segment(
  $e as element(tei:seg)?
  ) as element(tei:seg)? {
  let $next := $e/following-sibling::tei:seg[1]
  let $is-terminated :=
    exists($e/tei:pc[@j:type="pausal"]) or 
      (exists(($next,$e)/@xml:lang) and 
        not($next/@xml:lang = $e/@xml:lang)) or
      $e/following-sibling::tei:pb[1][. << $next]/@j:continued="false" or
      (stxt:is-poetry-mode($e) and
        ($e/following-sibling::tei:lb[1] << $next))
  return
    $next[not($is-terminated)]
};

declare function stxt:seg(
  $e as element(tei:seg)
  ) {
  stxt:seg($e, false())
};

(: $override turns off checking for continuation :)
declare function stxt:seg(
  $e as element(tei:seg),
  $override as xs:boolean
  ) {
  if (not($override) and stxt:is-continuation-segment($e))
  then 
    ((: is this a continued segment? if yes, ignore it :))
  else 
    let $next := stxt:is-continued-segment($e)
    let $continued-segments :=
      if ($next)
      then stxt:seg($next, true())
      else ()
    return
      element tei:seg {
        attribute j:pages {
          string-join(
            distinct-values(
              ($e/preceding::tei:pb[@ed="scan"][1]/@n,
              $continued-segments/@j:page)
            ),
          " "
          )
        },
        $e/@*,
        stxt:convert($e/node()),
        $continued-segments/node()
      }
};

(: once segments are finalized, assign xml:ids to the stream
 : elements 
 :)
declare function stxt:assign-xmlids(
  $n as node()?,
  $seg-ctr as xs:integer,
  $w-ctr as xs:integer
  ) {
  typeswitch($n)
  case empty-sequence() return ()
  case text() return $n
  case element(tei:anchor) return stxt:assign-xmlids-seg-level($n, $seg-ctr, $w-ctr)
  case element(tei:ptr) return stxt:assign-xmlids-seg-level($n, $seg-ctr, $w-ctr)
  case element(tei:seg) return stxt:assign-xmlids-seg-level($n, $seg-ctr, $w-ctr)
  case element(tei:w) return stxt:assign-xmlids-w-level($n, $seg-ctr, $w-ctr)
  case element(tei:pc) return stxt:assign-xmlids-w-level($n, $seg-ctr, $w-ctr)
  case element(stml:file) 
    return (
      (: file level, reset all counters :)
      stxt:assign-xmlids($n/*[1], 1, 1),
      stxt:assign-xmlids($n/following-sibling::node()[1], $seg-ctr, $w-ctr)
    )
  default return (
    (: other element type? copy and recurse :)
    element { QName(namespace-uri($n), name($n)) }{
      $n/@*,
      stxt:assign-xmlids($n/node()[1], $seg-ctr, $w-ctr)
    },
    stxt:assign-xmlids($n/following-sibling::*[1], $seg-ctr, $w-ctr)
    )
};

declare function stxt:assign-xmlids-seg-level(
  $n as element(),
  $seg-ctr as xs:integer,
  $w-ctr as xs:integer
  ) {
  (: segment level :)
  element { QName(namespace-uri($n), name($n))}{
    ( 
      $n/@xml:id, 
      attribute xml:id { concat(local-name($n), "_", $seg-ctr) }
    )[1],
    $n/(@* except @xml:id),
    stxt:assign-xmlids($n/node()[1], $seg-ctr, 1)
  },
  stxt:assign-xmlids($n/following-sibling::node()[1], $seg-ctr + 1, $w-ctr)
};

declare function stxt:assign-xmlids-w-level(
  $n as element(),
  $seg-ctr as xs:integer,
  $w-ctr as xs:integer
  ) {
  (: word-level :)
  element tei:w {
    (
      $n/@xml:id,
      attribute xml:id {
        concat(local-name($n), "_", $seg-ctr, "_", $w-ctr) 
      }
    )[1],
    $n/(@* except @xml:id),
    stxt:assign-xmlids($n/node()[1], $seg-ctr, $w-ctr)
  },
  stxt:assign-xmlids($n/following-sibling::node()[1], $seg-ctr, $w-ctr + 1)
};

declare function stxt:temporary-stream(
  $e as element(stml:temporary-stream)
  ) {
  <j:streamText xml:id="text">{
    stxt:convert($e/node())
  }</j:streamText>
};

declare function stxt:text(
  $t as text()
  ) {
  if ($t/ancestor::tei:seg and not($t/parent::tei:pc))
  then
    (: split into words and punctuation characters :)
    let $tokens := tokenize($t, "\s+")
    for $token in $tokens
    let $groups := text:groups($token, "([\p{L}\p{M}\p{N}\p{S}\p{C}]+)|(\p{P})")
    let $word-chars := $groups[2]
    let $punct-chars := $groups[3]
    where $groups[1]
    return
      if ($word-chars)
      then <tei:w>{$word-chars}</tei:w>
      else <tei:pc>{$punct-chars}</tei:pc>
  else normalize-space($t)
};