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
          format:format-xhtml($icompiled, (), $user, $password)
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
    case element() return local:element($n, $compile-externals)
    default return icompile:icompile($n/node(), $compile-externals)
};

declare function local:tei-ptr(
  $node as element(tei:ptr), 
  $compile-externals as xs:boolean?
  ) as element()* {
  let $targets := $node/@target
  let $document-uri := base-uri($node)
  for $target in tokenize($targets, "\s+")
  let $abs := uri:absolutize-uri($target, $node)
  let $base := uri:uri-base-path($abs) 
  return 
    if ($compile-externals or $base = $document-uri)
    then
      (: do follow the URI :)
      uri:follow-uri($target, $node, uri:follow-steps($node))
    else
      (: copy the external pointer :)
      element tei:ptr {
        $node/(@*|node())
      }
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