xquery version "1.0";
(:~
 : XQuery implementation of grammar parser originally written in XSLT 2.0
 : 
 : A "DTD" for grammars is as follows:
 :
 : <!DOCTYPE p:grammar [
 :  <!ELEMENT p:grammar (p:term+|p:grammar+)>
 :  <!ELEMENT p:term (p:termRef|p:zeroOrOne|p:zeroOrMore|p:oneOrMore|p:termRefAnon|p:exp|p:expAnon|p:choice|p:end)+>
 :  <!ATTLIST p:term name ID #REQUIRED>
 :  <!ELEMENT p:termRef EMPTY>
 :  <!ATTLIST p:termRef name IDREF #REQUIRED>
 :  <!ATTLIST p:termRef alias #CDATA #IMPLIED>
 :  <!ELEMENT p:termRefAnon EMPTY>
 :  <!ATTLIST p:termRefAnon name IDREF #REQUIRED>
 :  <!ELEMENT p:exp #PCDATA>
 :  <!ATTLIST p:exp name ID #IMPLIED>
 :  <!ELEMENT p:expAnon #PCDATA>
 :  <!ELEMENT p:choice (p:termRef|p:zeroOrOne|p:zeroOrMore|p:oneOrMore|p:termRefAnon|p:exp|p:expAnon|p:choice|p:end|p:empty|p:group)+>
 :  <!ELEMENT p:group (p:termRef|p:zeroOrOne|p:zeroOrMore|p:oneOrMore|p:termRefAnon|p:exp|p:expAnon|p:choice|p:end)+>
 :  <!ELEMENT p:end EMPTY>
 :  <!ELEMENT p:empty EMPTY>
 : ]>
 :
 : How it works:
 : Call grammar:parse($string as xs:string, $grammar as node*) as element()+ 
 :       
 : All functions return either:
 :  (r:{term-name}, r:remainder) if a match is found to the term.
 :  (r:no-match, r:remainder) if no match is found.
 :  r:{term name} contains 
 :       Terms may be referenced in grammars by name or anonymously.
 :       Anonymous references (p:termRefAnon, p:expAnon) create r:anonymous 
 :       instead of r:{term-name}, which can be cleaned from the result 
 :       by r:clean().
 :
 :  r:no-match also includes the longest remainder where no match could be found 
 :
 : Open Siddur Project
 : Copyright 2010-2012 Efraim Feinstein 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 :)
module namespace grammar="http://jewishliturgy.org/transform/grammar";

import module namespace expand="http://jewishliturgy.org/transform/grammar/expand"
	at "expand.xqm";
import module namespace clean="http://jewishliturgy.org/transform/grammar/clean"
	at "clean.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
	at "../modules/debug.xqm";

declare namespace p="http://jewishliturgy.org/ns/parser";
declare namespace r="http://jewishliturgy.org/ns/parser-result";

declare variable $grammar:debug-id := "grammar";

(:~ identity template that can stay in the current mode 
 : @param $node node to make identity of 
 : @param $mode function of arity 1 to call on children
 :)
declare function grammar:identity(
	$node as element(),
	$string as xs:string?,
	$string-position as xs:integer
	) as element() {
	element { node-name($node) }{
		$node/@*,
		grammar:grammar($node/node(), $string, $string-position)
	}
};

(:~ Front end to grammar parsing 
 : @param $string String to be parsed
 : @param $start-term Term name to start at
 : @param $grammar Grammar XML
 :) 
