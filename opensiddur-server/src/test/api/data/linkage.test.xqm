xquery version "3.1";

(:~ Tests for linkage data API
 : Copyright 2020 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)

module namespace t = "http://test.jewishliturgy.org/api/data/linkage";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

import module namespace lnk="http://jewishliturgy.org/api/data/linkage" at "../../../api/data/linkage.xqm";

import module namespace tcommon="http://jewishliturgy.org/test/tcommon" at "../../tcommon.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace a="http://jewishliturgy.org/ns/access/1.0";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";
declare namespace o="http://a9.com/-/spec/opensearch/1.1/";

declare variable $t:existing-linkage-document := document {
<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="">
   <tei:teiHeader>
      <tei:fileDesc>
         <tei:titleStmt>
            <tei:title type="main" xml:lang="en">Existing</tei:title>
               <tei:respStmt>
               <tei:resp key="trc">Transcribed by</tei:resp>
               <tei:name ref="/user/xqtest1">Test User</tei:name>
            </tei:respStmt>
         </tei:titleStmt>
         <tei:publicationStmt>
            <tei:distributor>
               <tei:ref target="http://opensiddur.org">Open Siddur Project</tei:ref>
            </tei:distributor>
            <tei:availability>
               <tei:licence target="http://www.creativecommons.org/publicdomain/zero/1.0"/>
            </tei:availability>
            <tei:date>2012-06-08</tei:date>
         </tei:publicationStmt>
         <tei:sourceDesc>
            <tei:bibl>
               <tei:ptr type="bibl" target="/data/sources/Born%20Digital"/>
               <tei:ptr type="bibl-content" target="#parallel"/>
            </tei:bibl>
         </tei:sourceDesc>
      </tei:fileDesc>
      <tei:revisionDesc>
         <tei:change type="create" when="2012-06-08-04:00">Document created from template</tei:change>
      </tei:revisionDesc>
   </tei:teiHeader>
   <tei:text>
      <tei:front>
        <tei:div>
            <tei:p>Query result</tei:p>
        </tei:div>
      </tei:front>
      <j:parallelText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="parallel">
         <tei:idno>Test Translation</tei:idno>
         <tei:linkGrp domains="/data/original/A-he /data/original/B-en">
            <tei:link target="/data/original/A-he#range(v1_seg1,v1_seg2) /data/original/B-en#range(v1_seg1,v1_seg2)"/>
         </tei:linkGrp>
      </j:parallelText>
   </tei:text>
</tei:TEI>
};

