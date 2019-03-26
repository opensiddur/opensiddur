xquery version "3.0";

module namespace t = "http://test.jewishliturgy.org/modules/upgrade12";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace deepequality="http://jewishliturgy.org/modules/deepequality" at "../../modules/deepequality.xqm";

import module namespace upg12="http://jewishliturgy.org/modules/upgrade12" at "../../modules/upgrade12.xqm";

import module namespace ridx="http://jewishliturgy.org/modules/refindex" at "refindex.xqm";
import module namespace magic="http://jewishliturgy.org/magic" at "../../magic/magic.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

declare variable $t:storage-collection := "/db/data/tests";
declare variable $t:reference-file-resource := "Referenced_File.xml";
declare variable $t:external-reference-file-resource := "External_References.xml";

declare variable $t:referenced-file := document {
  <tei:TEI>
    <tei:teiHeader>
      <tei:fileDesc>
        <tei:titleStmt>
          <tei:title xml:lang="en">Test file</tei:title>
        </tei:titleStmt>
      </tei:fileDesc>
      <tei:sourceDesc>
        <tei:bibl j:docStatus="outlined">
          <tei:title>Biblio</tei:title>
          <tei:ptr xml:id="non_seg_internal_ptr" type="bibl-content" target="#stream"/>
        </tei:bibl>
      </tei:sourceDesc>
    </tei:teiHeader>
    <tei:text>
      <j:streamText xml:id="stream">
        <tei:anchor xml:id="begin_p_1"/>
        <tei:seg xml:id="seg_1">seg 1</tei:seg>
        <tei:seg xml:id="seg_2">middle segment.</tei:seg>
        <tei:seg xml:id="seg_3">
          <tei:w>segment</tei:w>
          <tei:w>with</tei:w>
          <tei:w>internal</tei:w>
          <tei:w>structure</tei:w>
        </tei:seg>
        <tei:ptr xml:id="internal_ptr_to_segments" target="#range(seg_1,seg_3)"/>
        <tei:ptr xml:id="internal_ptr_to_one_segment" target="#seg_3"/>
        <tei:anchor xml:id="end_p_1"/>
        <tei:seg xml:id="seg_4">Referenced by an internal pointer</tei:seg>
        <tei:seg xml:id="seg_5">Outside a streamText</tei:seg>
        <tei:anchor xml:id="begin_p_3"/>
        <tei:seg xml:id="seg_6">Referenced externally without a range</tei:seg>
        <tei:seg xml:id="seg_7">Unreferenced.</tei:seg>
        <tei:seg xml:id="seg_8">Referenced externally</tei:seg>
        <tei:seg xml:id="seg_9">with</tei:seg>
        <tei:seg xml:id="seg_10">a range.</tei:seg>
        <tei:seg xml:id="seg_11">Multiple</tei:seg>
        <tei:seg xml:id="seg_12">range</tei:seg>
        <tei:seg xml:id="seg_13">references</tei:seg>
        <tei:seg xml:id="seg_14">in the</tei:seg>
        <tei:seg xml:id="seg_15">same ptr</tei:seg>
        <tei:ptr xml:id="external_ptr" target="http://www.external.com"/>
        <tei:anchor xml:id="end_p_3"/>
      </j:streamText>
      <j:concurrent type="p">
        <tei:p>
          <tei:ptr xml:id="internal_ptr_to_anchors" target="#range(begin_p_1,end_p_1)"/>
        </tei:p>
        <tei:p>
          <tei:ptr xml:id="internal_ptr_to_segs" target="#range(seg_4,seg_5)"/>
        </tei:p>
        <tei:p>
          <tei:ptr xml:id="multiple_references_in_one" target="#range(seg_11,seg_12) #seg_13 #range(seg_14,seg_15)"/>
        </tei:p>
      </j:concurrent>
    </tei:text>
  </tei:TEI>
};
declare variable $t:expected-referenced-file := document {
  <tei:TEI>
    <tei:teiHeader>
      <tei:fileDesc>
        <tei:titleStmt>
          <tei:title xml:lang="en">Test file</tei:title>
        </tei:titleStmt>
      </tei:fileDesc>
      <tei:sourceDesc>
        <tei:bibl j:docStatus="outlined">
          <tei:title>Biblio</tei:title>
          <tei:ptr xml:id="non_seg_internal_ptr" type="bibl-content" target="#stream"/>
        </tei:bibl>
      </tei:sourceDesc>
    </tei:teiHeader>
    <tei:text>
      <j:streamText xml:id="stream">
        <tei:anchor xml:id="begin_p_1"/>
        <tei:anchor xml:id="seg_1"/>seg 1 middle segment. <tei:anchor xml:id="seg_3"/>
        <tei:w>segment</tei:w>
        <tei:w>with</tei:w>
        <tei:w>internal</tei:w>
        <tei:w>structure</tei:w>
        <tei:anchor xml:id="seg_3_end"/> <tei:ptr xml:id="internal_ptr_to_segments" target="#range(seg_1,seg_3_end)"/>
        <tei:ptr xml:id="internal_ptr_to_one_segment" target="#range(seg_3,seg_3_end)"/>
        <tei:anchor xml:id="end_p_1"/>
        <tei:anchor xml:id="seg_4"/>Referenced by an internal pointer Outside a streamText<tei:anchor xml:id="seg_5_end"/> <tei:anchor xml:id="begin_p_3"/>
        <tei:anchor xml:id="seg_6"/>Referenced externally without a range<tei:anchor xml:id="seg_6_end"/> Unreferenced. <tei:anchor xml:id="seg_8"/>Referenced externally with a range.<tei:anchor xml:id="seg_10_end"/> <tei:anchor xml:id="seg_11"/>Multiple range<tei:anchor xml:id="seg_12_end"/> <tei:anchor xml:id="seg_13"/>references<tei:anchor xml:id="seg_13_end"/> <tei:anchor xml:id="seg_14"/>in the same ptr<tei:anchor xml:id="seg_15_end"/> <tei:ptr xml:id="external_ptr" target="http://www.external.com"/>
        <tei:anchor xml:id="end_p_3"/>
      </j:streamText>
      <j:concurrent type="p">
        <tei:p>
          <tei:ptr xml:id="internal_ptr_to_anchors" target="#range(begin_p_1,end_p_1)"/>
        </tei:p>
        <tei:p>
          <tei:ptr xml:id="internal_ptr_to_segs" target="#range(seg_4,seg_5_end)"/>
        </tei:p>
        <tei:p>
          <tei:ptr xml:id="multiple_references_in_one" target="#range(seg_11,seg_12_end) #range(seg_13,seg_13_end) #range(seg_14,seg_15_end)"/>
        </tei:p>
      </j:concurrent>
    </tei:text>
  </tei:TEI>
};

