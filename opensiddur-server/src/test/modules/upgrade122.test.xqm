xquery version "3.0";

module namespace t = "http://test.jewishliturgy.org/modules/upgrade122";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace deepequality="http://jewishliturgy.org/modules/deepequality" at "../../modules/deepequality.xqm";

import module namespace upg122="http://jewishliturgy.org/modules/upgrade122" at "../../modules/upgrade122.xqm";

import module namespace ridx="http://jewishliturgy.org/modules/refindex" at "refindex.xqm";
import module namespace magic="http://jewishliturgy.org/magic" at "../../magic/magic.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

declare variable $t:storage-collection := "/db/data/tests";
declare variable $t:file-resource := "Test_File.xml";

declare variable $t:test-file := document {
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
    <j:links>
      <tei:link type="note" target="#referenced_w #note"/>
    </j:links>
    <j:annotations>
      <tei:note xml:id="note">Note</tei:note>
    </j:annotations>
    <tei:text>
      <j:streamText xml:id="stream">
        <tei:anchor xml:id="anchor1"/>{ text { "    " } }
        <tei:w xml:id="unreferenced_w">w1</tei:w>{ text { "    " } }
        <tei:w xml:id="referenced_w">w2</tei:w>{ text { "    " } }
        <tei:choice><j:read>unreferenced</j:read><j:written>with child nodes</j:written></tei:choice>
        { text { "             text node                    " } }
        <tei:anchor xml:id="unreferenced_anchor"/>
        <tei:w>אבג</tei:w>{ text { "    " } }
      <tei:pc>־</tei:pc>{ text { "    " } }
        <tei:w>דהו</tei:w>{ text { "    " } }
      <tei:w>זחט</tei:w>{ text { "    " } }
      <tei:pc>׃</tei:pc>{ text { "    " } }
      <tei:w>יכל</tei:w>{ text { "    " } }
      <tei:pc>׀</tei:pc>{ text { "    " } }
      <tei:w>מנס</tei:w>{ text { "    " } }
        <tei:anchor xml:id="anchor2"/>
      </j:streamText>
      <j:concurrent type="p">
        <tei:p>
          <tei:ptr xml:id="p1" target="#range(anchor1,anchor2)"/>
        </tei:p>
      </j:concurrent>
    </tei:text>
  </tei:TEI>
};

declare variable $t:transformed := document {
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
    <j:links>
      <tei:link type="note" target="#referenced_w #note"/>
    </j:links>
    <j:annotations>
      <tei:note xml:id="note">Note</tei:note>
    </j:annotations>
    <tei:text>
      <j:streamText xml:id="stream">
        <tei:anchor xml:id="anchor1"/> w1 <tei:w xml:id="referenced_w">w2</tei:w> <tei:choice>
          <j:read>unreferenced</j:read>
          <j:written>with child nodes</j:written>
      </tei:choice>{ text { "             text node                    אבג־דהו זחט׃ יכל ׀ מנס "}}<tei:anchor xml:id="anchor2"/>
      </j:streamText>
      <j:concurrent type="p">
        <tei:p>
          <tei:ptr xml:id="p1" target="#range(anchor1,anchor2)"/>
        </tei:p>
      </j:concurrent>
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
    xmldb:store($t:storage-collection, $t:file-resource, $t:test-file)
  let $index-stored-files := ridx:reindex(collection($t:storage-collection))
  return ()
};

declare
%test:tearDown
function t:tear-down() {
  ridx:remove($t:storage-collection, $t:file-resource),
  xmldb:remove($t:storage-collection, $t:file-resource),
  xmldb:remove("/db/data/tests")
};

declare
%test:assertEmpty
function t:test-upgrade-122-changes-file() as document-node()? {
  let $do-upgrade := upg122:upgrade122(doc($t:storage-collection || "/" || $t:file-resource))
  return deepequality:equal-or-result($do-upgrade, $t:transformed)
};