declare variable $t:original-resource-a := document {
<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="he">
   <tei:teiHeader>
      <tei:fileDesc>
         <tei:titleStmt>
            <tei:title type="main" xml:lang="en">A-he</tei:title>
            <tei:respStmt>
                <tei:resp key="trc">Transcribed by</tei:resp>
                <tei:name ref="/user/xqtest1">Test User</tei:name>
            </tei:respStmt>
         </tei:titleStmt>
         <tei:publicationStmt>
            <tei:availability>
               <tei:licence target="http://www.creativecommons.org/publicdomain/zero/1.0"/>
            </tei:availability>
            <tei:distributor>
               <tei:ref xml:lang="en" target="http://opensiddur.org">Open Siddur Project</tei:ref>
            </tei:distributor>
            <tei:date>2012-06-08</tei:date>
         </tei:publicationStmt>
         <tei:sourceDesc>
            <tei:bibl>
               <tei:ptr type="bibl" target="/data/sources/Born%20Digital"/>
               <tei:ptr type="bibl-content" target="#text"/>
            </tei:bibl>
         </tei:sourceDesc>
      </tei:fileDesc>
      <tei:revisionDesc>
         <tei:change xml:lang="en" type="create" when="2012-06-08-04:00">Document created from template</tei:change>
      </tei:revisionDesc>
   </tei:teiHeader>
   <tei:text>
      <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="text">
         <tei:seg xml:id="v1_seg1">
            <tei:w xml:id="v1w1">בְּרֵאשִׁ֖ית</tei:w>
            <tei:w xml:id="v1w2">בָּרָ֣א</tei:w>
            <tei:w xml:id="v1w3">אֱלֹהִ֑ים</tei:w>
         </tei:seg>
         <tei:seg xml:id="v1_seg2">
            <tei:w xml:id="v1w4">אֵ֥ת</tei:w>
            <tei:w xml:id="v1w5">הַשָּׁמַ֖יִם</tei:w>
            <tei:w xml:id="v1w6">וְאֵ֥ת</tei:w>
            <tei:w xml:id="v1w7">הָאָֽרֶץ</tei:w>
            <tei:pc xml:id="v1pc8">׃</tei:pc>
         </tei:seg>
         <tei:seg xml:id="v2_seg1">
            <tei:w xml:id="v2w1">וְהָאָ֗רֶץ</tei:w>
         </tei:seg>
         <tei:seg xml:id="v2_seg2">
            <tei:w xml:id="v2w2">הָיְתָ֥ה</tei:w>
            <tei:w xml:id="v2w3">תֹ֙הוּ֙</tei:w>
            <tei:w xml:id="v2w4">וָבֹ֔הוּ</tei:w>
         </tei:seg>
         <tei:seg xml:id="v2_seg3">
            <tei:w xml:id="v2w5">וְחֹ֖שֶׁךְ</tei:w>
            <tei:w xml:id="v2w6">עַל</tei:w>
            <tei:pc xml:id="v2pc7">־</tei:pc>
            <tei:w xml:id="v2w8">פְּנֵ֣י</tei:w>
            <tei:w xml:id="v2w9">תְה֑וֹם</tei:w>
         </tei:seg>
         <tei:seg xml:id="v2_seg4">
            <tei:w xml:id="v2w10">וְר֣וּחַ</tei:w>
            <tei:w xml:id="v2w11">אֱלֹהִ֔ים</tei:w>
         </tei:seg>
         <tei:seg xml:id="v2_seg5">
            <tei:w xml:id="v2w12">מְרַחֶ֖פֶת</tei:w>
            <tei:w xml:id="v2w13">עַל</tei:w>
            <tei:pc xml:id="v2pc14">־</tei:pc>
            <tei:w xml:id="v2w15">פְּנֵ֥י</tei:w>
            <tei:w xml:id="v2w16">הַמָּֽיִם</tei:w>
            <tei:pc xml:id="v2pc17">׃</tei:pc>
         </tei:seg>
      </j:streamText>
      <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="concurrent">
         <j:layer type="div" xml:id="layer_div">
            <tei:div xml:id="main">
               <tei:head>בראשית</tei:head>
               <tei:ab type="verse">
                  <tei:label n="chapter">1</tei:label>
                  <tei:label n="verse">1</tei:label>
                  <tei:ptr target="#v1_seg1"/>
                  <tei:ptr target="#v1_seg2"/>
               </tei:ab>
               <tei:ab type="verse">
                  <tei:label n="chapter">1</tei:label>
                  <tei:label n="verse">2</tei:label>
                  <tei:ptr target="#v2_seg1"/>
                  <tei:ptr target="#v2_seg2"/>
                  <tei:ptr target="#v2_seg3"/>
                  <tei:ptr target="#v2_seg4"/>
                  <tei:ptr target="#v2_seg5"/>
               </tei:ab>
            </tei:div>
         </j:layer>
      </j:concurrent>
   </tei:text>
</tei:TEI>};

