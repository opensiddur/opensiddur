xquery version "3.0";
(:~
 : Modes to merge flattened hierarchical layers
 :
 : Open Siddur Project
 : Copyright 2009-2012 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 :)
module namespace merge="http://jewishliturgy.org/transform/merge";

import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "/code/modules/follow-uri.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "/code/modules/debug.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";

(:~ Given a sequence of elements from a flattened hierarchy,
 :  produce equivalent open or closed tags.
 : 
 : If activity is suspend, the tags become suspend tags,
 : if it is continue, they become continue tags.
 :
 : @param $sequence Sequence of opening elements
 : @param $activity May be one of `suspend` or `continue`
 :)
declare function flatten:continue-or-suspend(
  $sequence as element()*,
  $activity as xs:string
	) as element()* {
	for $seq in $sequence
	(: this variable is here to flag an error if there is no @jx:*activity* on the element or more than one :)
	let $current-activity as attribute() :=
  	$seq/(@jx:start,@jx:continue,@jx:end,@jx:suspend)
  return
  	element { node-name($seq) }{
    	$seq/(@* except (@jx:start,@jx:continue,@jx:suspend,@jx:end)),
      attribute {concat('jx:', $activity)}{ $current-activity },
      $seq/node()
    }
};
  
(:~ Find the tags that are closed, but not opened,
 :  in a group of flattened hierarchy.
 :
 : @param $inside-group Group of tags to search within.
 :)
declare function flatten:unopened-tags(
  $inside-group as element()*
  ) as element()* {
  for $closed in ($inside-group[@jx:suspend|@jx:end])
  where not(
  	some $open-id in ($closed/@jx:suspend, $closed/@jx:end)
    satisfies $open-id=($inside-group/@jx:start, $inside-group/@jx:continue)
  )
  return $closed
};
  
(:~ Find tags that are opened, but not closed, in a flattened hierarchy
 : @param $inside-group Group of tags to search within.
 :)
declare function flatten:unclosed-tags(
  $inside-group as element()*
	) as element()* {
  for $opened in ($inside-group[@jx:start|@jx:continue])
  where not(
  	some $open-id in ($opened/@jx:start, $opened/@jx:continue)
    satisfies $open-id=($inside-group/@jx:end, $inside-group/@jx:suspend)
  )
  return $opened
};

(:~ set the @jx:parents and @jx:ancestors attributes of elements in
 :  a flat hierarchy to the xml:ids of the parent and ancestor elements
 :  Uses the parent-id and ancestor-ids tunnel parameters
 :)
declare function flatten:set-parents(
	$context as element(),
	$tunnel as element()?
	) as attribute()* {
	let $parent-id as xs:string? := $tunnel/flatten:parent-id/string()
	let $ancestor-ids as xs:string* := $tunnel/flatten:ancestor-ids/string()
	return (
		(:debug:debug($debug:detail, ('set-parents:tunnel in ', $context), ($tunnel, ' parent-id =', $parent-id, ' ancestor-ids=', string-join($ancestor-ids,' '))),:)
		if (exists($parent-id))
		then attribute jx:parents { $parent-id }
		else (),
		if (exists($ancestor-ids))
		then attribute jx:ancestors { string-join($ancestor-ids,' ') }
		else ()
	)
};

(:~ main entry point for the merge mode, which operates on 
 : streamText
 :)
declare function merge:merge-layers(
  $e as element(j:streamText),
  $layers as element(jf:layer)*
  ) {
  merge:merge($e/*, $layers)
};

declare function merge:merge(
	$node as node()*,
	$layers as element(jf:layer)*
	) as node()* {
	for $n in $node
	return (
		typeswitch($n)
		case text() return $n
		case comment() return $n
		case processing-instruction() return $n
		case element() return merge:element($n)
		case document-node() return document { merge:merge($n/node()) }
		default return merge:merge($n/node())
	)
};

(:~ The "meat" of the merge operation, to be run on
 : the elements in the streamText
 : Combine and dump all of the flat hierarchies, 
 : avoid duplicates
 :)
declare function merge:element(
  $e as element(),
  $layers as element(jf:layer)*
  ) {
  let $xmlid := $e/(@jf:id, @xml:id)[1]
  let $stream := $e/parent::j:streamText
  let $before := 
    for $layer in $layers
    let $equiv := $layer/jf:placeholder[@jf:id=$e/@xml:id]
    return 
      if ($equiv)
      then (
        $equiv/preceding-sibling::node()
        intersect
        $equiv/preceding-sibling::jf:placeholder[1]/following-sibling::node()
      )
      else ()
  let $after :=
    for $layer in $layers
    let $equiv := $layer/jf:placeholder[@jf:id=$e/@xml:id]
    return ()
    (: if this is the last in a layer :)
  return (
    $before,
    element { QName(namespace-uri($e), name($e)) {
      attribute jf:id { $e/@xml:id },
      $e/(@* except @xml:id, node())
    },
    $after
  )
    
    <!-- if a selection has no views (is all external pointers), 
    the pointer should be copied, with xml:id->jx:id, and jx:selection/jx:uid added 
    (should this even be legal?)
    -->
    <xsl:if test="empty($flattened-views)">
      <xsl:copy>
        <xsl:call-template name="copy-attributes-and-context">
          <xsl:with-param name="attributes" as="attribute()*" select="@* except @xml:id"/>
        </xsl:call-template>
        <xsl:if test="@xml:id">
          <xsl:attribute name="jx:id" select="(@jx:id, @xml:id)"/>
        </xsl:if>
        <xsl:attribute name="jx:uid" select="(@jx:uid, generate-id())[1]"/>
        <xsl:attribute name="jx:selection" select="$selection-id"/> 
      </xsl:copy>
    </xsl:if>
    
    <xsl:if test="not(preceding-sibling::tei:ptr)">
      <xsl:for-each select="$flattened-views">
        <xsl:sequence 
          select="tei:ptr[@jx:selection=$selection-id]
            [$xmlid=(@jx:id,@xml:id)]/preceding-sibling::node()"/>
      </xsl:for-each>
    </xsl:if>
    
    <xsl:for-each select="$flattened-views">
      <xsl:variable name="equivalent-ptr" as="element(tei:ptr)?"
        select="tei:ptr[@jx:selection=$selection-id][$xmlid=(@jx:id,@xml:id)]"/>
      <xsl:sequence select="$equivalent-ptr/preceding-sibling::node()
        intersect
        $equivalent-ptr/preceding-sibling::tei:ptr
          [@jx:selection=$selection-id][1]/following-sibling::node()"/>
    </xsl:for-each>
    <xsl:for-each select="$flattened-views[1]/tei:ptr
      [@jx:selection=$selection-id][$xmlid=(@jx:id,@xml:id)]">
      <xsl:copy>
        <xsl:copy-of select="@* (:except @jx:in:)"/>
        <!-- xsl:attribute name="jx:in" 
          select="string-join($flattened-views/tei:ptr[@xml:id=$xmlid]/@jx:in, 
            ' ')"/-->
      </xsl:copy>
    </xsl:for-each>
    <!-- last pointer in the selection, grab all tags -->
    <xsl:if test="not(following-sibling::tei:ptr)">
      <xsl:for-each select="$flattened-views">
        <xsl:sequence select="tei:ptr[@jx:selection=$selection-id]
          [$xmlid=(@xml:id,@jx:id)]/following-sibling::node()"/>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>
