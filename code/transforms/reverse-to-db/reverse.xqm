xquery version "1.0";
(:~
 : Roundtrip fragmentation markup TEI to JLPTEI and save it to the
 : database 
 :
 : Open Siddur Project 
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace reverse = 'http://jewishliturgy.org/modules/reverse';

import module namespace nav="http://jewishliturgy.org/modules/nav"
  at "xmldb:exist:///code/api/modules/nav.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";

(: map j:view/@type to the elements it's intended to hold :)
declare variable $reverse:view-type-map :=
  <view-type-map>
    <view-type type="div">
      <tei:div/>
      <tei:head/>
      <tei:ab/>
    </view-type>
    <view-type type="verse">
      <tei:ab type="verse"/>
      <tei:label/>
    </view-type>
    <view-type type="choice">
      <tei:choice/>
      <j:option/>
    </view-type>
    <view-type type="lg">
      <tei:lg/>
      <tei:l/>
    </view-type>
    <view-type type="p">
      <tei:p/>
      <tei:s/>
    </view-type>
    <view-type type="s">
      <tei:s/>
    </view-type>
    <view-type type="list">
      <tei:list/>
      <tei:item/>
      <tei:head/>
    </view-type>
    <view-type type="parallel">
      <j:parallelGrp/>
      <j:parallel/>
      <j:original/>
    </view-type>
  </view-type-map>;

declare function reverse:view-type(
  $snippet as element(), 
  $ancestor-view as element()
  ) as xs:boolean {
  let $ln := local-name($snippet)
  let $ns := namespace-uri($snippet)
  let $type := $snippet/@type
  return
    exists(
      $reverse:view-type-map/view-type[@type=$ancestor-view/@type]/*
        [$ln = local-name(.)]
        [$ns = namespace-uri(.)]
        [
          if ($type) 
          then @type = $type  
          else true()
        ]
    )
};


declare function local:get-ancestor-view-type(
  $node as node()
  ) as element() {
  let $my-document-start := $node/ancestor-or-self::*[@jx:document-uri][1]
  let $my-document := $my-document-start/@jx:document-uri/string()
  let $closest-id := $node/ancestor-or-self::*[@jx:id][1][not(self::tei:ptr)]
    [(. is $my-document-start) or (. >> $my-document-start)]/@jx:id
  let $lookup := 
    if ($my-document and $closest-id)
    then 
      nav:api-path-to-sequence($my-document)/id($closest-id)
    else 
      (: take a guess by the element type :)
      typeswitch($node)
      case element(tei:ptr) return
        if ($node/@type="url")
        then <j:repository/>
        else <j:selection/>
      case element(tei:seg) return <j:repository/>
      case element(tei:w) return <j:repository/>
      case element(tei:pc) return <j:repository/>
      default return 
        element j:view {
          ($reverse:view-type-map/view-type
            [local-name(.)=local-name($node)]
            [namespace-uri(.)=namespace-uri($node)]/@type,
            attribute type { local-name($node) }
          )[1]
        }
  return 
    $lookup/(
      util:log-system-out($lookup),
      (: some bug prevents ancestor-or-self from working... :)
      self::j:view|
      self::j:selection|
      self::j:repository|
      ancestor-or-self::j:view|
      ancestor-or-self::j:selection|
      ancestor-or-self::j:repository
    )
};

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
    let $snippets := $intermed//*[@jx:document-uri]
    for $snippet at $n in $snippets
    let $parent := $snippet/..
    let $doc := nav:api-path-to-sequence($snippet/@jx:document-uri)
    let $replaces := 
      if ($snippet/@jx:id)
      then 
        (: the snippet derives from something referenced by jx:id directly :)
        $doc/id($snippet/@jx:id)
      else ()
        (: the snippet derives from something referenced by #range :)
    return (
      if ($replaces/ancestor-or-self::j:view)
      then
        element reverse:view { 
          attribute document {$snippet/@jx:document-uri},
          reverse:rebuild-view($snippet, $replaces/ancestor-or-self::j:view)
        }
      else (),
      element reverse:selection {
        attribute document { $snippet/@jx:document-uri },
        reverse:rebuild-selection($snippet, $doc//j:selection)
      }
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
  $ancestor-view as element()
  ) as xs:boolean {
  let $ln := local-name($snippet)
  let $ns := namespace-uri($snippet)
  let $type := $snippet/@type
  return
    exists(
      $reverse:view-type-map/view-type[@type=$ancestor-view/@type]/*
        [$ln = local-name(.)]
        [$ns = namespace-uri(.)]
        [
          if ($type) 
          then @type = $type  
          else true()
        ]
    )
};

(:~ transform that copies everything,
 : removes @jx:* attributes and assigns xml:ids
 :)
declare function local:remove-jx(
  $nodes as node()*,
  $ancestor as element()
  ) as node()* {
  for $n in $nodes 
  return 
    typeswitch ($n)
    case element() return
      element { QName(namespace-uri($n), name($n)) }{
        $n/(@* except @jx:*),
        attribute xml:id {
          $n/@jx:id 
        },
        local:remove-jx($n/node(), $ancestor)
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
        local:remove-jx($doc-seg, <j:repository/>)
    }
};

declare function reverse:rebuild-selection(
  $snippet as element(),
  $selection as element(j:selection)
  ) {
  let $doc-uri := $snippet/ancestor-or-self::*[@jx:document-uri][1]/@jx:document-uri/string()
  let $doc := nav:api-path-to-sequence($doc-uri)
  let $null := util:log-system-out(("rebuild-selection for ", $doc-uri, "#", $snippet/@jx:id))
  return
    if ($snippet instance of element(tei:ptr) and not($snippet/@type="url"))
    then
      let $snippet-equivalent := $doc/id($snippet/@jx:id)
      let $null := util:log-system-out(("pointer equivalent = ", $snippet-equivalent))
      return 
        if ($snippet-equivalent/ancestor::j:selection is $selection)
        then
          element tei:ptr {
            attribute xml:id { $snippet/@jx:id },
            $snippet/(@* except @jx:*) 
          }
        else ()
    else (
      util:log-system-out("not a pointer"),
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
  $ancestor-view as element(j:view)
  ) {
  for $node in $snippet/node()
  return
    typeswitch($node)
    case element() return reverse:rebuild-view($node, $ancestor-view)
    default return $node
};

(:~ recursively rebuild a view from a parent. If no parent is given,
 : find it
 :)
declare function reverse:rebuild-view(
  $snippet as element(),
  $ancestor-view as element(j:view)
  ) {
  let $document := root($ancestor-view)
  let $equivalent := $document/id($snippet/@jx:id)
  let $snippet-from-view := 
    $equivalent/(ancestor::j:view|ancestor::j:repository|ancestor::j:selection)
  return
    if ($snippet-from-view is $ancestor-view or
      local:is-correct-type($snippet, $ancestor-view)
      )
    then
      (: element is from the view this currently being processed.
       : or it is the correct type for this 
       : copy it.
       :)
      element { QName(namespace-uri($snippet), name($snippet))}{
        $snippet/(@* except (@jx:id, @jx:document-uri)),
        if ($snippet/@jx:id)
        then
          attribute xml:id { $snippet/@jx:id }
        else (),
        local:recurse-rebuild-view($snippet,$ancestor-view) 
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
      then local:recurse-rebuild-view($snippet,$ancestor-view)
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
  let $additions-last-common := $additions/*[@xml:id=$last-common-element/*/@xml:id]
  let $new-view := 
    element j:view {
      if ($equivalent-view)
      then $equivalent-view/@*
      else $additions/@*,
      $first-common-element/preceding-sibling::*,
      $additions-first-common/preceding-sibling::*,
      $first-common-element,
      $additions-first-common/following-sibling::*[. << $additions-last-common],
      $last-common-element[not(. is $first-common-element)],
      $additions-last-common/following-sibling::*,
      $last-common-element/following-sibling::*
    }
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
  for $view in $reverse-data/reverse:view
  return reverse:merge-view($view)
};

declare function reverse:merge(
  $reverse-data as element(reverse:rebuild)
  ) {
  (#exist:batch-transaction#) {
    reverse:merge-repositories($reverse-data),
    reverse:merge-selections($reverse-data),
    reverse:merge-views($reverse-data)
  }
};