declare variable $t:original-resource-b := document {
<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
   <tei:teiHeader>
      <tei:fileDesc>
         <tei:titleStmt>
            <tei:title type="main" xml:lang="en">B-en</tei:title>

               <tei:respStmt>
               <tei:resp key="trc">Transcribed by</tei:resp>
               <tei:name ref="/user/xqtest1">Test User</tei:name>
            </tei:respStmt>

         </tei:titleStmt>
         <tei:publicationStmt>
            <tei:availability>
               <tei:licence target="http://www.creativecommons.org/publicdomain/zero/1.0"/>
            </tei:availability>
            <tei:distributor>
               <tei:ref target="http://opensiddur.org">Open Siddur Project</tei:ref>
            </tei:distributor>
            <tei:date>2012-06-08</tei:date>
         </tei:publicationStmt>
         <tei:sourceDesc>
            <tei:bibl>
               <tei:ptr type="bibl" target="/data/sources/Born%20Digital"/>
               <tei:ptr type="bibl-content" target="#text"/>
            </tei:bibl>
         </tei:sourceDesc>
      </tei:fileDesc>
      <tei:revisionDesc>
         <tei:change xml:lang="en" type="create" when="2012-06-08-04:00">Document created from template</tei:change>
      </tei:revisionDesc>
   </tei:teiHeader>
   <tei:text>
      <j:streamText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="text">
         <tei:seg xml:id="v1_seg1">
            <tei:w xml:id="v1w1">In</tei:w>
            <tei:w xml:id="v1w2">the</tei:w>
            <tei:w xml:id="v1w3">beginning</tei:w>
            <tei:pc xml:id="v1pc4">,</tei:pc>
         </tei:seg>
         <tei:seg xml:id="v1_seg2">
            <tei:w xml:id="v1w4">God</tei:w>
            <tei:w xml:id="v1w5">created</tei:w>
            <tei:w xml:id="v1w6">the</tei:w>
            <tei:w xml:id="v1w7">heavens</tei:w>
            <tei:w xml:id="v1w8">and</tei:w>
            <tei:w xml:id="v1w9">the</tei:w>
            <tei:w xml:id="v1w10">earth</tei:w>
            <tei:pc xml:id="v1pc11">.</tei:pc>
         </tei:seg>
         <tei:seg xml:id="v2_seg1">
            <tei:w xml:id="v2w1">And</tei:w>
            <tei:w xml:id="v2w2">the</tei:w>
            <tei:w xml:id="v2w3">earth</tei:w>
            <tei:w xml:id="v2w4">was</tei:w>
            <tei:w xml:id="v2w5">without</tei:w>
            <tei:w xml:id="v2w6">form</tei:w>
         </tei:seg>
         <tei:seg xml:id="v2_seg2">
            <tei:w xml:id="v2w7">and</tei:w>
            <tei:w xml:id="v2w8">void</tei:w>
         </tei:seg>
         <tei:seg xml:id="v2_seg3">
            <tei:w xml:id="v2w9">and</tei:w>
            <tei:w xml:id="v2w10">darkness</tei:w>
            <tei:w xml:id="v2w11">was</tei:w>
            <tei:w xml:id="v2w12">on</tei:w>
            <tei:w xml:id="v2w13">the</tei:w>
            <tei:w xml:id="v2w14">face</tei:w>
            <tei:w xml:id="v2w15">of</tei:w>
            <tei:w xml:id="v2w16">the</tei:w>
            <tei:w xml:id="v2w17">deep</tei:w>
            <tei:pc xml:id="v2pc18">.</tei:pc>
         </tei:seg>
         <tei:seg xml:id="v2_seg4">
            <tei:w xml:id="v2w19">And</tei:w>
            <tei:w xml:id="v2w20">the</tei:w>
            <tei:w xml:id="v2w21">spirit</tei:w>
            <tei:w xml:id="v2w22">of</tei:w>
            <tei:w xml:id="v2w23">God</tei:w>
         </tei:seg>
         <tei:seg xml:id="v2_seg5">
            <tei:w xml:id="v2w24">moved</tei:w>
            <tei:w xml:id="v2w25">on</tei:w>
            <tei:w xml:id="v2w26">the</tei:w>
            <tei:w xml:id="v2w27">face</tei:w>
            <tei:w xml:id="v2w28">of</tei:w>
            <tei:w xml:id="v2w29">the</tei:w>
            <tei:w xml:id="v2w30">waters</tei:w>
            <tei:pc xml:id="v2pc31">.</tei:pc>
         </tei:seg>
      </j:streamText>
      <j:concurrent xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="concurrent">
         <j:layer type="div" xml:id="layer_div">
            <tei:div xml:id="main">
               <tei:head>Genesis</tei:head>
               <tei:ab type="verse">
                  <tei:label n="chapter">1</tei:label>
                  <tei:label n="verse">1</tei:label>
                  <tei:ptr target="#v1_seg1"/>
                  <tei:ptr target="#v1_seg2"/>
               </tei:ab>
               <tei:ab type="verse">
                  <tei:label n="chapter">1</tei:label>
                  <tei:label n="verse">2</tei:label>
                  <tei:ptr target="#v2_seg1"/>
                  <tei:ptr target="#v2_seg2"/>
                  <tei:ptr target="#v2_seg3"/>
                  <tei:ptr target="#v2_seg4"/>
                  <tei:ptr target="#v2_seg5"/>
               </tei:ab>
            </tei:div>
         </j:layer>
      </j:concurrent>
   </tei:text>
</tei:TEI>
};

