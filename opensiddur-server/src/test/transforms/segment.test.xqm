xquery version "3.0";

module namespace t = "http://test.jewishliturgy.org/transform/segment";

import module namespace segment="http://jewishliturgy.org/transform/segment" at "../../transforms/segment.xqm";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace deepequality="http://jewishliturgy.org/modules/deepequality" at "../../modules/deepequality.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

declare variable $t:no-streamText-input :=
  document {
    <tei:TEI>
      <tei:teiHeader>
        <tei:title>Something</tei:title>
      </tei:teiHeader>
      <tei:text n="an attribute">
        <!-- comment node -->
        <tei:p xml:id="xid">A text node</tei:p>
      </tei:text>
    </tei:TEI>
  };

declare variable $t:streamText-input :=
  <j:streamText>
    One text node
    <tei:ptr xml:id="ptr" target="somewhere"/>
    Another text node
    <tei:anchor xml:id="anchor"/>


    <tei:w>has no xml:id</tei:w>
    Space    inside    text
    nodes    is normalized.
  </j:streamText>;

declare variable $t:expected-streamText-output :=
  <j:streamText>
    <jf:textnode xml:id="...">One text node</jf:textnode>
    <tei:ptr xml:id="ptr" target="somewhere"/>
    <jf:textnode xml:id="...">Another text node</jf:textnode>
    <tei:anchor xml:id="anchor"/>
    <tei:w xml:id="...">has no xml:id</tei:w>
    <jf:textnode xml:id="...">Space inside text nodes is normalized.</jf:textnode>
  </j:streamText>;


declare
  %test:assertEmpty
  function t:test-segment-is-identity-with-no-streamText() {
  let $segmented := segment:segment($t:no-streamText-input)
  return deepequality:equal-or-result($segmented,  $t:no-streamText-input)
};

declare
  %test:assertEmpty
  function t:test-text-nodes-are-segmented-inside-streamText() {
  let $segmented := segment:segment($t:streamText-input)
  return deepequality:equal-or-result($segmented, $t:expected-streamText-output)
};