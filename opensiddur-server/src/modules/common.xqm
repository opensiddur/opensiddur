xquery version "3.0";
(:~
 : Common functions for the transform
 :
 : Open Siddur Project
 : Copyright 2011-2013 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
module namespace common="http://jewishliturgy.org/transform/common";

import module namespace debug="http://jewishliturgy.org/transform/debug"
	at "debug.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri" 
	at "follow-uri.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

(:~ generate a unique, persistent id for a node. replace with xsl:generate-id()
 : @param $node node to create an id for
 :)
declare function common:generate-id(
	$node as node()
	) as xs:string {
	let $docid := 
		let $d := util:document-id($node)
		return
			if ($d)
			then string($d)
			else (
				(: it's a temporary node :)
				debug:debug($debug:warn, 'common:generate-id() used on a temporary node. There is no guarantee the node will always have the same ID', $node),
				util:uuid($node)
			)
	let $nodeid := string(util:node-id($node))
	return
	  string-join(
	    (
	      $node/local-name(), $docid, $nodeid
	    ), "-"
	  )
};

declare function common:copy-attributes-and-context(
  $context as element(),
  $attributes as attribute()*
  ) as attribute()* {
  common:copy-attributes-and-context($context, $attributes, ())
};

(:~ Copy the current context attributes and lang/base
    context, if necessary.  Passing an empty sequence indicates
    that the base or lang should not be added unless an explicit
    attribute is present. :)
declare function common:copy-attributes-and-context(
	$context as element(),
	$attributes as attribute()*,
	$tunnel as map(xs:string, item()*)?
	) as attribute()* {
	let $tunnel := ($tunnel, map {} )[1]
  let $current-base-uri := 
    ($tunnel("current-base-uri"), base-uri($context))[1]
  let $current-document-uri := 
    ($tunnel("current-document-uri"), common:original-document-uri($context))[1]
  let $current-lang := 
    ($tunnel("current-lang"), common:language($context))[1]
  return (
    $attributes//(@* except (@lang,@xml:lang,@xml:base)),
    if ($current-base-uri)
    then
      attribute xml:base { uri:uri-base-resource($current-base-uri) }
    else (),
    if ($current-document-uri)
    then
    	attribute jf:document-uri { uri:uri-base-resource($current-document-uri) }
    else (),
    if ($current-lang)
    then
      attribute xml:lang { $current-lang }
    else (),
  	debug:debug($debug:detail, ('copy-attributes-and-context for ', util:node-xpath($context)), ('lang:', $current-lang, ' base:', $current-base-uri, ' document-uri:', $current-document-uri))
  ) 
};

declare function common:copy-attributes-and-context-if-changed(
  $context as element(),
  $attributes as attribute()*
  ) {
  common:copy-attributes-and-context-if-changed(
    $context, $attributes, ()
  )
};

declare function common:copy-attributes-and-context-if-changed(
	$context as element(),
	$attributes as attribute()*,
	$tunnel as map(xs:string, item()*)
	) as attribute()* {
	common:copy-attributes-and-context-if-changed(
	  $context, $attributes, $tunnel, (), (), ()
	)
};


(:~ Copy attributes and context (xml:base, jf:document-uri, xml:lang) if
    the context is changed, either by coming from a different document or by manual changes.  
    Do not copy @xml:id to prevent invalid XML from repetition.
    @param $context Context of call
    @param $attributes List of attributes to potentially copy
    @param new-document-uri Document URI of the context (defaulted if empty)
    @param new-lang Language of the context (defaulted if empty)</xd:param>
    @param new-base-uri Base URI of context (defaulted if empty)
    @param $tunnel Tunneled parameters:
    	current-document-uri Document URI 
    	current-language Language
    	current-base-uri Base URI
 :)
declare function common:copy-attributes-and-context-if-changed(
	$context as element(),
	$attributes as attribute()*,
	$tunnel as map(xs:string, item()*)?,
  $new-document-uri as xs:anyURI?,
  $new-lang as xs:string?, 
  $new-base-uri as xs:anyURI?
	) as attribute()* {
	let $new-document-uri := (
		$new-document-uri, 
		uri:uri-base-resource(common:original-document-uri($context))
		)[1]
	let $new-lang := (
		$new-lang, 
		common:language($context)
	)[1]
	let $new-base-uri := (
		$new-base-uri,
		uri:uri-base-resource(base-uri($context))
	)[1]
  let $current-document-uri := 
  	(
  	  $tunnel("current-document-uri"),  
      uri:uri-base-resource(
        common:original-document-uri($context/(..,.)[1])
      )
    )[1]
  let $current-lang := 
    (
      $tunnel("current-lang"), 
      common:language($context/(..,.)[1])
  	)[1]
  let $current-base-uri :=
  	(
  		$tunnel("current-base-uri"), 
  		uri:uri-base-resource(base-uri($context/(..,.)[1]))
  	)[1]
	return (
		$attributes//(@* except (@xml:base,@xml:lang,@jf:document-uri)),
    debug:debug($debug:detail, ('copy-attributes-and-context-if-changed for ', util:node-xpath($context)), ('attributes = ', debug:list-attributes($attributes//(@* except (@xml:base,@xml:lang,@jf:document-uri))),' copying = ' , $new-document-uri and not($current-document-uri eq $new-document-uri), '$current-document-uri = ', $current-document-uri, ' $new-document-uri = ', $new-document-uri, ' context:', $context)),
    if ($new-base-uri and not($current-base-uri eq $new-base-uri))
    then
      attribute xml:base { uri:uri-base-resource($new-base-uri) }
    else (),
    if ($new-document-uri and not($current-document-uri eq $new-document-uri))
    then
      attribute jf:document-uri { uri:uri-base-resource($new-document-uri) }
    else (),
    if ($new-lang and not($current-lang eq $new-lang))
    then
      attribute xml:lang { $new-lang }
    else ()
  )
};

(:~ Returns the language of the given node, as it would be tested with the lang() function.
 : If none can be found, returns and empty string.
 : @param $node A single node to return the language for.
 :)
declare function common:language(
  $node as node()
	) as xs:string {
	string($node/ancestor-or-self::*[@xml:lang][1]/@xml:lang)
};

(:~ Return the original document uri of a node, given the 
 :  possibility that processing was done by concurrent.xqm
 :  When this function is called, you want a URI.  
 :  It fails if it cannot give one.
 :  The declaration is xs:anyURI? to prevent a stylesheet error.
 :  The original document URI is determined by (in order):
 :  @jf:source-document-uri, @jf:document-uri (cascading from ancestors) and
 :  the document-uri() function
 :  @param $node The node whose document-uri we are trying to get
 :)
declare function common:original-document-uri( 
	$node as node()
	) as xs:anyURI? {
  let $document-uri as xs:anyURI? := document-uri(root($node))
  let $closest-jf-document-uri as xs:anyURI? :=
      xs:anyURI(
        if ($node instance of document-node())
        then $node/*/(@jf:source-document-uri, @jf:document-uri)[1]
        else $node/
          (@jf:source-document-uri,
          ancestor-or-self::*[@jf:document-uri][1]/@jf:document-uri)[1]
      )
  return    
    ($closest-jf-document-uri, $document-uri)[1]
};

(:~ apply an identity transform until reaching
 : a node in $transition-nodes, then apply
 : $transform 
 : @param $nodes nodes to identity transform
 : @param $transition-nodes transitional nodes
 : @param $transform The transform to apply
 : @param $params Named parameters to pass to the transform
 :)
declare function common:apply-at(
  $nodes as node()*,
  $transition-nodes as node()*,
  $transform as function(node()*, map) as node()*,
  $params as map
  ) as node()* {
  for $node in $nodes
  return
    if (some $t in $transition-nodes satisfies $node is $t)
    then 
      $transform($node, $params)
    else
      typeswitch($node)
      case processing-instruction() return $node
      case comment() return $node
      case text() return $node
      case element()
      return
        element {QName(namespace-uri($node), name($node))}{
          $node/@*,
          common:apply-at($node/node(), $transition-nodes, $transform, $params)
        }
      case document-node() 
      return document { common:apply-at($node/node(), $transition-nodes, $transform, $params) }
      default return common:apply-at($node/node(), $transition-nodes, $transform, $params)
};

(:~ simulate following-sibling::* in sequences
 : @return all items in the sequence $sequence that follow $item
 : $item is a reference, not a value
 :)
declare function common:following(
  $item as item(),
  $sequence as item()*
  ) as item()* {
  subsequence(
    $sequence,
    (: there may be a better way to do this! :) 
    (for $s at $i in $sequence 
    where $s is $item 
    return $i + 1)[1]
  )
};

(:~ simulate preceding-sibling::* in sequences
 : @return all items in the sequence $sequence that precede $item
 : $item is a reference, not a value
 :)
declare function common:preceding(
  $item as item(),
  $sequence as item()*
  ) as item()* {
  subsequence(
    $sequence,
    1,
    (: there may be a better way to do this! :) 
    (for $s at $i in $sequence 
    where $s is $item 
    return $i - 1)[1]
  )
};

(:~ given a language code, determine its direction
 : (rtl, ltr) 
 :)
declare function common:direction-from-language(
  $lang as xs:string
  ) as xs:string {
  switch ($lang)
  case "he" (: Hebrew :)
  case "arc" (: Aramaic :)
  case "ar" (: Arabic :)
  return
    if (contains($lang, "-latn")) (: Latin alphabet transliteration :)
    then "ltr"
    else "rtl"
  default
  return "ltr"
};