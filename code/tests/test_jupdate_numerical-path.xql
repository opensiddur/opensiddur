(: Unit test code for the numerical xpath of an item in the database.
 : Should be run in the context of /db/tests/contributors.xml
 : Copyright 2009 Efraim Feinstein
 : Licensed under the GNU Lesser GPL version 3 or later
 :
 : $Id: test_jupdate_numerical-path.xql 411 2010-01-03 06:58:09Z efraim.feinstein $
 :)
xquery version "1.0";
import module namespace
  util="http://exist-db.org/xquery/util";
import module namespace 
  jupdate="http://jewishliturgy.org/ns/functions/nonportable/update"
  at "xmldb:exist:///db/queries/jupdate.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare variable $document-node := doc('/db/tests/contributors.xml');
declare variable $root-node := 
  $document-node/tei:TEI;
declare variable $teitext-node := 
  $root-node/tei:text;
declare variable $attribute-node := 
  $root-node/tei:text/tei:body/tei:div/@type;
declare variable $text-node := 
  $root-node/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title/text()[1];
declare variable $comment-node :=
  $root-node/tei:teiHeader/tei:fileDesc/tei:sourceDesc/comment()[2];

declare function local:test-xpath($node as node()) 
  as xs:boolean {
  let $num-path := jupdate:numerical-path($node)
  return
    boolean(util:eval($num-path) is $node)
};

<paths>
<docnode>{local:test-xpath($document-node)}</docnode>
<TEInode>{local:test-xpath($root-node)}</TEInode>
<teitext>{local:test-xpath($teitext-node)}</teitext>
<attrnode>{local:test-xpath($attribute-node)}</attrnode>
<textnode>{local:test-xpath($text-node)}</textnode>
<commentnode>{local:test-xpath($comment-node)}</commentnode>
</paths>
