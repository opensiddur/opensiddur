xquery version "3.1";
(:~
 : follow-uri function and mode
 : The follow-uri function will follow paths in the /api/* form, 
 : /data/* form, and if neither can be found, will use 
 : direct database resource paths as a fallback. The fast-* form
 : will not use caching and assumes that only #range() XPointers
 : or #id pointers are used. 
 :
 : Open Siddur Project
 : Copyright 2009-2013 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 :)
module namespace uri="http://jewishliturgy.org/transform/uri";

import module namespace common="http://jewishliturgy.org/transform/common"
  at "common.xqm"; 
import module namespace debug="http://jewishliturgy.org/transform/debug"
	at "debug.xqm"; 
import module namespace mirror="http://jewishliturgy.org/modules/mirror"
    at "mirror.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "data.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";
declare namespace p="http://jewishliturgy.org/ns/parser";
declare namespace r="http://jewishliturgy.org/ns/parser-result";
declare namespace error="http://jewishliturgy.org/errors";

(:~ return an element by id, relative to a node :)
declare function uri:id(
	$id as xs:string,
	$root as node()
	) as element()? {
	($root/id($id), $root//*[@jf:id = $id])[1]
};

(:~ Given a relative URI and a context,  
 :  resolve the relative URI into an absolute URI
 : @param $uri contains the URI to make absolute
 : @param $context The URI is absolute relative to this context.
 :)
declare function uri:absolutize-uri(
	$uri as xs:string,
  $context as node()?
  ) as xs:anyURI {
	let $base-path as xs:anyURI := uri:uri-base-path($uri)
	return
    xs:anyURI(
    if ($base-path and (matches($uri, "^http[s]?://") or doc-available($base-path)))
    then $uri
    else (:resolve-uri($uri,base-uri($context) ):)
        (: UHOH: there is some kind of bug in eXist 2.2 where if this is run on an in-memory document,
        it will fail with an NPE.
        This code checks for an in-memory document and if the document does not have a document-uri,
        it will try to figure out the right base uri manually. If it can't, it will just assume that
        it is as absolute as it can be :)
        let $docuri := document-uri(root($context))
        return
            if ($docuri)
            then resolve-uri($uri,base-uri($context) )
            else
                let $base := $context/ancestor-or-self::*[@xml:base][1]/@xml:base
                return
                    if ($base)
                    then resolve-uri($uri, xs:anyURI($base))
                    else $uri
    )
};
  
(:~ Returns the base path part of an absolute URI 
 : @param $uri An absolute URI
 :)
declare function uri:uri-base-path(
	$uri as xs:string
	) as xs:anyURI {
  xs:anyURI(
  	if (contains($uri,'#')) 
    then substring-before($uri,'#') 
    else $uri
  )
};
  
(:~ Base resource of a URI (not including the fragment or query string)
 : @param $uri A URI
 :)
declare function uri:uri-base-resource(
	$uri as xs:string
	) as xs:anyURI {
  let $base-path as xs:string := string(uri:uri-base-path($uri))
  return
    xs:anyURI(
      if (contains($base-path, '?'))
      then substring-before($base-path, '?')
      else $base-path
    )
};
  
(:~ Returns the fragment portion of an absolute URI.  
 : The return value excludes the #
 : @param $uri An absolute URI
 :)
declare function uri:uri-fragment(
	$uri as xs:string
	) as xs:anyURI {
  xs:anyURI(
  	if (contains($uri, '#')) 
    then substring-after($uri, '#') 
    else ''
  )
};
  
(:~ Follow a given pointer $uri, 
 : including any subsequent pointers or links (such as tei:join). 
 : The $steps parameter indicates the number of pointer steps to follow if 
 : another pointer is pointed to by $uri.  
 : If $steps is negative, the chain is followed infinitely (or
 : until another pointer limits it).
 :)
declare function uri:follow-uri(
	$uri as xs:string,
  $context as node(),
  $steps as xs:integer
	) as node()* {
  uri:fast-follow($uri, $context, $steps)
};

declare function uri:follow-cached-uri(
  $uri as xs:string,
  $context as node(),
  $steps as xs:integer,
  $cache-type as xs:string?
  ) as node()* {
  uri:fast-follow($uri, $context, $steps, false(), false(), $cache-type)
};

(:~ Extended uri:follow-uri() to allow caching.
 : @param $cache-type Which cache to use
 :)
declare function uri:follow-cached-uri(
	$uri as xs:string,
  $context as node(),
  $steps as xs:integer,
  $cache-type as xs:string?,
  $intermediate-ptrs as xs:boolean?
	) as node()* {
  uri:fast-follow($uri, $context, $steps, $intermediate-ptrs, false(), $cache-type) 
};

declare function uri:fast-follow(
  $uri as xs:string,
  $context as node(),
  $steps as xs:integer
  ) as node()* {
  uri:fast-follow($uri, $context, $steps, (), false())
};

declare function uri:fast-follow(
  $uri as xs:string,
  $context as node(),
  $steps as xs:integer,
  $intermediate-ptrs as xs:boolean?) {
  uri:fast-follow($uri, $context, $steps, $intermediate-ptrs, false())
};

declare function uri:fast-follow(
  $uri as xs:string,
  $context as node(),
  $steps as xs:integer,
  $intermediate-ptrs as xs:boolean?,
  $allow-copies as xs:boolean
  ) as node()* {
  uri:fast-follow($uri, $context, $steps, $intermediate-ptrs, $allow-copies, ())
};

(:~ faster routine to follow a pointer one step
 : Only works with shorthand pointers and #range().
 : If $cache is used, assumes that the cache is valid 
 :)
declare function uri:fast-follow(
  $uri as xs:string,
  $context as node(),
  $steps as xs:integer,
  $intermediate-ptrs as xs:boolean?,
  $allow-copies as xs:boolean,
  $cache as xs:string?
  ) as node()* {
  let $full-uri as xs:anyURI :=
    uri:absolutize-uri($uri, $context)
  let $base-path as xs:anyURI := 
    uri:uri-base-path($full-uri)
  let $fragment as xs:anyURI := 
    uri:uri-fragment(string($full-uri))
  let $original-document as document-node()? := 
    try {
      data:doc($base-path)
    }
    catch error:NOTIMPLEMENTED {
      (: the requested path is not in /data :)
      doc($base-path)
    }
  (: short-circuit if the document does not exist :) 
  where exists($original-document)  
  return
    let $original-document-uri := document-uri($original-document)
    let $document as document-node()? :=
      if ($cache
        and not(starts-with($original-document-uri, "/db/cache")))
      then
        (: we have requested a cached link and we make sure that the link is not also coming from the cache :)
        mirror:doc($cache, $original-document-uri)
      else $original-document
    let $pointer-destination as node()* :=
      if ($fragment) 
      then 
        uri:follow(
          if (starts-with($fragment, "range("))
          then 
            let $left :=
              let $left-ptr := substring-before(substring-after($fragment, "("), ",")
              return uri:id($left-ptr, $document)[1]
            let $right := 
              let $right-ptr := substring-before(substring-after($fragment, ","), ")")
              return uri:id($right-ptr, $document)[1]
            return uri:range($left, $right, $allow-copies)
          else 
            uri:id($fragment,$document)[1], 
          $steps, $cache, true(), 
          $intermediate-ptrs
        )
      else $document
    return $pointer-destination
};

declare function uri:follow-tei-link(
	$context as element()
	) as node()* {
	uri:follow-tei-link($context, -1, (), ())
};

declare function uri:follow-tei-link(
	$context as element(),
	$steps as xs:integer
	) as node()* {
	uri:follow-tei-link($context, $steps, (), ())
};

declare function uri:follow-tei-link(
  $context as element(),
  $steps as xs:integer,
  $cache-type as xs:string?
  ) as node()* {
  uri:follow-tei-link($context, $steps, $cache-type, ())
};

declare function uri:follow-tei-link(
  $context as element(),
  $steps as xs:integer,
  $cache-type as xs:string?,
  $fast as xs:boolean?
  ) as node()* {
  uri:follow-tei-link($context, $steps, $cache-type, $fast, ())
};

(:~ Handle the common processing involved in following TEI links
 : @param $context Link to follow
 : @param $steps Specifies the maximum number of steps to evaluate.  Negative for infinity (default)
 : @param $cache-type Specifies the cache type to use (eg, fragmentation).  Empty for none (default)
 : @deprecated @param $fast use the fast follow algorithm (default true()) 
 : @param $intermediate-ptrs return all intermediate pointers, not just the final result (default false())
 :)
declare function uri:follow-tei-link(
	$context as element(),
  $steps as xs:integer,
  $cache-type as xs:string?,
  $fast as xs:boolean?,
  $intermediate-ptrs as xs:boolean?
	) as node()* {
  let $targets as xs:string+ := 
    tokenize(string($context/(@target|@targets)),'\s+')
  return
    for $t in $targets
    return
    	if ($steps = 0)
    	then $context
    	else 
    	  if ($fast)
    	  then
    	    uri:fast-follow($t, $context, 
    	      uri:follow-steps($context, $steps),
    	      $intermediate-ptrs, false(), $cache-type)
    	  else 
            (:
          uri:follow-cached-uri(
          	$t, $context, 
            uri:follow-steps($context, $steps), 
            $cache-type,
            $intermediate-ptrs)
            :)
            error(xs:QName("error:DEPRECATED"), "slow follow is deprecated")
};

(:~ calculate the number of steps to pass to follow-cached-uri()
 : given a pointer or link element 
 :)
declare function uri:follow-steps(
  $context as element()
  ) as xs:integer {
  uri:follow-steps($context, -1)
};

(:~ calculate the number of steps to pass to follow-cached-uri()
 : given a pointer or link element and a number already followed 
 :)
declare function uri:follow-steps(
  $context as element(),
  $steps as xs:integer
  ) as xs:integer {
  let $evaluate as xs:string? := 
    ($context/(@evaluate,../(tei:linkGrp|../tei:joinGrp)/@evaluate)[1])/string()
  return
    if ($evaluate='none') 
    then 0 
    else if ($evaluate='one') 
    then 1
    else $steps - 1
};

(:----------- follow a pointer mode -------------:)

declare function uri:follow(
  $node as node()*,
  $steps as xs:integer,
  $cache-type as xs:string?
  ) as node()* {
  uri:follow($node, $steps, $cache-type, (), ())
};

declare function uri:follow(
  $node as node()*,
  $steps as xs:integer,
  $cache-type as xs:string?,
  $fast as xs:boolean?
  ) as node()* {
  uri:follow($node, $steps, $cache-type, $fast, ())
};

(:~ 
 : @param $fast use uri:fast-follow()
 : @param $intermediate-ptrs return all intermediates in addition
 :    to the end result of following the pointer
 :)
declare function uri:follow(
	$node as node()*,
	$steps as xs:integer,
	$cache-type as xs:string?,
	$fast as xs:boolean?,
	$intermediate-ptrs as xs:boolean?
	) as node()* {
	for $n in $node
	return
		typeswitch($n)
		case element(tei:join) return uri:tei-join($n, $steps, $cache-type, $fast, $intermediate-ptrs)
		case element(tei:ptr) return uri:tei-ptr($n, $steps, $cache-type, $fast, $intermediate-ptrs) 
		default return $n
};  

(:~ follow tei:ptr, except tei:ptr[@type=url] :)
declare function uri:tei-ptr(
	$context as element(),
  $steps as xs:integer,
  $cache-type as xs:string?,
  $fast as xs:boolean?,
  $intermediate-ptrs as xs:boolean?
  ) as node()* {
 	if ($context/@type = 'url')
 	then $context
 	else (
 	  $context[$intermediate-ptrs],
 	  if ($context/parent::tei:joinGrp)
 	  then uri:tei-join($context, $steps, $cache-type, $fast, $intermediate-ptrs)
 	  else uri:follow-tei-link($context, $steps, $cache-type, $fast, $intermediate-ptrs)
 	) 
};

(:~ tei:join or tei:ptr acting as a join being followed.  
 : If @result is present, produce an element with the namespace URI
 : the same as that of the context node
 :)
declare function uri:tei-join(
	$context as element(),
	$steps as xs:integer,
	$cache-type as xs:string?,
	$fast as xs:boolean?,
	$intermediate-ptrs as xs:boolean?
	) as node()* {
	$context[$intermediate-ptrs],
	let $joined-elements as element()* :=
		for $pj in uri:follow-tei-link($context, $steps, $cache-type, $fast, $intermediate-ptrs)
    return
    	if ($pj/@scope='branches')
      then $pj/node()
      else $pj
  let $result as xs:string? := 
  	string($context/(@result, parent::tei:joinGrp/@result)[1]) 
  return
  	if ($result)
  	then 
  		element { QName($context/namespace-uri(), $result)} {
      	$joined-elements
      }
    else
     	$joined-elements
};

(:~ find the dependency graph of a given document
 : @param $doc The document
 : @param $visited Dependencies already checked
 : @return A dependency list of database URIs, including the $doc itself
 :)
declare function uri:dependency(
  $doc as document-node(),
  $visited as xs:string*
  ) as xs:string+ {
  let $new-dependencies := 
    distinct-values(
      for $targets in $doc//*[@targets|@target|@domains|@ref]/(@target|@targets|@domains|@ref)
      for $target in 
        tokenize($targets, '\s+')
          [not(starts-with(., '#'))]
          [not(starts-with(., 'http:'))]
          [not(starts-with(., 'https:'))]
      return 
        uri:uri-base-path(
          uri:absolutize-uri($target, $targets/..)
        )
    )
  let $this-uri := document-uri($doc)
  return distinct-values((
    $this-uri,
    for $dependency in $new-dependencies
    let $next-doc := data:doc($dependency)
    where not(document-uri($next-doc)=$visited)
    return
      if (exists($next-doc))
      then 
        uri:dependency(
          $next-doc, 
          ($visited, $this-uri)
        )
      else error(xs:QName("error:DEPENDENCY"), "An unresolvable dependency was found in " || tokenize(document-uri($doc), "/")[last()] ||": The pointer: " || $dependency || " points to a document that does not exist.")
  ))
    
   
};

(:~ range transform, returning nodes in $context that are
 : between $left and $right, inclusive.
 : If $allow-copies is true(), the nodes that are returned
 : may be copies. If they are, their original document URI,
 : base-uri and language
 : will be included as uri:document-uri, uri:base and uri:lang 
 : attributes.
 :)
declare function uri:range-transform(
  $context as node()*,
  $left as node(),
  $right as node(),
  $allow-copies as xs:boolean
  ) as node()* {
  for $node in $context
  return
    if ($node is $right)
    then
     (: special case for $right itself... its descendants
      : should be returned, but won't be because they are
      : after $right
      :)
      if ($allow-copies)
        then
          element {QName(namespace-uri($node), name($node))}{
            attribute uri:document-uri { document-uri(root($node)) },
            if ($node/@xml:lang)
            then ()
            else attribute uri:lang { common:language($node) },
            if ($node/@xml:base)
            then ()
            else attribute uri:base { base-uri($node) },
            $node/(@*|node())
          }
        else
          $node 
    else if (
        ($node << $left or $node >> $right)
        )
    then
      uri:range-transform($node/node(), $left, $right, $allow-copies)
    else
      typeswitch($node)
      case element() 
      return
        if ($allow-copies)
        then
          element {QName(namespace-uri($node), name($node))}{
            attribute uri:document-uri { document-uri(root($node)) },
            if ($node/@xml:lang)
            then ()
            else attribute uri:lang { common:language($node) },
            if ($node/@xml:base)
            then ()
            else attribute uri:base { base-uri($node) },
            $node/@*,
            uri:range-transform($node/node(), $left, $right, $allow-copies)
          }
        else
          ( 
          if ($node/descendant::*[. is $right] and $right/following-sibling::node()) 
          then ()
          else $node, 
          uri:range-transform($node/node(), $left, $right, $allow-copies)
          )
      default return $node 
};

(:~
 : @param $left node pointed to by the left pointer
 : @param $right node pointed to by the right pointer
 : @param $allow-copies If true(), allow returning a copy of the nodes, 
 :  which will result in the nodes being returned in document order and arity,
 :  but without identity to the place of origin.
 :  If false(), return a reference to the nodes, which may be duplicated.  
 : @return The range between $left and $right
 :) 
declare function uri:range(
  $left as node(),
  $right as node(),
  $allow-copies as xs:boolean
  ) as node()* {
  let $start := (
    $left/ancestor::* intersect 
      $right/ancestor::*)[last()]
  return
    if ($left/parent::* is $right/parent::*)
    then
      (: if $left and $right are siblings, no transform is needed :)
      $left | 
      ($left/following-sibling::* intersect $right/preceding-sibling::*) | 
      $right
    else
      uri:range-transform($start, $left, $right, $allow-copies)
};