declare function grammar:parse(
	$string as xs:string?,
  $start-term as xs:string,
  $grammar as node()
  ) as element()+ {
  let $unexpanded as element()+ :=
      grammar:grammar($grammar//p:term[@name=$start-term], $string)
  return expand:expand($unexpanded, $string)
};

declare function grammar:clean(
	$parsed as element()+
	) as element()+ {
	clean:clean($parsed)
};

(:~ Using a previous result, chain to the next handler if necessary
 : @param previous-result The last result
 :)
declare function local:chain-next(
	$context as node(),
  $string as xs:string?,
  $string-position as xs:integer,
  $previous-result as element()+
  ) as element()* {
	let $match as element()* :=
   	$previous-result/self::r:* except $previous-result/self::r:remainder
  let $remainder as element(r:remainder)? := 
  	if (number($previous-result/self::r:remainder/@end) >= number($previous-result/self::r:remainder/@begin)) 
    then $previous-result/self::r:remainder 
    else ()   
	let $matched-str as xs:string? := string-join($match,'')
  return
  	if ((empty($match) or $match/self::r:no-match) and 
        $context/not(self::p:zeroOrOne or self::p:zeroOrMore))
    then (
    	(: no match to this.  no need to chain. :)
      debug:debug($debug:detail, $grammar:debug-id, 'chain next: CHAIN COMPLETE'),
      <r:no-match>{
        ($match/self::r:no-match/*, $remainder)[1]
      }</r:no-match>,
      $remainder
    )
    else if ($context/parent::p:choice)
    then (
    	(: the parent is a choice element, we don't need to chain continue :)
    	debug:debug($debug:detail, $grammar:debug-id, 'chain next: NOT CHAINING CHOICE'),
      $match, 
      $remainder
    )
    else (
			(: we have a match and are not in a choice construct,
        so we need to chain to the next sibling  :)
      debug:debug($debug:detail,
      	$grammar:debug-id,
      	('chain-next: CHAINING TO ', ($context/following-sibling::*[1]/name(), 'NOTHING')[1], ' remainder=', $remainder)
      ),
      let $chain-result as element()* :=
      	grammar:grammar(
      		$context/following-sibling::element()[1], 
      		$string, 
      		($remainder/@begin, string-length($string) + 1)[1]
      	)
      return
      	if (not($context/following-sibling::*[1]))
      	then ($match, $remainder)
      	else if ($chain-result/self::r:no-match)
      	then (
        	$chain-result/self::r:no-match,
          <r:remainder expand="1" 
          	begin="{min(($match/@begin, $remainder/@begin))}" 
            end="{string-length($string)}"/>
        )
        else ($match, $chain-result)
		)
};

declare function grammar:grammar(
	$node as node()*,
	$string as xs:string
	) as element()* {
	grammar:grammar($node, $string, 1)
};

declare function grammar:grammar(
	$node as node()*,
	$string as xs:string?,
	$string-position as xs:integer
	) as element()* {
	for $n in $node
	return
		typeswitch ($n)
		case element(p:empty) return grammar:p-empty($n, $string, $string-position)
		case element(p:zeroOrOne) return grammar:number($n, $string, $string-position)
		case element(p:zeroOrMore) return grammar:number($n, $string, $string-position)
		case element(p:oneOrMore) return grammar:number($n, $string, $string-position)
		case element(p:term) return grammar:p-term($n, $string, $string-position)
		case element(p:group) return grammar:p-term($n, $string, $string-position)  
		case element(p:choice) return grammar:p-choice($n, $string, $string-position)
		case element(p:termRef) return grammar:p-termRef($n, $string, $string-position)
		case element(p:termRefAnon) return grammar:p-termRef($n, $string, $string-position)
		case element(p:exp) return grammar:p-exp($n, $string, $string-position)
		case element(p:expAnon) return grammar:p-exp($n, $string, $string-position)
		case element(p:end) return grammar:p-end($n, $string, $string-position)
		default return grammar:grammar($n/node(), $string, $string-position)
};

declare function grammar:p-empty(
	$node as element(),
	$string as xs:string?
	) {
	grammar:p-empty($node, $string, 1)
};

(:~ p:empty matches everything 
 : @param $string-position string position (default 1) 
 :)
declare function grammar:p-empty(
	$node as node(),
	$string as xs:string?,
	$string-position as xs:integer
	) as element()+ {
	<r:empty/>,
  if ($string)
  then
  	<r:remainder expand="1" begin="{$string-position}" end="{string-length($string)}"/>
  else ()
};

declare function grammar:number(
	$context as element(),
	$string as xs:string?
	) as element()+ {
	grammar:number($context, $string, 1, 0)
};

declare function grammar:number(
	$context as element(),
	$string as xs:string?,
	$string-position as xs:string
	)  as element()+ {
	grammar:number($context, $string, $string-position, 0)
};
  
(:~ Number
 : matches for p:zeroOrOne|p:zeroOrMore|p:oneOrMore
 :)
declare function grammar:number(
	$context as element(),
	$string as xs:string?,
	$string-position as xs:string,
	$found-already as xs:integer
	) as element()* {
	let $result as element()* :=
		grammar:grammar($context/*[1], $string, $string-position)
	let $match as element()* := 
		$result/self::r:* except ($result/self::r:remainder,$result/self::r:no-match)
  let $remainder as element(r:remainder)? := 
  	$result/self::r:remainder
  return
  	if (empty($match) and $found-already eq 0)
  	then (
    	debug:debug(
    		$debug:detail, $grammar:debug-id,
    		('zeroOrOne|zeroOrMore|oneOrMore: ','NO MATCH for ', $context, ' for string ', 
          debug:abbr-string(substring($string,$string-position)))
      ),
      local:chain-next(
      	$context,
      	$string,
      	$string-position,
      	(
      		if ($context/self::p:zeroOrOne or $context/self::p:zeroOrMore)
          then <r:empty/> 
          else <r:no-match>{$remainder}</r:no-match>,
          <r:remainder expand="1" begin="{$string-position}" end="{string-length($string)}"/>
        )
      )
    )
    else if (empty($match) and $found-already > 0)
    then (
    	(: return remainder back through the recursion :)
      debug:debug(
      	$debug:detail, $grammar:debug-id,
      	('zeroOrOne|zeroOrMore|oneOrMore: ',
      	'NO MATCH and FOUND ALREADY for ', $context, ' for string ', 
          debug:abbr-string(substring($string,$string-position)))
      ),
      $remainder
    )
    else if ($match and $context instance of element(p:zeroOrOne))
    then (
    	debug:debug($debug:detail, $grammar:debug-id, ('zeroOrOne: ', 'MATCH for ', $context, ' for string ', debug:abbr-string($string))),
    	$match,
    	local:chain-next(
    		$context, $string, $string-position, $result
    	)
    )
    else (
    	debug:debug(
    		$debug:detail, $grammar:debug-id,
    		('zeroOrOne|zeroOrMore|oneOrMore: ',
    		'MATCH and *orMore for ', $context, ' for string ', 
          debug:abbr-string(substring($string,$string-position)))
      ),
      let $or-more-match as element()* :=
      	grammar:number(
      		$context,
      		$string,
      		($remainder/@begin, string-length($string) + 1)[1],
      		$found-already + 1
      	)
      return (
        (: $match and zeroOrMore or OneOrMore :)
        if ($found-already eq 0)
        then (
        	debug:debug($debug:info, $grammar:debug-id, 
        	'*OrMore COMPLETED.  Chaining next'),
        	local:chain-next(
        		$context,
        		$string,
        		$string-position,
        		($match,$or-more-match)
        	)
        )
        else (
        	debug:debug($debug:info, $grammar:debug-id, '*OrMore returning chained results'),
          ($match, $or-more-match)
        )
 			)
    )
};

declare function grammar:p-term(
	$context as element(),
	$string as xs:string?
	) as element()+ {
	grammar:p-term($context, $string, 1)
};

(:~ Handle a named term or group :)
declare function grammar:p-term(
	$context as element(),
	$string as xs:string?,
	$string-position as xs:integer
	) as element()+ {
  let $result as element()+ :=
  	grammar:grammar($context/*[1], $string,	$string-position)
  let $this-result as element()+ :=
  	if ($result/self::r:no-match)
  	then (
    	$result/self::r:no-match,
      <r:remainder expand="1" begin="{$string-position}" end="{string-length($string)}"/>
    )
    else (
    	(: term matched :)
    	element {concat("r:", ($context/@name, 'anonymous')[1])}{
      	$result/self::r:* except 
        	($result/self::r:remainder,$result/self::r:no-match)
      },
      $result/self::r:remainder
    )
  return
    if ($context/self::p:group)
    then
    	local:chain-next($context, $string, $string-position, $this-result)
    else $this-result
};

declare function grammar:p-choice(
	$context as element(),
	$string as xs:string?
	) as element()+ {
	grammar:p-choice($context, $string, 1)	
};
   
(:~ Handle multiple choices.  The one that matches to the longest string wins :)
declare function grammar:p-choice(
	$context as element(),
	$string as xs:string?,
	$string-position as xs:integer
	) as element()+ {
	let $result as element(r:choice-match)* :=
		for $e in $context/element()
		return
			element r:choice-match {
      	grammar:grammar($e, $string, $string-position)
      }
  let $successful-matches as element(r:choice-match)* := 
  	$result/self::r:choice-match[not(r:no-match)]
  let $match-length as xs:integer* :=
  	for $s in $successful-matches
  	let $match-element as element()* := $s/(r:* except r:remainder)
  	let $max-difference as xs:integer? :=
    	xs:integer(max($match-element//@end) - min($match-element//@begin))
  	return ($max-difference, 0)[1]
  let $no-result as element()+ := (
  	$result/self::r:choice-match/r:no-match[r:remainder/@begin=max(r:remainder/@begin)][1],
    <r:remainder expand="1" begin="{$string-position}" end="{string-length($string)}"/>
  )
  return (
  	local:chain-next($context, $string, $string-position, 
  		if (exists($successful-matches)) 
      then $successful-matches[number(subsequence(index-of($match-length,max($match-length)),1,1))]/element()
      else $no-result
    )
  )
};    
  
declare function grammar:p-termRef(
	$context as element(),
	$string as xs:string?
	) as element()+ {
	grammar:p-termRef($context, $string, 1)	
};

(:~ Named or anonymous Reference to a term or a group :)
declare function grammar:p-termRef(
	$context as element(),
	$string as xs:string?,
	$string-position as xs:integer
	) as element()+ {
  let $result as element()+ :=
  	grammar:grammar(
  		root($context)//p:term[@name = $context/@name],
  		$string, 
  		$string-position)
  let $matched-part as xs:string :=
  	string-join(
    	$result/(self::* except self::r:remainder)
    	,'')
  return (
  	local:chain-next(
    	$context,
    	$string,
    	$string-position,
    	(: anonymize or alias if necessary :)
      if ($context/self::p:termRefAnon or $context/@alias)
      then (
      	for $r in $result
      	return
      		if ($r/name()=concat('r:',string($context/@name)))
      		then
      			element {concat('r:',if ($context/@alias) then string($context/@alias) else 'anonymous')}{
              $r/node()
            }
          else $r
      )
      else $result
   	)
  )
};    
  
(: Match a named or anonymous expression.  Return r:{@name} or r:anonymous :)
declare function grammar:p-exp(
	$context as element(),
	$string as xs:string?
	) as element()+ {
	grammar:p-exp($string, 1)
};

declare function grammar:p-exp(
	$context as element(),
	$string as xs:string?,
	$string-position as xs:integer
	) as element()+ {
  let $regex := string($context)
  let $result as element()+ :=
  	if ($string-position > string-length($string))
  	then 
  	  let $remainder := 
  	    <r:remainder expand="1" begin="{$string-position}" end="{string-length($string)}"/>
  	  return (
    		if (not($regex))
    		then
        	<r:empty/>
        else
          <r:no-match>{
            $remainder
          }</r:no-match>,
        $remainder
      )
    else (
    	let $string-match as element()? :=
    		let $match as xs:string* := 
    			text:groups(substring($string, $string-position), concat('^(', $regex, ')'))[2]
    		where exists($match)
    		return 
    			element {concat('r:', if ($context/@name) then string($context/@name) else 'anonymous')}{
          	attribute expand { 1 },
          	attribute begin { $string-position },
          	attribute end { $string-position + string-length($match) - 1 }
          }
      return (
      	$string-match,
      	if (max(($string-match/@end + 1,$string-position)) <= string-length($string))
      	then
          <r:remainder expand="1" 
          	begin="{if ($string-match) then ($string-match/@end + 1) else $string-position}" 
            end="{string-length($string)}"/>
        else ()
      )
  	)
  return
  	local:chain-next($context, $string, $string-position, $result)  
};

declare function grammar:p-end(
	$context as element(),
	$string as xs:string?
	) as element()+ {
	grammar:p-end($context, $string, 1)
};

(:~ End of string :)
declare function grammar:p-end(
	$context as element(),
	$string as xs:string?,
	$string-position as xs:integer
	) as element()+ {
	if ($string-position > string-length($string))
	then (
		debug:debug($debug:info, $grammar:debug-id, ('p:end: ', 'FOUND')),
    <r:end/>
  )
  else (
  	debug:debug($debug:info, $grammar:debug-id, ('p:end: ', 'FAIL')),
  	let $remainder :=
  	  <r:remainder expand="1" begin="{$string-position}" end="{string-length($string)}"/>
  	return (
  	  <r:no-match>{
  	    $remainder
  	  }</r:no-match>,
  	  $remainder
  	)
  )          
};
