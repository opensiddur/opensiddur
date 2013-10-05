xquery version "3.0";
(:~ transliterator transform
 : Copyright 2008-2010,2013 Efraim Feinstein, efraim@opensiddur.org
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace translit="http://jewishliturgy.org/transforms/transliterator";

import module namespace uri="http://jewishliturgy.org/transform/uri"
    at "../../modules/follow-uri.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";

(:
    Automated transliterator for Hebrew to Roman (or any other alphabet)
    text.
  	
  	<p>Implementation details: 
	After substituting the Tetragrammaton for the appropriate pronunciation, a word is
	split into independent characters, which are represented in XML as &lt;tr:cc/&gt; elements,
	which are contained in tr:w elements.  Each tr:w element should contain a <strong>grammatical</strong> word.
	cc stands for "complex character."
	This transliterator is a 6 pass processor:
	<ol>
		<li>The "zeroth" pass assembles the shin and shin/sin dots and marks first, 
    last letters of orthographic words and punctuation, and assembles the hiriq male-dagesh</li>
		<li>The first pass assembles multicharacter vowels, such as shuruq, holam male, qamats-he</li>
		<li>The second pass removes vowel letters that are ignored in transliteration</li>
		<li>The third pass marks degeshim as hazak or kal; virtually doubles dagesh hazak</li>
		<li>The fourth pass marks sheva as sheva na or sheva nach, using characters in the private use area</li>
		<li>The fifth pass transliterates using a given table</li>
	</ol>
	</p>
	<p>Partial words that are broken up between elements must be enclosed 
  in tei:w elements, with a chain of @next attributes 
  pointing from the first part to the last.  
  (Partial words are not supported in standalone mode)</p>
:)	

declare variable $translit:hebrew := map {
    "aleph"  := "&#x05d0;",
    "bet" := "&#x05d1;",
    "gimel" := "&#x05d2;",
    "dalet" := "&#x05d3;",
    "he" := "&#x05d4;",
    "vav" := "&#x05d5;",
    "zayin" := "&#x05d6;",
    "het" := "&#x05d7;",
    "tet" := "&#x05d8;",
    "yod" := "&#x05d9;",
    "finalkaf" := "&#x05da;",
    "kaf" := "&#x05db;",
    "lamed" := "&#x05dc;",
    "finalmem" := "&#x05dd;",
    "mem" := "&#x05de;",
    "finalnun" := "&#x05df;",
    "nun" := "&#x05e0;",
    "samekh" := "&#x05e1;",
    "ayin" := "&#x05e2;",
    "finalpe" := "&#x5e3;",
    "pe" := "&#x05e4;",
    "finaltsadi" := "&#x05e5;",
    "tsadi" := "&#x05e6;",
    "qof" := "&#x05e7;",
    "resh" := "&#x05e8;",
    "shin" := "&#x05e9;",
    "tav" := "&#x05ea;",
    "etnahta" := "&#x0591;",
    "accentsegol" := "&#x0592;",
    "shalshelet" := "&#x0593;",
    "zaqefqatan" := "&#x0594;",
    "zaqefgadol" := "&#x0595;",
    "tipeha" := "&#x0596;",
    "revia" := "&#x0597;",
    "zarqa" := "&#x0598;",
    "pashta" := "&#x0599;",
    "yetiv" := "&#x059a;",
    "tevir" := "&#x059b;",
    "geresh" := "&#x059c;",
    "gereshmuqdam" := "&#x059d;",
    "gershayim" := "&#x059e;",
    "qarneypara" := "&#x059f;",
    "telishagedola" := "&#x05a0;",
    "pazer" := "&#x05a1;",
    "atnahhafukh" := "&#x05a2;",
    "munah" := "&#x05a3;",
    "mahapakh" := "&#x05a4;",
    "merkha" := "&#x05a5;",
    "merkhakefula" := "&#x05a6;",
    "darga" := "&#x05a7;",
    "qadma" := "&#x05a8;",
    "telishaqetana" := "&#x05a9;",
    "yerahbenyomo" := "&#x05aa;",
    "ole" := "&#x05ab;",
    "iluy" := "&#x05ac;",
    "dehi" := "&#x05ad;",
    "zinor" := "&#x05ae;",
    "masoracircle" := "&#x05af;",
    "sheva" := "&#x05b0;",
    "hatafsegol" := "&#x05b1;",
    "hatafpatah" := "&#x05b2;",
    "hatafqamats" := "&#x05b3;",
    "hiriq" := "&#x05b4;",
    "tsere" := "&#x05b5;",
    "segol" := "&#x05b6;",
    "patah" := "&#x05b7;",
    "qamats" := "&#x05b8;",
    "holam" := "&#x05b9;",
    "holamhaserforvav" := "&#x05ba;",
    "qubuts" := "&#x05bb;",
    "dageshormapiq" := "&#x05bc;",
    "meteg" := "&#x05bd;",
    "maqaf" := "&#x05be;",
    "rafe" := "&#x05bf;",
    "paseq" := "&#x05c0;",
    "shindot" := "&#x05c1;",
    "sindot" := "&#x05c2;",
    "sofpasuq" := "&#x05c3;",
    "upperdot" := "&#x05c4;",
    "lowerdot" := "&#x05c5;",
    "nunhafukha" := "&#x05c6;",
    "qamatsqatan" := "&#x05c7;",
    "punctuationgeresh" := "&#x05f3;",
    "punctuationgershayim" := "&#x05f4;",
    "schwa" := "&#x259;",
    "lefthalfring" := "&#x2bf;",
    "righthalfring" := "&#x2be;",
    "underline" := "&#x332;",
    "dotbelow" := "&#x323;",
    "acute" := "&#x301;",
    "circumflex" := "&#x302;",
    "macron" := "&#x304;",
    "breve" := "&#x306;",
    "caron" := "&#x30c;",
    "shevana" := "&#xff00;",
    "shevanach" := "&#xff01;",
    "cgj" := "&#x34f;"
};

(:~ transliterate a document.
 : @param $params Expected to include 'translit:table', a document node containing a transliteration table 
 :)
declare function translit:transliterate-document(
    $doc as document-node(),
    $params as map
    ) as document-node() {
    translit:transliterate($doc, $params)
};


(:~ Check if the given context item has a vowel or sheva 
 : (include shuruq and holam male) :)
declare 
    %private 
    function translit:has-vowel(
        $context as element(tr:cc)
    ) as xs:boolean {
    $context/(
        (tr:s|tr:vu|tr:vl|tr:vs) or
        following::tr:cc[1][tr:cons=$translit:hebrew('vav') and 
        (tr:vl=$translit:hebrew('holam') or 
          (tr:d and not(tr:s|tr:vu|tr:vl|tr:vs)))]
    )
};

declare function translit:assemble-word-reverse(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case element(tei:w) return translit:assemble-word-reverse-tei-w($node, $params)
        case text() return $node
        default return translit:assemble-word-reverse($node/node(), $params)
};

(:~
    Find a whole word, reversing through the @next pointers.  
    When the first part is found, go into assemble-word mode.
:)
declare function translit:assemble-word-reverse-tei-w(
    $context as element(tei:w),
    $params as map
    ) as node()* {
    let $context-abs-uri := 
        uri:absolutize-uri(xs:anyURI(concat('#',$context/@xml:id)), $context)
    let $backlink as element(tei:w)? := 
      root($context)//tei:w
        [uri:absolutize-uri(xs:anyURI(@next), .)=$context-abs-uri]
    return
        if ($backlink)
        then
            translit:assemble-word-reverse-tei-w($backlink, $params)
		else
			translit:assemble-word($context, $params)
};

declare function translit:assemble-word(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case element(tei:w) return translit:assemble-word-tei-w($node, $params)
        case text() return translit:assemble-word-text($node, $params)
        case element() return translit:identity($node, $params, translit:assemble-word#2)
        default return translit:assemble-word($node/node(), $params)
};

(:~ Find a whole word, going forward through the @next 
 :   pointers. 
 :)
declare function translit:assemble-word-tei-w(
    $context as element(tei:w),
    $params as map
    ) {
    translit:assemble-word($context/node(), $params),
    if ($context/@next)
    then
        translit:assemble-word(uri:follow-uri($context/@next, $context, -1), $params)
    else ()
};

(:~ Finds the textual part of a whole word; 
 : If it's from the context we're looking for, don't wrap it.  
 : If it isn't, wrap it in tr:ignore tags.
 : @param $params Includes translit:this-context as node()
 :)
declare function translit:assemble-word-text(
    $context as text(),
    $params as map
    ) as node() { 
	if ($context=$params("translit:this-context"))
    then
        $context
    else
        element tr:ignore { $context }
};

declare function translit:replace-tetragrammaton(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case text() return translit:replace-tetragrammaton-text($node, $params)
        case element() return translit:identity($node, $params, translit:replace-tetragrammaton#2)
        default return translit:replace-tetragrammaton($node/node(), $params)
};

(:~ Replaces appearances of the Tetragrammaton with their pronounced versions. Returns an xs:string.  
 : Will only work if the Tetragrammaton is a not broken up.
 :)
declare function translit:replace-tetragrammaton-text(
    $context as text(),
    $params as map
    ) as text() {
    let $word as xs:string := $context/string()
    let $regex := "(" || $translit:hebrew("yod") || "([" || $translit:hebrew("sheva") || "]?)([\P{L}]*)" ||
                  $translit:hebrew("he") || "([\P{L}]*)" || 
                  $translit:hebrew("vav") || "([" || $translit:hebrew("qamats") || $translit:hebrew("patah") || 
                  $translit:hebrew("hiriq") || "])([\P{L}]*)" ||
                  $translit:hebrew("he") || "([\P{L}]*)$)|(" ||
                  $translit:hebrew("yod") || "([" || $translit:hebrew("sheva") || "]?)" ||
                  $translit:hebrew("yod") || "[" || $translit:hebrew("qamats") || "]?$)"
	let $replaced := 
        for $a in analyze-string($word, $regex)/*
        return
            typeswitch ($a)
            case element(fn:match)
            return
				if ($a//fn:group[@nr=5]=$translit:hebrew("hiriq"))
                then
					(: elohim :)
					string-join(
								($translit:hebrew("aleph"),
								if ($a//fn:group[@nr=2]=$translit:hebrew("sheva")) then $translit:hebrew("hatafsegol") else "",
								$a//fn:group[@nr=3]/string(),
								$translit:hebrew("lamed"),
                                $translit:hebrew("holam"),
								$a//fn:group[@nr=4]/string(),
								$translit:hebrew("he"),
                                $translit:hebrew("hiriq"),
								$a//fn:group[@nr=6],
								$translit:hebrew("finalmem"),
								$a//fn:group[@nr=7]/string()
                                ),"")
                else if ($a//fn:group[@nr=8])
                then
                    (: adonai without cantillation :)
                    string-join(
                                ($translit:hebrew("aleph"),
                                if ($a//fn:group[@nr=9]=$translit:hebrew("sheva")) then $translit:hebrew("hatafpatah") else "",
                                $translit:hebrew("dalet"),
                                $translit:hebrew("holam"),
                                $translit:hebrew("nun"),
                                ($a//fn:group[@nr=5], $translit:hebrew("qamats"))[1],
                                $translit:hebrew("yod")
                                ), "")
				else
                    (: adonai :)
					string-join(
								($translit:hebrew("aleph"),
								if ($a//fn:group[@nr=2]=$translit:hebrew("sheva")) then $translit:hebrew("hatafpatah") else "",
								$a//fn:group[@nr=3]/string(),
								$translit:hebrew("dalet"),
                                $translit:hebrew("holam"),
								$a//fn:group[@nr=4]/string(),
								$translit:hebrew("nun"),
								$a//fn:group[@nr=5]/string(),
								$a//fn:group[@nr=6]/string(),
								$translit:hebrew("yod"),
								$a//fn:group[@nr=7]/string()),"")
			default (: non match :) 
            return $a/string()
	return text { string-join($replaced, "") }
};

declare function translit:make-word(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case text() return translit:make-word-text($node, $params)
        case element() return translit:identity($node, $params, translit:make-word#2) 
        default return translit:make-word($node/node(), $params)
};
(:~
	Make a tr:w word filled with tr:cc "complex characters."  
	The result must be processed further to make all of these correct.</xd:short>
	
	A set of complex characters consists of the following elements in the "urn:transliterator" namespace:
		<ul>
			<li>cons: consonant</li>
			<li>s: sheva</li>
			<li>vu: ultrashort vowel</li>
			<li>vs: short vowel</li>
			<li>vl: long vowel</li>
			<li>d: dagesh or rafe</li>
			<li>dot:shin/sin dot</li>
			<li>m: meteg</li>
			<li>al: lower accent</li>
			<li>am: "mid accent" - Unicode character class between 220 and 230, exclusive</li>
			<li>ah: high accent</li>
		</ul>

		The context is the content of the Hebrew word to be converted, which is a Unicode string inside tr:w
:)
declare function translit:make-word-text(
    $context as text(),
    $params as map
    ) as element()* {
    let $word as xs:string := $context/string()
	(: regex order is defined by the idiotic -but at least standard- Unicode normalization chart
		$1=consonant or equivalent 
		$2=sheva
		$3=ultrashort
		$4=short
		$5=long
		$6=dagesh
		$7=meteg
		$8=rafe
		$9=shin/sin dot
		$10=lower accent
		$11=mid accent
		$12=upper accent
	:)
    let $regex := 
		"([\p{Lo}\p{Po}" || $translit:hebrew("cgj") || "])" ||
		"([" || $translit:hebrew("sheva") || "]?)" ||
				"([" || $translit:hebrew("hatafsegol") || "-" || $translit:hebrew("hatafqamats") || "]?)" ||
				"([" || $translit:hebrew("hiriq") || $translit:hebrew("segol") || $translit:hebrew("patah") || $translit:hebrew("qamatsqatan") || $translit:hebrew("qubuts") || "]?)" ||
				"([" || $translit:hebrew("tsere") || $translit:hebrew("qamats") || $translit:hebrew("holam") || $translit:hebrew("holamhaserforvav") || "]?)" ||
			"([" || $translit:hebrew("dageshormapiq") || "]?)" ||
			"([" || $translit:hebrew("meteg") || "]?)" ||
			"([" || $translit:hebrew("rafe") || "]?)" ||
			"([" || $translit:hebrew("shindot") || $translit:hebrew("sindot") || "]?)" ||
			"([" || $translit:hebrew("etnahta") || $translit:hebrew("tevir") || $translit:hebrew("atnahhafukh") || $translit:hebrew("munah") || $translit:hebrew("mahapakh") || $translit:hebrew("merkha") || $translit:hebrew("merkhakefula") || $translit:hebrew("darga") || $translit:hebrew("yerahbenyomo") || $translit:hebrew("lowerdot") || $translit:hebrew("tipeha") || "]?)" ||
			"([" || $translit:hebrew("dehi") || $translit:hebrew("yetiv") || $translit:hebrew("zinor") || "]?)" ||
			"([" || $translit:hebrew("geresh") || $translit:hebrew("shalshelet") || $translit:hebrew("accentsegol") || $translit:hebrew("ole") || $translit:hebrew("iluy") || $translit:hebrew("pazer") || $translit:hebrew("qadma") || $translit:hebrew("zaqefqatan") || $translit:hebrew("zaqefgadol") || $translit:hebrew("telishaqetana") || $translit:hebrew("telishagedola") || $translit:hebrew("qarneypara") || $translit:hebrew("gershayim") || $translit:hebrew("gereshmuqdam") || $translit:hebrew("revia") || $translit:hebrew("zarqa") || $translit:hebrew("pashta") || $translit:hebrew("upperdot") || "]*)"
	for $a in analyze-string(normalize-unicode(normalize-space($word),'NFKD'), $regex)/*
	return
        typeswitch($a)
        case element(fn:match)
        return
			let $complex-character-subelements := 
				('cons','s','vu','vs','vl','d','m','d','dot','al','am','ah')
            return
				element tr:cc {
					for $group in $a/fn:group
                    let $index-num := $group/@nr/number()
                    return
						element { "tr:" || $complex-character-subelements[$index-num] }{
							$group/string()
                        }
				}
	    default (: no match :)
        return (
			element tr:nomatch { $a/string() },
            util:log-system-err(string-join((
				"Encountered a character (", $a/string(), "=#", string-to-codepoints($a/string()), ") in your Hebrew text in the word ", $word, "that doesn't match any known pattern in Hebrew.  This is either a typo or a bug in the transliterator."), ""))
		)	
};

(:~ @param $params translit:table as element(tr:table) :)
declare function translit:transliterate-final(
    $nodes as node()*,
    $params as map
    ) as node()* {
    let $table as element(tr:table)? := $params("translit:table")
    for $node in $nodes
    return
        typeswitch($node)
        case element() return
            (: this has to work as a cascade, to simulate next-match :)
            if ($node/parent::tr:cc[@virtual] and 
                ($table/tr:tr[@from=$node/string()]/@double=('no','false','off'))
                )
            then ((: suppressed virtual doubling :))
            else if (
                $node instance of element(tr:cc) or
                $node instance of element(tr:silent) or 
                $node instance of element(tr:w)
            )
            then translit:transliterate-final-continue($node, $params)
            else if (
                ($node instance of element (tr:cons) and $node[not(tr:suppress) and following-sibling::tr:d])
                and not(contains($node/string(), $translit:hebrew("dageshormapiq") or $node/string()=$translit:hebrew("vav"))) 
            )
            then translit:transliterate-final-different-by-dagesh($node, $params)
            else if (
                $node instance of element(tr:ignore) or
                $node instance of element(tr:suppress) or
                $node/tr:suppress
            )
            then translit:transliterate-final-ignored($node, $params)
            else if ($node[not(tr:suppress) and not(parent::tr:silent)])
            then translit:transliterate-final-non-ignored($node, $params)
            else if ($node instance of element(tr:cons) and $node[parent::tr:silent])
            then translit:transliterate-final-silent($node, $params)
            else translit:identity($node, $params, translit:transliterate-final#2)
        case text() return $node
        default return translit:transliterate-final($node/node(), $params)
};

(:~ continue... :)
declare function translit:transliterate-final-continue(
    $context as element(),
    $params as map
    ) as node()* {
    translit:transliterate-final($context/node(), $params)
};

(:~ If a dagesh letter requires a different transliteration
 :  because it has a dagesh, transliterate it here
 :)
declare function translit:transliterate-final-different-by-dagesh(
    $context as element(),
    $params as map
    ) as text() {
    let $table as element(tr:table)? := $params("translit:table")
    let $text := $context/string()
    return text {
        (
          $table/tr:tr[@from=concat($text, $translit:hebrew("dageshormapiq"))],
          $table/tr:tr[@from=$text]
        )[1]/@to/string()
    }
};

(:~ silent letter: use @silent instead of @to :)
declare function translit:transliterate-final-silent(
    $context as element(tr:cons),
    $params as map
    ) as text() {
    let $table as element(tr:table)? := $params("translit:table")
    return text {
        $table/tr:tr[@from=$context/string()]/@silent/string()
    }
};
  
(:~
 : Transliterate non-ignored text from the table
 : @param $params "translit:table" as element(tr:table)
 :)
declare function translit:transliterate-final-non-ignored(
    $context as element(),
    $params as map
    ) as text()? {
    let $table as element(tr:table)? := $params("translit:table")
    let $text := $context/string()
    return text {
        $table/tr:tr[@from=$text]/@to/string()
    } 
};

(:~ Ignore text under tr:ignore/tr:suppress :)
declare function translit:transliterate-final-ignored(
    $context as element(),
    $params as map
    ) as empty-sequence() {
    ()
};

(:~ @param $params must include a "translit:table" parameter that contains a tr:table element :)
declare function translit:transliterate(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case document-node() return document { translit:transliterate($node/node(), $params) }
        case text() return translit:transliterate-text($node, $params)
        case element() return translit:identity($node, $params, translit:transliterate#2)
        default return translit:transliterate($node/node(), $params)
};

(:~ transliterate raw text
 : @param $params translit:table as element(tr:table)
 :)
declare function translit:transliterate-text(
    $context as text(),
    $params as map
    ) as text()* {
    let $table as element(tr:table) := $params("translit:table")
    for $token in tokenize($context, "\s+")[.]
    let $original := $token
    let $replaced-tetragrammaton as element(tr:w) :=
        let $whole-word as element(tr:w) :=
            element tr:w {
  				if ($context/ancestor::tei:w)
                then translit:assemble-word-reverse($context/ancestor::tei:w, map:new(($params, map { "translit:this-context" := $context } )))
  				else $original
  			}
        return
            if (not($table/tr:option
                [@name='replace-tetragrammaton'][@value=('off','false','no')])
                )
            then
  				translit:replace-tetragrammaton($whole-word, $params)
            else $whole-word
    let $complex-character-word as element(tr:w)? :=
        translit:make-word($replaced-tetragrammaton, $params)
    where (exists($complex-character-word))
    return text {
        string-join(
            let $pass0-result as element(tr:w) :=
                translit:pass0($complex-character-word, $params)
  			let $pass1-result as element(tr:w) :=
                translit:pass1($pass0-result, $params)
            let $pass2-result as element(tr:w) :=
                translit:pass2($pass1-result, $params)  
            let $pass3-result as element(tr:w) :=
                translit:pass3($pass2-result, $params) 
            let $pass4-result as element(tr:w) :=
                translit:pass4($pass3-result, $params) 
            return
                translit:transliterate-final($pass4-result, $params) 
        , "")
    }
};

declare function translit:pass0(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case element(tr:cc) return translit:pass0-tr-cc($node, $params)
        case element() return translit:identity($node, $params, translit:pass0#2)
        case text() return $node
        default return translit:pass0($node/node(), $params)
};
	
(:~ Mark first and last in word with @first or @last; punctuation is marked with @punct; combine shin/sin dot :)
declare function translit:pass0-tr-cc(
    $context as element(tr:cc),
    $params as map
    ) as element(tr:cc) {
    $context/
    element tr:cc {
        @*,	
	    (: mark position; can't use position() because there may be other elements in the hierarchy! :)
		if (not(preceding::tr:cc) or preceding::tr:cc[1][matches(tr:cons/text(),'\p{P}','x')])
        then
			attribute first { 1 }
		else (),
		if (matches(tr:cons/text(),'\p{P}','x'))
        then
            attribute punct { 1 }
        else (),
		if (not(following::tr:cc) or following::tr:cc[1][matches(tr:cons/text(),'\p{P}','x')])
        then
			attribute last { 1 }
		else (),
		(: shin/sin dot :)
        if (tr:dot)
        then (
            element tr:cons {
                concat(tr:cons, tr:dot)
            },
            * except (tr:cons, tr:dot)
        )
        else *
	}
};
	
declare function translit:pass1(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch ($node)
        case element(tr:cc) return
            if ($node[@last][tr:vs=$translit:hebrew("patah")])
            then translit:pass1-furtive-patah($node, $params)
            else if (
                $node
                    [not(tr:vs|tr:s|tr:vl|tr:vu)]
                    [following::tr:cc[1][tr:cons=$translit:hebrew("vav")][tr:vl=$translit:hebrew("holam")]]
            )
            then translit:pass1-preceding-holam-male($node, $params)
            else if ($node[tr:cons=$translit:hebrew("vav")][tr:vl=$translit:hebrew("holam")])
            then translit:pass1-vav-haluma($node, $params)
            else if (
                $node
                    [not(tr:vs|tr:s|tr:vl|tr:vu)]
                    [following::tr:cc[1]
                        [tr:cons=$translit:hebrew("vav")]
                        [tr:d=$translit:hebrew("dageshormapiq")]
                        [not(following::tr:cc[2]
                            [tr:cons=$translit:hebrew("vav")][tr:d=$translit:hebrew("dageshormapiq")])]]
            )
            then translit:pass1-preceding-shuruq($node, $params)
            else if (
                $node
                    [tr:cons=$translit:hebrew("vav")]
                    [tr:d=$translit:hebrew("dageshormapiq")]
                    [not(tr:vl|tr:vs|tr:s)]
                    [not(following::tr:cc[1]
                        [tr:cons=$translit:hebrew("vav")]
                        [tr:d=$translit:hebrew("dageshormapiq") or tr:vl=$translit:hebrew("holam")])
                    ])
            then translit:pass1-vav-with-dagesh($node, $params)
            else if (
                $node
                    [tr:vs=($translit:hebrew("hiriq"),$translit:hebrew("segol")) or tr:vl=$translit:hebrew("tsere")]
                    [following::tr:cc[1][tr:cons=$translit:hebrew("yod")][tr:d or not(translit:has-vowel(.))]]
            )
            then translit:pass1-male-vowels($node, $params)
            else if (
                $node
                    [tr:cons=$translit:hebrew("yod")]
                    [not(tr:s|tr:d|tr:vl|tr:vs|tr:vu)]
                    [preceding::tr:cc[1]
                        [tr:vs=($translit:hebrew("hiriq"),$translit:hebrew("segol")) or tr:vl=$translit:hebrew("tsere")]
                        [not(following::tr:cc[1]
                            [tr:cons=$translit:hebrew("vav")]
                            [((tr:d and not(tr:vl|tr:vs|tr:vu|tr:s)) or tr:vl=$translit:hebrew("holam")) ])]
                    ])
            then translit:pass1-male-vowels-yod($node, $params)
            else if (
                $node
                    [tr:vl=$translit:hebrew("qamats")]
                    [following::tr:cc[1]
                        [tr:cons=$translit:hebrew("he")][not(tr:d)][not(translit:has-vowel(.))]])
            then translit:pass1-qamats-vowel-letter($node, $params)
            else if (
                $node
                    [tr:cons=$translit:hebrew("he")]
                    [not(translit:has-vowel(.))]
                    [not(tr:d)]
                    [preceding::tr:cc[1][tr:vl=$translit:hebrew("qamats")]]
            )
            then translit:pass1-vowel-letter-he($node, $params) 
            else translit:identity($node, $params, translit:pass1#2)
        case element() return translit:identity($node, $params, translit:pass1#2)
        case text() return $node
        default return translit:pass1($node/node(), $params)
};

(:~ Furtive patah.  Reverses the vowel and consonant order. :)
declare function translit:pass1-furtive-patah(
    $context as element(tr:cc),
    $params as map
    ) as element(tr:cc) {
	$context/
    element tr:cc {
		@*,
        if (tr:cons=(
                $translit:hebrew("aleph"),
                $translit:hebrew("he"),
                $translit:hebrew("het"), 
                $translit:hebrew("ayin"),
                $translit:hebrew("resh")
                ))
        then
			(tr:vs,tr:cons,* except (tr:vs,tr:cons))
		else *
	}
};	

(:~ Complex character preceding a holam male.  Adds the holam male. :)
declare function translit:pass1-preceding-holam-male(
    $context as element(tr:cc),
    $params as map
    ) as element(tr:cc) {
    $context/
    element tr:cc {
		@*,
		following::tr:cc[1]/@last, (: holam male can't be first or punct :)
	    tr:cons,
        element tr:vl { $translit:hebrew("vav") || $translit:hebrew("holam") },
        * except tr:cons
    }
};
	
(:~ vav with holam - remove (it's a typographic convention for holam male).  
 : For vav haluma use HEBREW VOWEL HOLAM FOR VAV instead
 :)
declare function translit:pass1-vav-haluma(
    $context as element(tr:cc),
    $params as map
    ) as empty-sequence() {
    ()
};

(:~ Complex character preceding a shuruq; adds the shuruq; ignore two "possible" shuruqs in a row - first is not a shuruq :)
declare function translit:pass1-preceding-shuruq(
    $context as element(tr:cc),
    $params as map
    ) as element(tr:cc) {
	$context/
    element tr:cc {
        following::tr:cc[1]/@last, @*,
        tr:cons, 
        tr:d,
        element tr:vl { $translit:hebrew("vav") || $translit:hebrew("dageshormapiq") },
        * except (tr:cons,tr:d)
	}
};
	
(:~
 : vav with dagesh. 
 :		At beginning of word - replace the current cc with a shuruq vowel only; 
 :		if the preceding consonant has no vowel, it's a shuruq and should be ignored; 
 :		otherwise, it gets copied wholesale because it's a vav with dagesh; ignores first vav-dagesh
 :)
declare function translit:pass1-vav-with-dagesh(
    $context as element(tr:cc),
    $params as map
    ) as element(tr:cc)? {
	$context/(
    if (@first)
    then
		element tr:cc {
			@*,
			element tr:vl { $translit:hebrew("vav") || $translit:hebrew("dageshormapiq") },
			* except (tr:cons, tr:d)
		}
    else if (preceding::tr:cc[1][not(tr:s|tr:vs|tr:vl|tr:vu)])
    then ()
    else .
    )
};

(:~ Hiriq male or long versions of tsere and segol :)
declare function translit:pass1-male-vowels(
    $context as element(tr:cc),
    $params as map
    ) as element(tr:cc) {
    $context/(
        let $table as element(tr:table) := $params("translit:table")    
        let $vowel-male as element() :=
            element tr:vl {
                string-join((
                    tr:vs|tr:vl,
                    $translit:hebrew("yod"),
                    if (tr:vs=$translit:hebrew("hiriq") and 
                        following::tr:cc[1][tr:d] and
                        $table/tr:tr[@from=($translit:hebrew("hiriq") || $translit:hebrew("yod") || $translit:hebrew("dageshormapiq"))])
                    then $translit:hebrew("dageshormapiq")
                    else ()
                ), "")
            }
        return
            element tr:cc {
                following::tr:cc[1]/@last,
                @*, 
                tr:cons,
                $vowel-male,
                * except (tr:cons,tr:vs,tr:vl)
            }
    )
};
	
(:~ Hiriq male and similar, remove the yod (but not when it has a dagesh) :)
declare function translit:pass1-male-vowels-yod(
    $context as element(tr:cc),
    $params as map
    ) as empty-sequence() {
    ()
};

(:
 : 	Check if a qamats is a vowel letter.
 :   Removed @last condition on following tr:cc.
 :   Has to prevent next letter from having a vowel itself or shuruq/holam male
 :)
declare function translit:pass1-qamats-vowel-letter(
    $context as element(tr:cc),
    $params as map
    ) as element(tr:cc) {
    $context/
  	element tr:cc {
  	    following::tr:cc[1]/@last,
  		@*, 
        tr:cons,
        element tr:vl { $translit:hebrew("qamats") || $translit:hebrew("he") },
        * except (tr:cons,tr:vl)
  	}
};
	
(:~ Remove the vowel letter he :)
declare function translit:pass1-vowel-letter-he(
    $context as element(tr:cc),
    $params as map
    ) as element(tr:silent) {
    element tr:silent {
        $context/tr:cons
    }
};

declare function translit:pass2(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case element(tr:cc) return
            if (
                $node
                    [not(@first|@punct)]
                    [not(translit:has-vowel(.))]
                    [following::tr:cc[1]
                        [tr:cons=($translit:hebrew("he"),$translit:hebrew("aleph"))]
                        [not(tr:d)]
                        [not(translit:has-vowel(.))]
                        [not(@last) ]]
            )
            then translit:pass2-preceding-silent($node, $params)
            else if (
                $node
                    [tr:cons=$translit:hebrew("aleph")]
                    [not(tr:d)]
                    [not(translit:has-vowel(.))]
                    [not(preceding::tr:cc[1][tr:s|tr:vs|tr:vu|tr:vl]) or (not(@last))]
                    [not(@first|@punct)]
            )
            then translit:pass2-silent-letter($node, $params)
            else translit:identity($node, $params, translit:pass2#2) 
        case element() return translit:identity($node, $params, translit:pass2#2)
        case text() return $node
        default return translit:pass2($node/node(), $params)
};
	
(:~ Put a vowel on the preceding letter when a silent letter is 
 :   about to be removed.
 :)
declare function translit:pass2-preceding-silent(
    $context as element(tr:cc),
    $params as map
    ) as element(tr:cc) {
    $context/
  	element tr:cc {
        following::tr:cc[1]/@last,
        @*, 
        tr:cons,
        * except tr:cons
  	}
};

(:~ Remove silent letters in the second pass.  
 : 
 : The silent letter may actually have a vowel after the first pass (HOW!?), 
 :   which should be moved (by another function) to the preceding letter
 :)
declare function translit:pass2-silent-letter(
    $context as element(tr:cc),
    $params as map
    ) as element(tr:silent) {
    element tr:silent { $context/tr:cons }
};

declare function translit:pass3(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case element(tr:cc) return
            if ($node
                    [tr:d=$translit:hebrew("dageshormapiq")] 
                    [not(tr:cons[.=$translit:hebrew("he")][@last])]
            )
            then translit:pass3-identify-dagesh($node, $params)
            else translit:identity($node, $params, translit:pass3#2)
        case element() return translit:identity($node, $params, translit:pass3#2)
        case text() return $node
        default return translit:pass3($node/node(), $params)
};

(:~ Try to find whether a dagesh is a kal or hazak.
 :     If hazak, double the letter by adding a "virtual" complex
 :     character before the current one, otherwise join the dagesh
 :     to the consonant.
 :)
declare function translit:pass3-identify-dagesh(
    $context as element(tr:cc),
    $params as map
    ) as element(tr:cc) {
    (: dagesh kal if begedkeft letter at beginning of word or after sheva(nach) :)
    let $is-bgdkft as xs:boolean :=
        $context/tr:cons=(
            $translit:hebrew("bet"),
            $translit:hebrew("gimel"),
            $translit:hebrew("dalet"),
            $translit:hebrew("finalkaf"),
            $translit:hebrew("kaf"),
            $translit:hebrew("finalpe"),
            $translit:hebrew("pe"),
            $translit:hebrew("tav")
        )
    let $is-dagesh-kal as xs:boolean :=
        ($is-bgdkft) and $context/(@first or preceding::tr:cc[1][tr:s])
    let $new-consonant as element(tr:cons) :=
        element tr:cons {
            string-join((
                $context/tr:cons,
                $context/tr:d[$is-bgdkft]
            ), "")
        }
    return
        if ($is-dagesh-kal)
        then
            $context/
            element tr:cc {
                @*, 
                $new-consonant, 
                * except (tr:cons,tr:d)
            }
        else $context/(
            element tr:cc {
                attribute virtual { 1 },
                @first,
                $new-consonant,
                tr:d,
                element tr:s { $translit:hebrew("shevanach") }
            },
            element tr:cc {
                @* except @first, 
                $new-consonant, 
                * except tr:cons
            }
        )
};

declare function translit:pass4(
    $nodes as node()*,
    $params as map
    ) as node()* {
    for $node in $nodes
    return
        typeswitch($node)
        case element(tr:cc) return
            if ($node[tr:s=$translit:hebrew("sheva")])
            then translit:pass4-identify-sheva($node, $params)
            else translit:identity($node, $params, translit:pass4#2)
        case element() return translit:identity($node, $params, translit:pass4#2)
        case text() return $node
        default return translit:pass4($node/node(), $params)
};

(:~ Determine if an indeterminate sheva is na or nach.
 :
 : Rules:
 :     <ul>
 :       <li>First letter in word</li>
 :       <li>Preceding letter had a long vowel or sheva and not last
 :         letter in word</li>
 :       <li>Next letter is not last and with sheva (not the first in a
 :         doubly closed syllable)</li>
 :       <li>First consonant in a sequence of two identical consonants
 :       </li>
 :     </ul>
 :)
declare function translit:pass4-identify-sheva(
    $context as element(tr:cc),
    $params as map
    ) as element(tr:cc) {
    $context/
    element tr:cc {
        @*,
        tr:cons,
        (: removed tr:s and @last from following::tr:cc[1][tr:s] :)
        element tr:s {
            if (
  			    (@first
  			    or preceding::tr:cc[1][tr:vl|tr:s] 
  			    and not(@last))
  			    and not(following::tr:cc[1][tr:s])
  			    or (tr:cons=following::tr:cc[1]/tr:cons)
  			) 
            then $translit:hebrew("shevana")
            else $translit:hebrew("shevanach")
        },
        * except (tr:cons, tr:s)
    }
};

(:~ By default, pass on what already exists in all modes. :)
declare function translit:identity(
    $context as element(),
    $params as map,
    $mode as function(node()*,map) as node()*
    ) as node()* {
    element { QName(namespace-uri($context), name($context)) }{
        $context/(@* except @xml:lang),
        $mode($context/node(), $params)
    }
};

