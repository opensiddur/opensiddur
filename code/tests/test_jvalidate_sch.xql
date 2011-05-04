(: Unit test code for validation by schema/RelaxNG
 : should be run in the context of the file to validate
 :
 : Copyright 2009 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser GPL, version 3 or above
 :)
xquery version "1.0";
import module namespace 
    jvalidate="http://jewishliturgy.org/ns/functions/nonportable/validation"
    at "xmldb:exist:///db/queries/jvalidate.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $sch-schema := '/db/schema/header.sch' cast as xs:anyURI;

let $node := root(//tei:TEI)
let $sch-result := jvalidate:validate-iso-schematron-svrl($node, $sch-schema)
return
  <tests>
    <sch>{$sch-result}</sch>
    <sch-bool>{jvalidate:validation-boolean($sch-result)}</sch-bool>
  </tests>