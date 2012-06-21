xquery version "3.0";
(:~ Convert STML to JLPTEI: construction of hierarchies
 :
 : @author Efraim Feinstein
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace hier="http://jewishliturgy.org/transform/hierarchies";

declare namespace error="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace stml="http://jewishliturgy.org/transform/stml";

(: write a target string :)
declare function hier:target(
  $start as element(),
  $end as element()
  ) {
  if ($start is $end)
  then $start/@xml:id/string()
  else concat("range(", $start/@xml:id ,",", $end/@xml:id ,")")
};

(:~ last step in the conversion process:
 : separate out stml:file, and do other cleanup
 :)
declare function hier:separate-files(
  $e as element(stml:file)+
  ) as element(stml:file)+ {
  for $file in $e/descendant-or-self::stml:file
  return
    element stml:file {
      $file/@*,
      hier:remove-embedded-files($file/node())
    }
};

declare function hier:remove-embedded-files(
  $nodes as node()*
  ) {
  for $n in $nodes
  return 
    typeswitch($n)
    case element(stml:file) return ()
    case element(tei:milestone) return ()
    case document-node() return 
      document {
        hier:remove-embedded-files($n/node())
      }
    case text() return $n
    default return 
      element { QName(namespace-uri($n), name($n)) }{
        $n/(@* except @j:*),
        hier:remove-embedded-files($n/node())
      }
};

(:~ construct page links :)
declare function hier:page-links(
  $e as element(tei:TEI),
  $page-images-url as xs:string
  ) {
  <j:links>{
    let $stream := $e/tei:text/j:streamText
    let $ids-by-page :=
      <pages>{
        for $seg in $stream/tei:seg[@j:pages]
        let $pages := tokenize($seg/@j:pages,'\s+')
        for $page in $pages
        return <page n="{$page}" xml:id="{$seg/@xml:id}"/>
      }</pages>
    for $page in distinct-values($ids-by-page/page/@n)
    let $ids-on-page := $ids-by-page/page[@n=$page]
    let $first-on-page := $ids-on-page[1]
    let $last-on-page := $ids-on-page[count($ids-on-page)]  (: last() is broken :)
    let $local-target := hier:target($first-on-page,$last-on-page)
    let $page-target := replace($page-images-url, "\{\$page\}", $page)
    return
      <tei:link type="facs" target="#{$local-target} {$page-target}"/>
  }</j:links>
};

declare function hier:add-hierarchies(
  $nodes as node()*,
  $support as element(stml:file)+
  ) {
  for $n in $nodes
  let $making-hierarchies := 
    (count($n/ancestor::j:streamText) = count($n/ancestor-or-self::stml:file))
  return
    typeswitch($n)
    case element(stml:file) return hier:file($n, $support)
    case element(tei:TEI) return hier:TEI($n, $support)
    case element(tei:text) return hier:text($n, $support)
    case element(tei:div) return hier:div($n, $support)
    case element(tei:ab) return hier:ab($n, $support)
    case element(tei:p) return hier:p($n, $support)
    case element(tei:lb) return hier:lb($n, $support)
    case element(tei:anchor) return hier:anchor($n, $support)
    case element(j:streamText) return hier:add-hierarchies($n/node(), $support)
    case document-node() return 
      document { hier:add-hierarchies($n/node(), $support) }
    case text() return 
      if ($making-hierarchies) 
      then ()
      else $n
    default return
      if ($making-hierarchies)
      then hier:add-hierarchies($n/node(), $support)
      else
        element { QName(namespace-uri($n), name($n)) }{
          $n/@*,
          hier:add-hierarchies($n/node(), $support)
        }
};

declare function hier:file(
  $n as element(stml:file),
  $support as element()+
  ) {
  element stml:file {
    $n/@*,
    hier:add-hierarchies($n/node(), $support)
  },
  hier:add-hierarchies($n/tei:TEI/tei:text/j:streamText/stml:file, $support)
};

declare function hier:TEI(
  $e as element(tei:TEI),
  $support as element(stml:file)+
  ) {
  element tei:TEI {
    $e/@*,
    $e/tei:teiHeader,
    hier:page-links($e, $support//tei:relatedItem[@type="scan"]/@targetPattern),
    hier:add-hierarchies($e/(node() except tei:teiHeader), $support)
  }
};

declare function hier:text(
  $e as element(tei:text),
  $support as element(stml:file)+
  ) {
  element tei:text {
    $e/@*,
    hier:streamText($e/j:streamText),
    <j:concurrent xml:id="concurrent">{
      let $all-hierarchies := hier:add-hierarchies($e/j:streamText/node(),$support)
      return hier:split-layers($all-hierarchies) 
    }</j:concurrent>
  }
};

declare function hier:div(
  $e as element(tei:div),
  $support as element()+
  ) {
  <tei:div j:layer="div-{$e/@j:type}">{
    if ($e/@j:type="file")
    then attribute xml:id { "main" }
    else (),
    $e/tei:head,
    let $start := $e/following-sibling::tei:seg[1]
    (: last() is broken in annoying ways: :)
    let $n-segs := count($e/following-sibling::tei:seg)
    let $end := 
      $e/(
        following-sibling::tei:div[@j:type=$e/@j:type]/preceding-sibling::tei:seg[1], 
        following-sibling::tei:seg[$n-segs]
        )[1]
    let $target :=
      hier:target($start, $end)
    return
      <tei:ab>
        <tei:ptr target="#{$target}"/>
      </tei:ab>
  }</tei:div>
};

declare function hier:p(
  $e as element(tei:p),
  $support as element()+
  ) {
  let $p-count := count($e/preceding-sibling::tei:p) + 1
  let $start-p := $e/(
    preceding-sibling::tei:p[1],
    preceding-sibling::*[last()]
  )[1]
  let $start := $start-p/(self::tei:seg, following-sibling::tei:seg[1])
  let $end := $e/preceding-sibling::tei:seg[1]
  let $target := hier:target($start, $end)
  return (
    if ($start and $end and 
      (($start is $end) or $start << $end)
    )
    then
      <tei:p xml:id="p_{$p-count}" j:layer="p">
        <tei:ptr target="#{$target}"/>
      </tei:p>
    else (),
    if (
      empty($e/following-sibling::tei:p) and 
      exists($e/following-sibling::tei:seg)
      )
    then
      (: insert one more last paragraph :)
      <tei:p xml:id="p_{$p-count + 1}" j:layer="p">{
        let $start := $e/following-sibling::tei:seg[1]
        let $end := $e/following-sibling::tei:seg[last()]
        let $Null := util:log-system-out(("Inserting last p from ", $start/@xml:id/string(), " to ", $end/@xml:id/string()))
        return
          <tei:ptr target="#{hier:target($start,$end)}"/>
      }</tei:p>
    else ()
  )
};

(:~ named hierarchies :)
declare function hier:anchor(
  $e as element(tei:anchor),
  $support as element()+
  ) {
  if ($e/@j:type = "NamedCommand")
  then 
    let $name := substring-after($e/@xml:id, "start-")
    return
      <tei:ab j:layer="ab-{$name}" xml:id="{$name}">{
        <tei:ptr target="#range(start-{$name},end-{$name})"/>
      }</tei:ab>
  else () 
};

(:~ verses :)
declare function hier:ab(
  $e as element(tei:ab),
  $support as element()+
  ) {
  if ($e/@type="verse")
  then
    let $chapter := $e/tei:label[@n="chapter"]
    let $verse := $e/tei:label[@n="verse"]
    return 
      <tei:ab xml:id="v_{$chapter}_{$verse}" j:layer="verse">{
        $e/(@*|node()),
        let $start := $e/following-sibling::tei:seg[1]
        let $end := $e/(
          following-sibling::tei:ab[@type="verse"][1]/preceding-sibling::tei:seg[1],
          following-sibling::tei:seg[last()]
        )
        let $target := hier:target($start,$end)
        return
          <tei:ptr target="#{$target}"/>
      }</tei:ab>
  else ()
};

(:~ line group/line hierarchy: after stxt transform,
 : these should only exist in poetry mode
 :)
declare function hier:lb(
  $e as element(tei:lb),
  $support as element()+
  ) {
  (: is this lb the end of an lg? :)
  let $end-of-lg :=
    $e/(
      following-sibling::tei:milestone[@type="End-Poetry-Mode"][1]|
      following-sibling::tei:p[1]|
      (
        let $lst := (self::*,following-sibling::*)
        return $lst[count($lst)] (: last() is *very* broken :)
      )
      )[1]
  let $last-lb := $end-of-lg/(
    self::tei:lb,
    preceding-sibling::tei:lb[1]
    )[1]
  where ($e is $last-lb)
  return
    (: because of issues with last(), this code is terribly
    inefficient :)
    let $starts := 
      ($e/preceding-sibling::*| $e)[1] |
      $e/preceding-sibling::tei:milestone[@type="Begin-Poetry-Mode"][1]|
      $e/preceding-sibling::tei:p[1]
    let $start-of-lg := $starts[count($starts)] (: <-- these are in document order, so I want the last one :)
    return
      <tei:lg j:layer="lg">{
        for $lb in (
          $start-of-lg/following-sibling::tei:lb[. << $end-of-lg],
          $end-of-lg/self::tei:lb
        )
        let $start-of-l := ($start-of-lg|$lb/preceding-sibling::tei:lb[1])[last()]
        let $contained-segments := $start-of-l/following-sibling::tei:seg[. << $lb]
        where exists($contained-segments)
        return 
          <tei:l>{
            <tei:ptr target="#{
              hier:target(
                $contained-segments[1],
                $contained-segments[count($contained-segments)])}"/>
          }</tei:l>
      }</tei:lg>
};

  

declare function hier:split-layers(
  $layer-elements as element()+
  ) {
  for $element in $layer-elements
  group $element as $e by $element/@j:layer as $layer-type
  return
    if ($layer-type)
    then
      <j:layer type="{
        if (contains($layer-type, "-"))
        then substring-before($layer-type, "-")
        else $layer-type}">{
        $e
      }</j:layer>
    else ()
};

declare function hier:streamText(
  $e as element(j:streamText)?
  ) {
  for $st in $e
  return
    element j:streamText {
      $e/(@*|tei:ptr|tei:seg|tei:anchor)
    }
};