declare variable $t:external-references-file := document {
  <tei:TEI>
    <tei:teiHeader>
      <tei:fileDesc>
        <tei:titleStmt>
          <tei:title xml:lang="en">External reference file</tei:title>
        </tei:titleStmt>
      </tei:fileDesc>
    </tei:teiHeader>
    <tei:text>
      <j:streamText xml:id="stream">
        <tei:ptr xml:id="external_reference_to_stream" target="/data/tests/Referenced_File#stream"/>
        <tei:ptr xml:id="external_reference_to_seg" target="/data/tests/Referenced_File#seg_6"/>
        <tei:ptr xml:id="external_reference_to_range" target="/data/tests/Referenced_File#range(seg_8,seg_10)"/>
        <tei:ptr xml:id="external_reference_to_ptr" target="/data/tests/Referenced_File#external_ptr"/>
      </j:streamText>
    </tei:text>
  </tei:TEI>
};
declare variable $t:expected-external-references-file := document {
  <tei:TEI>
    <tei:teiHeader>
      <tei:fileDesc>
        <tei:titleStmt>
          <tei:title xml:lang="en">External reference file</tei:title>
        </tei:titleStmt>
      </tei:fileDesc>
    </tei:teiHeader>
    <tei:text>
      <j:streamText xml:id="stream">
        <tei:ptr xml:id="external_reference_to_stream" target="/data/tests/Referenced_File#stream"/>
        <tei:ptr xml:id="external_reference_to_seg" target="/data/tests/Referenced_File#range(seg_6,seg_6_end)"/>
        <tei:ptr xml:id="external_reference_to_range" target="/data/tests/Referenced_File#range(seg_8,seg_10_end)"/>
        <tei:ptr xml:id="external_reference_to_ptr" target="/data/tests/Referenced_File#external_ptr"/>
      </j:streamText>
    </tei:text>
  </tei:TEI>
};

declare
%test:setUp
function t:setup() {
  let $tests-collection :=
    system:as-user("admin", $magic:password, (
      xmldb:create-collection("/db/data", "tests"),
      sm:chmod(xs:anyURI("/db/data/tests"), "rwxrwxrwx")
    ))
  let $store-referenced-file :=
    xmldb:store($t:storage-collection, $t:reference-file-resource, $t:referenced-file)
  let $store-external-references-file :=
    xmldb:store($t:storage-collection, $t:external-reference-file-resource, $t:external-references-file)
  let $index-stored-files := ridx:reindex(collection($t:storage-collection))
  return ()
};

declare
%test:tearDown
function t:tear-down() {
  ridx:remove($t:storage-collection, $t:reference-file-resource),
  ridx:remove($t:storage-collection, $t:external-reference-file-resource),
  xmldb:remove($t:storage-collection, $t:reference-file-resource),
  xmldb:remove($t:storage-collection, $t:external-reference-file-resource),
  xmldb:remove("/db/data/tests")
};


declare
%test:assertEmpty
function t:test-upgrade-changes-reference-file() as document-node()? {
  let $do-upgrade := upg12:upgrade(doc($t:storage-collection || "/" || $t:reference-file-resource))
  return deepequality:equal-or-result($do-upgrade, $t:expected-referenced-file)
};

declare
%test:assertEmpty
function t:test-upgrade-changes-external-reference-file() as document-node()? {
  let $do-upgrade := upg12:upgrade(doc($t:storage-collection || "/" || $t:external-reference-file-resource))
  return deepequality:equal-or-result($do-upgrade, $t:expected-external-references-file)
};