declare variable $t:valid-resource := document {
<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="">
 <tei:teiHeader>
    <tei:fileDesc>
       <tei:titleStmt>
          <tei:title type="main" xml:lang="en">Valid</tei:title>
          <tei:respStmt>
             <tei:resp key="trc">Transcribed by</tei:resp>
             <tei:name ref="/user/testuser">Test User</tei:name>
          </tei:respStmt>
       </tei:titleStmt>
       <tei:publicationStmt>
          <tei:distributor>
             <tei:ref target="http://opensiddur.org">Open Siddur Project</tei:ref>
          </tei:distributor>
          <tei:availability>
             <tei:licence target="http://www.creativecommons.org/publicdomain/zero/1.0"/>
          </tei:availability>
          <tei:date>2012-06-08</tei:date>
       </tei:publicationStmt>
       <tei:sourceDesc>
          <tei:bibl>
             <tei:ptr type="bibl" target="/data/sources/Born%20Digital"/>
             <tei:ptr type="bibl-content" target="#parallel"/>
          </tei:bibl>
       </tei:sourceDesc>
    </tei:fileDesc>
    <tei:revisionDesc>
       <tei:change type="create" when="2012-06-08-04:00">Document created from template</tei:change>
    </tei:revisionDesc>
 </tei:teiHeader>
 <tei:text>
    <tei:front>
      <tei:div>
          <tei:p>Front matter</tei:p>
      </tei:div>
    </tei:front>
    <j:parallelText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="parallel">
       <tei:idno>Test Translation</tei:idno>
       <tei:linkGrp domains="/data/original/A-he /data/original/B-en">
          <tei:link target="/data/original/A-he#range(v1_seg1,v1_seg2) /data/original/B-en#range(v1_seg1,v1_seg2)"/>
       </tei:linkGrp>
    </j:parallelText>
    <tei:back>
      <tei:div>
          <tei:p>Back matter</tei:p>
      </tei:div>
    </tei:back>
 </tei:text>
</tei:TEI>
};

