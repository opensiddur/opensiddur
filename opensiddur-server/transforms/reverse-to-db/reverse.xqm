xquery version "1.0";
(:~
 : Roundtrip fragmentation markup TEI to JLPTEI and save it to the
 : database 
 :
 : Debugging code: reverse
 :
 : Open Siddur Project 
 : Copyright 2011-2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace reverse = 'http://jewishliturgy.org/modules/reverse';

import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "xmldb:exist:///code/modules/debug.xqm";
import module namespace nav="http://jewishliturgy.org/modules/nav"
  at "xmldb:exist:///code/api/modules/nav.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";

(: map j:view/@type to the elements it's intended to hold :)
declare variable $reverse:view-type-map :=
  <view-type-map>
    <view-type type="div">
      <tei:div>
        <tei:head/>
        <tei:ab/>
      </tei:div>
    </view-type>
    <view-type type="verse">
      <tei:ab type="verse">
        <tei:label/>
      </tei:ab>
    </view-type>
    <view-type type="choice">
      <tei:choice>
        <j:option/>
      </tei:choice>
    </view-type>
    <view-type type="lg">
      <tei:lg>
        <tei:l/>
      </tei:lg>
    </view-type>
    <view-type type="p">
      <tei:p>
        <tei:s/>
      </tei:p>
    </view-type>
    <view-type type="s">
      <tei:s/>
    </view-type>
    <view-type type="list">
      <tei:list>
        <tei:head/>
        <tei:item/>
      </tei:list>
    </view-type>
    <view-type type="parallel">
      <j:parallelGrp>
        <j:parallel/>
        <j:original/>
      </j:parallelGrp>
    </view-type>
  </view-type-map>;

declare function reverse:generate-id(
  $node as node()
  ) as xs:string {
  reverse:generate-id(
    $node,
    $node/descendant::node())
};

(: generate a unique id for a given node
 :)
declare function reverse:generate-id(
  $node as node(),
  $context-descendants as node()*
  ) as xs:string {
  concat(
    local-name($node),
    "_",
    util:hash(
      util:serialize(
        if (exists($context-descendants))
        then
          element { QName(namespace-uri($node), name($node)) }{
            $node/@*,
            $context-descendants
          }
        else $node, ()
      ), "sha1")
  )
};

declare function local:recurse-find-views(
  $snippets as element()*,
  $from-document as xs:string,
  $parent-names as xs:QName*
  ) as xs:string* {
  for $snippet in $snippets[not(@jx:document-uri != $from-document)]
  let $snippet-qname := QName(namespace-uri($snippet), local-name($snippet))
  let $my-view-type := 
    $reverse:view-type-map/view-type/descendant-or-self::*
      [local-name(.)=local-name($snippet)]
      [namespace-uri(.)=namespace-uri($snippet)]
      [not(@type) or (@type=$snippet/@type)]
      [
        let $p := parent::* except parent::view-type
        return
          if ($p)
          then $parent-names=$snippet-qname
          else true()
      ]/../@type/string()
  return
    ($my-view-type, 
      local:recurse-find-views($snippet/*, $from-document, ($parent-names, $snippet-qname))
    )
};

(:~ return back which view types exist in the given snippet :)
declare function reverse:find-views(
  $snippet as element()
  ) as xs:string* {
  distinct-values(local:recurse-find-views($snippet, $snippet/@jx:document-uri, ()))
}; 

(: find a starting point for view processing :)
declare function reverse:reverse-views(
  $intermed-snippet as element()+,
  $doc as document-node()
  ) as element(reverse:view)* {
  for $snippet in $intermed-snippet
  let $view-types := reverse:find-views($snippet)
(:
  let $null := 
    util:log-system-out(
      ("**** view-types for snippet ", $snippet, " are: ", string-join($view-types, ","))
    )
:)
  for $view-type in $view-types 
  return
    element reverse:view { 
      attribute document {$snippet/@jx:document-uri},
      attribute type { $view-type },
      let $result := reverse:rebuild-view($snippet, $doc, $view-type, ())
      return (
(:      
        util:log-system-out(("rebuild-view:", $result )),
:)      
        $result
      )
    }
}; 

(:~ main entry point for reversal operations. 
 : @param @intermed the fragmentation TEI
 : @param $start-resource the resource which the TEI is POSTed to
 :)
declare function reverse:reverse(
  $intermed as element(),
  $start-resource as xs:string
  ) as element(reverse:rebuild) {
  element reverse:rebuild {
    reverse:rebuild-repository($intermed),
    (: find and process all snippets (views and selections) :)
    let $snippets := $intermed/descendant-or-self::*[@jx:document-uri]
    for $snippet at $n in $snippets
    let $doc := nav:api-path-to-sequence($snippet/@jx:document-uri)
    return (
      element reverse:selection {
        attribute document { $snippet/@jx:document-uri },
        reverse:rebuild-selection($snippet, $doc//j:selection)
      },
      reverse:reverse-views($snippet, $doc)
    )
  }
    
};

declare function local:is-in-other-view(
  $snippet-equivalent as element(), 
  $ancestor-view as element()
  ) as xs:boolean {
  let $other-views := $ancestor-view/parent::*/(j:view except $ancestor-view)
  let $my-ancestor-view := $snippet-equivalent/ancestor::j:view
  return not($my-ancestor-view) or $my-ancestor-view is $other-views 
};

declare function local:is-correct-type(
  $snippet as element(), 
  $view-type as xs:string,
  $parent-names as xs:QName*
  ) as xs:boolean {
  let $ln := local-name($snippet)
  let $ns := namespace-uri($snippet)
  let $type := $snippet/@type
  return
    exists(
      $reverse:view-type-map/view-type
        [@type=$view-type]/descendant-or-self::*
        [$ln = local-name(.)]
        [$ns = namespace-uri(.)]
        [
          not(@type) or @type=$type 
        ]
        [
          if ($type) 
          then @type = $type  
          else true()
        ]
        [
          let $p := parent::* except parent::view-type
          return
            if ($p)
            then $parent-names=QName(namespace-uri($p), local-name($p))
            else true()
        ]
    )
};

declare function local:split-words(
  $string as xs:string
  ) as element()* {
  local:split-words($string, ())
};


(:~ split a string into multiple words (tei:w/tei:pc) 
 :
 : This code is derived from split-word.xsl2 
 :)
declare function local:split-words(
  $string as xs:string,
  $first-xmlid as xs:string?
  ) as element()* {
  (: need to split into characters & control characters, punctuation, spaces :)
  let $text-groups := text:groups($string, "(\s*(([\p{L}\p{M}\p{N}\p{S}\p{C}]+)|(\p{P}))\s*)")
  let $remainder := substring-after($string, $text-groups[2])
  let $word-chars := $text-groups[4]
  let $punct-chars := $text-groups[5]
  return (
    if ($word-chars)
    then 
      element tei:w {
        attribute xml:id { 
          ($first-xmlid, concat("w-", util:random(1000000)))[1] 
        },
        reverse:normalize-nonunicode($word-chars)
      }
    else if ($punct-chars)
    then 
      element tei:pc {
        attribute xml:id { 
          concat("pc-", util:random(1000000))
        },
        $punct-chars
      }
    else (),
    if ($remainder)
    then local:split-words($remainder, ())
    else ()
  )
};

(: possibilities for transforming nodes in tei:w:
 : 1. text() -> split into w/pc
 : 2. text()[spc]element()[spc]text() -> split text()s into w/pc, pass through element()
 : 3. text()element()[spc]text() -> split text(), last incorporated into <tei:w>text() element()</tei:w>  
 :)
declare function local:transform-w-child(
  $nodes as node()*
  ) as node()* {
  let $this-xmlid := ($nodes[1]/../(@xml:id, @jx:id)[1])[empty($nodes[1]/preceding-sibling::node())]
  return
    typeswitch($nodes[1])
    case empty() return ()
    case element() return (
      let $this := local:reverse-transform($nodes[1])
      let $next := local:transform-w-child(subsequence($nodes, 2))
      return 
        if (
          $next and 
          ($nodes[2] instance of element() or 
            not(matches($nodes[2], "^\s")))
           )
        then (
          element tei:w {
            (
              $this-xmlid, 
              $next[1]/@*, 
              attribute xml:id {concat("w-", util:random(1000000))}
            )[1],
            $this,
            $next[1]/node()
          },
          subsequence($next, 2)
        )
        else (
          element tei:w {
           ($this-xmlid, attribute xml:id {concat("w-", util:random(1000000))})[1],
           $this
          },
          $next
        )
    )
    case $n1 as text() return
      if ($n1/following-sibling::element() and not(matches($n1, "\s$")))
      then
        let $this := local:split-words($n1, $this-xmlid)
        let $next := local:transform-w-child(subsequence($nodes,2))
        return (
          subsequence($this, 1, count($this) - 1),
          element tei:w {
            $this[last()]/(@*|node()),
            $next[1]/node()
          },
          subsequence($next,2)
        )
      else (
        local:split-words($n1, $this-xmlid),
        local:transform-w-child(subsequence($nodes, 2))
      )
    default return
      ($nodes[1], local:transform-w-child(subsequence($nodes, 2)))
};

declare function local:transform-w(
  $w as element(tei:w)
  ) as element(tei:w)+ {
  local:transform-w-child($w/node()[1])
};

(:~ transform that copies everything,
 : performs nonunicode normalization,
 : corrects tei:w/tei:pc to contain one word/punct character
 : removes @jx:* attributes,
 : assigns xml:ids
 :)
declare function local:reverse-transform(
  $nodes as node()*
  ) as node()* {
  for $n in $nodes 
  return 
    typeswitch ($n)
    case element(tei:w) return
      local:transform-w($n)
    case text() return
      if ($n/(ancestor::tei:w|ancestor::tei:c|ancestor::tei:g|ancestor::tei:pc))
      then $n
      else local:split-words($n)
    case element() return
      element { QName(namespace-uri($n), name($n)) }{
        $n/(@* except @jx:*),
        if ($n/@jx:id)
        then
          attribute xml:id {
            $n/@jx:id 
          }
        else (),
        local:reverse-transform($n/node())
      }
    default return $n
};

(:~ build text repository entries :)
declare function reverse:rebuild-repository(
  $full as element()
  ) as element(reverse:repository)* {
  for $segment in $full//tei:seg
  group 
    $segment as $seg 
    by $segment/ancestor::*[@jx:document-uri][1]/@jx:document-uri/string() as $document-source
  return 
    element reverse:repository {
      attribute document { $document-source },
      for $document-segment in $seg
      group 
        $document-segment as $doc-seg
        by $document-segment/@jx:id as $id
      return 
        local:reverse-transform($doc-seg)
    }
};

declare function reverse:rebuild-selection(
  $snippet as element(),
  $selection as element(j:selection)
  ) {
  let $doc-uri := $snippet/ancestor-or-self::*[@jx:document-uri][1]/@jx:document-uri/string()
  let $doc := nav:api-path-to-sequence($doc-uri)
  return
    if ($snippet instance of element(tei:ptr) and not($snippet/@type="url"))
    then
      let $snippet-equivalent := $doc/id($snippet/@jx:id)
      return 
        if ($snippet-equivalent/ancestor::j:selection is $selection)
        then
          element tei:ptr {
            attribute xml:id { $snippet/@jx:id },
            $snippet/(@* except @jx:*) 
          }
        else ()
    else (
      for $element in $snippet/element()
      return
        reverse:rebuild-selection($element, $selection)
    )
};

declare function reverse:identify-ancestor-view(
  $snippet as element()
  ) as element(j:view)? {
  let $doc-uri := $snippet/ancestor-or-self::*[@jx:document-uri][1]/@jx:document-uri/string()
  let $doc := nav:api-path-to-sequence($doc-uri)
  let $snippet-equivalent := $doc/id($snippet/@jx:id)
  where exists($snippet-equivalent)
  return $snippet-equivalent/ancestor::j:view
};

declare function local:recurse-rebuild-view(
  $snippet as element(),
  $doc as document-node(),
  $view-type as xs:string,
  $parent-names as xs:QName*
  ) as node()* {
  for $node in $snippet/node()
  return
    typeswitch($node)
    case text() return
      text { reverse:normalize-nonunicode($node) }
    case element() return 
      reverse:rebuild-view($node, $doc, $view-type, $parent-names)
    default return $node
};

(:~ recursively rebuild a view from a parent. If no parent is given,
 : find it
 :)
declare function reverse:rebuild-view(
  $snippet as element(),
  $doc as document-node(),
  $view-type as xs:string,
  $parent-names as xs:QName*
  ) {
  let $equivalent := $doc/id($snippet/@jx:id)
  let $snippet-from-view := 
    $equivalent/(ancestor::j:view|ancestor::j:repository|ancestor::j:selection)
  return
    if (local:is-correct-type($snippet, $view-type, $parent-names))
    then
      (: element is from the view that is currently being processed.
       : or it is the correct type for it 
       : copy it.
       :)
      let $my-qname := QName(namespace-uri($snippet), name($snippet))
      let $my-local-qname := QName(namespace-uri($snippet), local-name($snippet))
      return
        element { $my-qname }{
          $snippet/(@* except (@jx:id, @jx:document-uri)),
          if ($snippet/@jx:id)
          then
            attribute xml:id { $snippet/@jx:id }
          else (),
          local:recurse-rebuild-view($snippet,$doc,$view-type, ($parent-names, $my-local-qname)) 
        }
    else if ($snippet instance of element(tei:ptr))
    then
      element tei:ptr {
        attribute target {
          concat("#",
            if ($snippet-from-view instance of element(j:selection))
            then
              (: from the selection. generate a new pointer that points
               : into the selection
               :)
               $snippet/@jx:id
            else
              (: not from the selection: new pointer in the selection :)
              reverse:generate-id($snippet)
           )
        }
      }
    else 
      (: not in the current ancestor view, not a pointer.
       : skip it
       :)
      if ($snippet/descendant::tei:ptr)
      then local:recurse-rebuild-view($snippet,$doc,$view-type, $parent-names)
      else ()
};

(:~ merge all repositories in the rebuild set :)
declare function reverse:merge-repositories(
  $reverse-data as element(reverse:rebuild)
  ) {
  for $repository in $reverse-data/reverse:repository
  return reverse:merge-repository($repository)
};

(:~ merge a single repository :)
declare function reverse:merge-repository(
  $additions as element(reverse:repository)
  ) {
    let $doc := nav:api-path-to-sequence($additions/@document)
    let $repository := $doc//j:repository
    for $segment in $additions/tei:seg
    let $replaces := $doc/id($segment/@xml:id)
    return 
      if (exists($replaces))
      then 
        (: possible optimization: is $segment different than $replaces? :)
        update replace $replaces with $segment
      else
        update insert $segment into $repository
};  

declare function reverse:merge-selection(
  $additions as element(reverse:selection)
  ) {
    let $doc := nav:api-path-to-sequence($additions/@document)
    let $selection := $doc//j:selection
    let $selection-ptrs := $selection/tei:ptr
    let $first-common-ptr := $selection-ptrs[@xml:id=$additions/tei:ptr/@xml:id][1]
    let $additions-first-common := $additions/tei:ptr[@xml:id=$first-common-ptr/@xml:id]
    let $last-common-ptr := $selection-ptrs[@xml:id=$additions/tei:ptr/@xml:id][last()]
    let $additions-last-common := $additions/tei:ptr[@xml:id=$last-common-ptr/@xml:id]
    let $new-selection := (
      $first-common-ptr/preceding-sibling::*,
      $additions-first-common/preceding-sibling::*,
      $first-common-ptr,
      $additions-first-common/following-sibling::*[. << $additions-last-common],
      $last-common-ptr[not(. is $first-common-ptr)],
      $additions-last-common/following-sibling::*,
      $last-common-ptr/following-sibling::*
    )
    return 
      update replace $selection with 
        element j:selection {
          $selection/@*,
          $new-selection
        }
};

declare function reverse:merge-view(
  $additions as element(reverse:view)
  ) {
  let $doc := nav:api-path-to-sequence($additions/@document)
  let $equivalent-view := $doc//j:view[@type=$additions/@type]
  let $first-common-element := $equivalent-view/*[@xml:id=$additions/*/@xml:id][1]
  let $last-common-element := $equivalent-view/*[@xml:id=$additions/*/@xml:id][last()]
  let $additions-first-common := $additions/*[@xml:id=$first-common-element/@xml:id]
  let $additions-last-common := $additions/*[@xml:id=$last-common-element/@xml:id]
  let $new-view := 
    element j:view {
      if ($equivalent-view)
      then $equivalent-view/@*
      else $additions/(@* except @document),
      $first-common-element/preceding-sibling::*,
      $additions-first-common/preceding-sibling::*,
      $additions-first-common, (: the new version should be used :)
      $additions-first-common/following-sibling::*[. << $additions-last-common],
      $additions-last-common[not(. is $additions-first-common)],
      $additions-last-common/following-sibling::*,
      $last-common-element/following-sibling::*
    }
(:
  let $null := util:log-system-out((
    "****Merging view: ",
    "equivalent=", $equivalent-view, 
    " ^^^^ additions=", $additions, 
    " $$$$ new-view =", $new-view,
    " first-common-element =", $first-common-element,
    " additions-first-common = ", $additions-first-common,
    " last-common-element =", $last-common-element,
    " additions-last-common =", $additions-last-common,
    " middle elements = ", $additions-first-common/following-sibling::*[. << $additions-last-common]
    ))
:)
  return 
    if (exists($equivalent-view))
    then update replace $equivalent-view with $new-view
    else update insert $new-view into $doc//j:concurrent
};

declare function reverse:merge-selections(
  $reverse-data as element(reverse:rebuild)
  ) {
  for $selection in $reverse-data/reverse:selection
  return reverse:merge-selection($selection)
};

declare function reverse:merge-views(
  $reverse-data as element(reverse:rebuild)
  ) {
  (:
  let $null := util:log-system-out(("***merge-views from", $reverse-data))
  :)
  for $view in $reverse-data/reverse:view
  return reverse:merge-view($view)
};

declare function reverse:merge(
  $reverse-data as element(reverse:rebuild)
  ) {
  (#exist:batch-transaction#) {
    debug:debug($debug:info, "reverse", "merge-repositories..."),
    reverse:merge-repositories($reverse-data),
    debug:debug($debug:info, "reverse", "merge-selections..."),
    reverse:merge-selections($reverse-data),
    debug:debug($debug:info, "reverse", "merge-views..."),
    reverse:merge-views($reverse-data),
    debug:debug($debug:info, "reverse", "done")
  }
};

declare variable $reverse:nonunicode-data :=
  doc("/code/modules/code-tables/non-unicode-combining-classes.xml")/*;

(:~ Normalize a string based on non-Unicode combining classes, used by
 : some reverse formatters
 : @param original-string The string to convert
 :)
declare function reverse:normalize-nonunicode(
  $original-string as xs:string
  ) as xs:string { 
  let $tokenized-string-xml :=
    element string {
      for $cp at $n in string-to-codepoints($original-string)
      let $comb-class as xs:integer := 
        xs:integer(($reverse:nonunicode-data/*[@from=$cp], 0)[1])
      return element ch { attribute cp { $cp }, attribute cc { $comb-class }, attribute n { $n } }
    }
  return
    string-join(
      let $last-char := count($tokenized-string-xml/*) + 1
      for $ch0 in $tokenized-string-xml/ch[@cc = 0]
      let $next-ch0 := xs:integer(($ch0/following-sibling::*[@cc = 0][1]/@n, $last-char)[1])
      return
        for $ch in ($ch0, $ch0/following-sibling::*[@n < $next-ch0])
        order by $ch/@cc/number()
        return
          codepoints-to-string($ch/@cp),
      ""
    )
};
  
  