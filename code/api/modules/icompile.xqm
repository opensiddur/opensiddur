xquery version "1.0";
(:~ "instant compilation" is compilation of only one file into XHTML
 : using the cached copy as a basis
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace icompile="http://jewishliturgy.org/modules/icompile";

import module namespace app="http://jewishliturgy.org/modules/app"
  at "/code/modules/app.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "/code/modules/format.xqm";
import module namespace jcache="http://jewishliturgy.org/modules/cache"
  at "/code/modules/cache-controller.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "/code/modules/follow-uri.xqm";

declare namespace err="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";

(:~ perform the instant data compile operation on the given node :)
declare function icompile:compile(
  $node as node(),
  $compile-externals as xs:boolean?,
  $format-xhtml as xs:boolean?
  ) as node()+ {
  let $doc := root($node)
  let $id := $node/@xml:id
  return
    if (exists($id) or $node instance of document-node())
    then
      let $user := app:auth-user()
      let $password := app:auth-password()
      let $uri := document-uri($doc)
      let $cache := jcache:cache-all($uri, $user, $password)
      let $cached-uri := jcache:cached-document-path($uri)
      let $cached-nodes := doc($cached-uri)//*[@jx:id=$id]
      let $icompiled := icompile:icompile($cached-nodes, $compile-externals)   
      return 
        if ($format-xhtml)
        then
          (: we may be looking at a fragment and the XHTML formatter,
           : which is XSLT, cannot read context. Add context here :)
          for $ic at $n in $icompiled
          let $elem := 
            typeswitch ($ic)
            case document-node() return $ic/*
            default return $ic
          let $icompiled-with-context :=      
            element { QName(namespace-uri($elem), local-name($elem)) }{
              $elem/(@* except (@jx:document-uri, @xml:base)),
              ($elem/@xml:base, attribute xml:base { base-uri($cached-nodes[$n]) })[1],
              ($elem/@jx:document-uri, $cached-nodes[$n]/ancestor-or-self::*[@jx:document-uri][1]/@jx:document-uri)[1],
              $elem/node()
            }
          return
            format:format-xhtml($icompiled-with-context, (), $user, $password)
        else $icompiled    
    else
      error(xs:QName("err:TYPE"), "The node passed to icompile:compile() must be a document node or have an @xml:id")
};

(:~ perform instant compilation :)
declare function icompile:icompile(
  $node as node()*,
  $compile-externals as xs:boolean?
  ) as node()* {
  for $n in $node 
  return
    typeswitch($n)
    case document-node() return document{ icompile:icompile($n/node(), $compile-externals)}
    case text() return $n
    case element(tei:ptr) return local:tei-ptr($n, $compile-externals)
    case element(tei:join) return local:tei-join($n, $compile-externals)
    case element() return local:element($n, $compile-externals)
    default return icompile:icompile($n/node(), $compile-externals)
};

declare function local:tei-ptr(
  $node as element(tei:ptr), 
  $compile-externals as xs:boolean?
  ) as element()* {
  let $targets := $node/@target
  let $document-uri := base-uri($node)
  let $cached-document-uri := jcache:cached-document-path($document-uri)
  for $target in tokenize($targets, "\s+")
  let $abs := uri:absolutize-uri($target, $node)
  let $base := uri:uri-base-path($abs) 
  return 
    if ($compile-externals or $base = ($document-uri, $cached-document-uri))
    then (
      (: do follow the URI :)
      icompile:icompile(
        uri:follow-cached-uri($target, $node, uri:follow-steps($node), 
          $uri:fragmentation-cache-type),
        $compile-externals
      )
    )
    else
      (: copy the external pointer :)
      element tei:ptr {
        $node/(@*|node()),
        util:log-system-out(("Rejecting: ", $node, " because: $base=", $base, " $document-uri=", $document-uri, " $c-d-u=", $cached-document-uri))
      }
};

declare function local:tei-join(
  $node as element(tei:join),
  $compile-externals as xs:boolean?
  ) as element()* {
  let $ptrs :=
    for $target in tokenize($node/(@targets|@target), "\s+")
    return
      element tei:ptr {
        attribute xml:base { base-uri($node) },
        attribute target { $target }
      }
  return 
    icompile:icompile(
      if ($node/@result)
      then 
        element { $node/@result/string() }{
          $node/@xml:base,
          $ptrs
        }
      else $ptrs,
      $compile-externals
    )
};

declare function local:element(
  $node as element(),
  $compile-externals as xs:boolean?
  ) as element() {
  element { QName(namespace-uri($node), local-name($node)) } {
    $node/@*,
    icompile:icompile($node/node(), $compile-externals)
  }
};