declare variable $t:invalid-resource := document {
<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="">
   <tei:teiHeader>
      <tei:fileDesc>
         <tei:titleStmt>
            <tei:title type="main" xml:lang="en">Invalid</tei:title>

               <tei:respStmt>
               <tei:resp key="trc">Transcribed by</tei:resp>
               <tei:name ref="/user/testuser">Test User</tei:name>
            </tei:respStmt>

         </tei:titleStmt>
         <tei:publicationStmt>
            <tei:availability>
               <tei:licence target="http://www.creativecommons.org/publicdomain/zero/1.0"/>
            </tei:availability>
            <tei:distributor>
               <tei:ref target="http://opensiddur.org">Open Siddur Project</tei:ref>
            </tei:distributor>
            <tei:date>2012-06-08</tei:date>
         </tei:publicationStmt>
         <tei:sourceDesc>
            <tei:bibl>
               <tei:ptr type="bibl" target="/data/sources/Born%20Digital"/>
               <tei:ptr type="bibl-content" target="#parallel"/>
            </tei:bibl>
         </tei:sourceDesc>
      </tei:fileDesc>
      <tei:revisionDesc>
         <tei:change type="create" when="2012-06-08-04:00">Document created from template</tei:change>
      </tei:revisionDesc>
   </tei:teiHeader>
   <tei:text>
      <j:parallelText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="parallel">
        <tei:idno>Has Nonexistent</tei:idno>
        <tei:linkGrp domains="/data/original/Nonexistent">
            <tei:link target="/data/original/Nonexistent#range(v1_seg1,v1_seg2) /data/original/B-en#range(v1_seg1,v1_seg2)"/>
        </tei:linkGrp>
      </j:parallelText>

   </tei:text>
</tei:TEI>
};

declare variable $t:existing-linkage-document-after-put := document {
<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="">
   <tei:teiHeader>
      <tei:fileDesc>
         <tei:titleStmt>
            <tei:title type="main" xml:lang="en">Existing</tei:title>

               <tei:respStmt>
               <tei:resp key="trc">Transcribed by</tei:resp>
               <tei:name ref="/user/xqtest1">Test User</tei:name>
            </tei:respStmt>

         </tei:titleStmt>
         <tei:publicationStmt>
            <tei:distributor>
               <tei:ref target="http://opensiddur.org">Open Siddur Project</tei:ref>
            </tei:distributor>
            <tei:availability>
               <tei:licence target="http://www.creativecommons.org/publicdomain/zero/1.0"/>
            </tei:availability>
            <tei:date>2012-06-08</tei:date>
         </tei:publicationStmt>
         <tei:sourceDesc>
            <tei:bibl>
               <tei:ptr type="bibl" target="/data/sources/Born%20Digital"/>
               <tei:ptr type="bibl-content" target="#parallel"/>
            </tei:bibl>
         </tei:sourceDesc>
      </tei:fileDesc>
      <tei:revisionDesc>
         <tei:change type="create" when="2012-06-08-04:00">Document created from template</tei:change>
      </tei:revisionDesc>
   </tei:teiHeader>
   <tei:text>
      <tei:front>
        <tei:div>
            <tei:p>Query result</tei:p>
        </tei:div>
      </tei:front>
      <j:parallelText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="parallel">
         <tei:idno>Test Translation</tei:idno>
         <tei:linkGrp domains="/data/original/A-he /data/original/B-en">
            <tei:link target="/data/original/A-he#range(v1_seg1,v1_seg2) /data/original/B-en#range(v1_seg1,v1_seg2)"/>
            <tei:link target="/data/original/A-he#range(v2_seg1,v2_seg5) /data/original/B-en#range(v2_seg1,v2_seg5)"/>
         </tei:linkGrp>
      </j:parallelText>
   </tei:text>
</tei:TEI>};

