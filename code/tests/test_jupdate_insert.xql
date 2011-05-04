(: Unit test code for insertion into the database
 : Efraim Feinstein, LGPL 3+
 :)
xquery version "1.0";
import module namespace 
    jupdate="http://jewishliturgy.org/ns/functions/nonportable/update"
    at "xmldb:exist:///db/queries/jupdate.xqm";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare variable $testItem := (
<tei:item xml:id="test.steven.case">
    <tei:forename>Test</tei:forename>
    <tei:forename>Steven</tei:forename>
    <tei:surname>Case</tei:surname>
    <tei:email>test@aol.com</tei:email>
</tei:item>);
declare variable $list := 
    doc('/db/tests/contributors.xml')/tei:TEI/tei:text/tei:body/tei:div/tei:list;

<a>{jupdate:insert($testItem, 'into', $list)}</a>