declare variable $t:existing-document-with-invalid-revisionDesc := document {
<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="">
   <tei:teiHeader>
      <tei:fileDesc>
         <tei:titleStmt>
            <tei:title type="main" xml:lang="en">Existing</tei:title>
               <tei:respStmt>
               <tei:resp key="trc">Transcribed by</tei:resp>
               <tei:name ref="/user/xqtest1">Test User</tei:name>
            </tei:respStmt>

         </tei:titleStmt>
         <tei:publicationStmt>
            <tei:distributor>
               <tei:ref target="http://opensiddur.org">Open Siddur Project</tei:ref>
            </tei:distributor>
            <tei:availability>
               <tei:licence target="http://www.creativecommons.org/publicdomain/zero/1.0"/>
            </tei:availability>
            <tei:date>2012-06-08</tei:date>
         </tei:publicationStmt>
         <tei:sourceDesc>
            <tei:bibl>
               <tei:ptr type="bibl" target="/data/sources/Born%20Digital"/>
               <tei:ptr type="bibl-content" target="#parallel"/>
            </tei:bibl>
         </tei:sourceDesc>
      </tei:fileDesc>
      <tei:revisionDesc>
         <tei:change when="2000-01-01" who="/user/xqtest1" type="edited"/>
         <tei:change type="create" when="2012-06-08-04:00">Document created from template</tei:change>
      </tei:revisionDesc>
   </tei:teiHeader>
   <tei:text>
      <tei:front>
        <tei:div>
            <tei:p>Query result</tei:p>
        </tei:div>
      </tei:front>
      <j:parallelText xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0" xml:id="parallel">
         <tei:idno>Test Translation</tei:idno>
         <tei:linkGrp domains="/data/original/A-he /data/original/B-en">
            <tei:link target="/data/original/A-he#range(v1_seg1,v1_seg2) /data/original/B-en#range(v1_seg1,v1_seg2)"/>
            <tei:link target="/data/original/A-he#range(v2_seg1,v2_seg5) /data/original/B-en#range(v2_seg1,v2_seg5)"/>
         </tei:linkGrp>
      </j:parallelText>
   </tei:text>
</tei:TEI>
};

(:~ suite setup :)
declare
    %test:setUp
    function t:setUp() {
    let $users := tcommon:setup-test-users(2)
    let $original-resource-he := tcommon:setup-resource("A-he", "original", 1, $t:original-resource-a)
    let $original-resource-en := tcommon:setup-resource("B-en", "original", 1, $t:original-resource-b)
    return ()
};

(:~ resource set up for tests :)
declare function t:before() {
    let $linkage-resource := tcommon:setup-resource("Existing", "linkage", 1, $t:existing-linkage-document, "none", "everyone", "rw-rw-r--")
    let $no-access-linkage-resource := tcommon:setup-resource("NoAccess", "linkage", 2, $t:existing-linkage-document, "none", "everyone", "rw-------")
    let $no-write-access-linkage-resource := tcommon:setup-resource("NoWriteAccess", "linkage", 2, $t:existing-linkage-document, "none", "everyone", "rw-r--r--")
    return ()
};

(:~ suite teardown :)
declare
    %test:tearDown
    function t:tear-down() {
    let $just-delete-everything := t:after()
    let $original-resource-he := tcommon:teardown-resource("A-he", "original", 1)
    let $original-resource-en := tcommon:teardown-resource("B-en", "original", 1)
    let $users := tcommon:teardown-test-users(2)
    return ()
  };

declare function t:after() {
    let $linkage-resource := tcommon:teardown-resource("Existing", "linkage", 1)
    let $no-access-linkage-resource := tcommon:teardown-resource("NoAccess", "linkage", 2)
    let $no-write-access-linkage-resource := tcommon:teardown-resource("NoWriteAccess", "linkage", 2)
    let $valid-resource := tcommon:teardown-resource("Valid", "linkage", 1)
    return ()
};

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:get-an-existing-resource() {
        t:before(),
        let $result := lnk:get("Existing")
        where empty($result/tei:TEI)
        return <error desc="Returns a resource">{$result}</error>,
        t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:get-combined() {
    t:before(),
    let $result := lnk:get-combined("Existing")
    where empty($result/tei:TEI//jf:merged)
    return
          <error desc="Returns a TEI resource with unflattened data">{$result}</error>,
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:get-a-nonexisting-resource() {
        t:before(),
        let $result := lnk:get("NonExisting")
        return tcommon:not-found($result),
        t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:get-with-no-read-access() {
    t:before(),
    let $result := lnk:get("NoAccess")
    return tcommon:not-found($result),
    t:after()
};

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:list-all-resources() {
    t:before(),
    let $result := lnk:list("", 1, 100)
    return (
        if (count($result//html:li[@class="result"]) >= 1)
        then ()
        else <error desc="returns at least 1 result">{$result}</error>,
        if (every $li in $result//html:li[@class="result"]
            satisfies exists($li/html:a[@class="alt"][@property="access"]))
        then ()
        else <error desc="results include a pointer to access API">{$result}</error>,
        if (every $li in $result//html:li[@class="result"]
            satisfies exists($li/html:a[@class="alt"][@property="combined"]))
        then ()
        else <error desc="results include a pointer to combined API">{$result}</error>,
        tcommon:contains-search-results($result)
    ),
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:list-some-resources() {
    t:before(),
    let $result := lnk:list("", 1, 2)
    return (
        if (count($result//html:li[@class="result"])=2)
        then ()
        else <error desc="returns 2 results">{$result}</error>,
        tcommon:contains-search-results($result)
    ),
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:respond-to-a-query() {
    t:before(),
    let $result := lnk:list("Query", 1, 100)
    return (
        if (count($result//html:ol[@class="results"]/html:li)=2)
        then ()
        else <error desc="returns 2 results (Existing and NoWriteAccess)">{$result}</error>,
        tcommon:contains-search-results($result)
    ),
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:delete-an-existing-resource() {
    t:before(),
    let $result := lnk:delete("Existing")
    return tcommon:no-data($result),
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:delete-a-nonexisting-resource() {
    t:before(),
    let $result := lnk:delete("NonExisting")
    return tcommon:not-found($result),
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:delete-a-resource-without-write-access() {
    t:before(),
    let $result := lnk:delete("NoWriteAccess")
    return tcommon:forbidden($result),
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:post-a-valid-resource() {
    t:before(),
    let $result := lnk:post($t:valid-resource)
    return (
        tcommon:created($result),
        tcommon:deep-equal(
            collection('/db/data/linkage/none')[descendant::tei:title[@type='main'][.='Valid']]//tei:revisionDesc/tei:change[1],
            <tei:change xmlns:tei="http://www.tei-c.org/ns/1.0" type="created" who="/user/xqtest1"
                                                when="..."/>
        )
    ),
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:post-an-invalid-resource() {
    t:before(),
    let $result := lnk:post($t:invalid-resource)
    return tcommon:bad-request($result),
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:put-a-valid-resource() {
        t:before(),
        let $result := lnk:put("Existing", $t:existing-linkage-document-after-put)
        return (
            tcommon:no-data($result),
            tcommon:deep-equal(
                (collection('/db/data/linkage/none')[descendant::tei:title[@type='main'][.='Existing']]//tei:revisionDesc/tei:change)[1],
                <tei:change xmlns:tei="http://www.tei-c.org/ns/1.0" type="edited" who="/user/xqtest1"
                                                    when="..."/>
            )
        ),
        t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:put-a-valid-resource-to-a-nonexisting-resource() {
        t:before(),
        let $result := lnk:put("DoesNotExist", $t:valid-resource)
        return tcommon:not-found($result),
        t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:put-an-invalid-resource() {
        t:before(),
        let $result := lnk:put("Existing", $t:invalid-resource)
        return tcommon:bad-request($result),
        t:after()
    };

declare
    %test:pending
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:put-a-valid-resource-with-an-illegal-change() {
        t:before(),
        let $result := lnk:put("Existing", $t:existing-document-with-invalid-revisionDesc)
        return tcommon:bad-request($result),
        t:after()
    };

declare
    %test:assertEmpty
    function t:unauthenticated-get-an-existing-resource() {
    t:get-an-existing-resource()
    };

declare
    %test:assertEmpty
    function t:unauthenticated-get-an-existing-resource-no-read-access() {
    t:get-with-no-read-access()
    };

declare
    %test:assertEmpty
    function t:unauthenticated-get-a-nonexisting-resource() {
    t:get-a-nonexisting-resource()
    };

declare
    %test:assertEmpty
    function t:unauthenticated-get-a-combined-resource() {
    t:get-combined()
    };

declare
    %test:assertEmpty
    function t:unauthenticated-list-all-resources() {
    t:before(),
    let $result := lnk:list("", 1, 100)
    return (
        if (count($result//html:li[@class="result"]) >= 1)
        then ()
        else <error desc="returns at least 1 result">{$result}</error>,
        if (empty($result//html:li[@class="result"]/html:a[@class="document"]/@href[contains(., "NoAccess")]))
        then ()
        else <error desc="does not list resource with no read access">{$result}</error>,
        tcommon:contains-search-results($result)
    ),
    t:after()
    };

declare
    %test:assertEmpty
    function t:unauthenticated-delete() {
    t:before(),
    let $result := lnk:delete("Existing")
    return tcommon:unauthorized($result),
    t:after()
    };

declare
    %test:assertEmpty
    function t:unauthenticated-delete-nonexisting() {
    t:before(),
    let $result := lnk:delete("DoesNotExist")
    return tcommon:not-found($result),
    t:after()
    };

declare
    %test:assertEmpty
    function t:unauthenticated-post() {
    t:before(),
    let $result := lnk:post($t:valid-resource)
    return tcommon:unauthorized($result),
    t:after()
    };

declare
    %test:assertEmpty
    function t:unauthenticated-put-existing() {
    t:before(),
    let $result := lnk:put("Existing", $t:existing-linkage-document)
    return tcommon:unauthorized($result),
    t:after()
    };

declare
    %test:assertEmpty
    function t:unauthenticated-put-nonexisting() {
    t:before(),
    let $result := lnk:put("DoesNotExist", $t:existing-linkage-document)
    return tcommon:not-found($result),
    t:after()
    };

declare
    %test:assertEmpty
    function t:unauthenticated-get-access() {
    t:before(),
    let $result := lnk:get-access("Existing", ())
    where empty($result/self::a:access)
    return
        <error desc="an access structure is returned">{$result}</error>,
    t:after()
    };

declare
    %test:assertEmpty
    function t:unauthenticated-put-access() {
    t:before(),
    let $result := lnk:put-access("Existing", document{
                                                      <a:access>
                                                        <a:owner>xqtest1</a:owner>
                                                        <a:group write="false">everyone</a:group>
                                                        <a:world read="false" write="false"/>
                                                      </a:access>
                                                      })
    return tcommon:unauthorized($result),
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:get-access() {
    t:before(),
    let $result := lnk:get-access("Existing", ())
    where empty($result/self::a:access)
    return
        <error desc="an access structure is returned">{$result}</error>,
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:get-access-nonexisting() {
    t:before(),
    let $result := lnk:get-access("DoesNotExist", ())
    return tcommon:not-found($result),
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:put-access-with-a-valid-structure() {
    t:before(),
    let $result := lnk:put-access("Existing", document{
                                                      <a:access>
                                                        <a:owner>xqtest1</a:owner>
                                                        <a:group write="true">everyone</a:group>
                                                        <a:world read="true" write="true"/>
                                                      </a:access>
                                                      })
    return tcommon:no-data($result),
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:put-access-nonexisting() {
    t:before(),
    let $result := lnk:put-access("DoesNotExist", document{
                                                      <a:access>
                                                        <a:owner>xqtest1</a:owner>
                                                        <a:group write="true">everyone</a:group>
                                                        <a:world read="true" write="true"/>
                                                      </a:access>
                                                      })
    return tcommon:not-found($result),
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:put-access-with-an-invalid-structure() {
    t:before(),
    let $result := lnk:put-access("Existing", document{
                                                      <a:access>
                                                        <a:invalid/>
                                                      </a:access>
                                                      })
    return tcommon:bad-request($result),
    t:after()
    };

declare
    %test:user("xqtest1", "xqtest1")
    %test:assertEmpty
    function t:put-access-with-no-write-access() {
    t:before(),
    let $result := lnk:put-access("NoWriteAccess", document{
                                                    <a:access>
                                                      <a:owner>xqtest1</a:owner>
                                                      <a:group write="true">everyone</a:group>
                                                      <a:world read="true" write="true"/>
                                                    </a:access>
                                                      })
    return tcommon:forbidden($result),
    t:after()
    };