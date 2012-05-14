xquery version "3.0";
(:
: Module Name: Validation API
: Date: August 19, 2009
: Copyright: 2009,2012 Efraim Feinstein <efraim@opensiddur.org>. 
: Licensed under the GNU Lesser General Public License, version 3 or later
: Module Overview: Provides the vendor-specific interfaces to validation.
:   Return values come as report elements.  status can be:
:     "ok", 
:     "invalid", 
:     "valid",
:     "not available"
:)
(:~
 : 
 : @author Efraim Feinstein
 :)
module namespace jvalidate="http://jewishliturgy.org/modules/jvalidate";

import module namespace mirror="http://jewishliturgy.org/modules/mirror"
  at "xmldb:exist:///code/modules/mirror.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace sch="http://purl.oclc.org/dsdl/schematron";
declare namespace svrl="http://purl.oclc.org/dsdl/svrl";
declare namespace error="http://jewishliturgy.org/errors";

declare variable $jvalidate:not-available := (
  <report>
    <status>not available</status>
  </report>
);

declare variable $jvalidate:schema-location :=
  '/db/schema/';

declare function jvalidate:validate-relaxng(
  $content as item(), $grammar as item()) 
  as element(report) {
  validation:jing-report($content, $grammar)
};

(:~ Validate $content using the ISO Schematron schema $grammar
 : Assumes all failed assertions and activated reports are invalid.
 : @param $content The content to validate
 : @param $grammar XSLT-transformed schematron grammar (an XSLT stylesheet)
 : @return The result of the validation as:
 : <report>
 :  <status>valid|invalid</status>
 :  <message><!-- a SVRL document --></message>
 : </report>
 :)
declare function jvalidate:validate-iso-schematron-svrl(
  $content as item(), $grammar as document-node()) 
  as element(report) {
  let $result-transform :=
    transform:transform($content, $grammar, ())
  return (
    <report>
      <status>{
        if ($result-transform/svrl:failed-assert | 
            $result-transform/svrl:successful-report)
        then 'invalid'
        else 'valid'
      }</status>
      <message>{
        $result-transform
      }</message>
    </report>
  )
};

(:~ Validate content against an XML Schema :)
declare function jvalidate:validate-xsd(
  $content as item(), $grammar as item()) 
  as element(report) {
  validation:jing-report($content, $grammar)
};

(:~ Convert the result of a validation performed by one of the other
 : jvalidate functions to a boolean 
 :)
declare function jvalidate:validation-boolean(
  $validation-result as element(report))
  as xs:boolean {
  $validation-result/status = ('valid', 'ok')
};


(:~ Validate the document containing the given node as 
 : JLPTEI.  Attempt to determine if it is a special type of file.
 : If it is, validate its additional components.
 : @param $node-or-uri An xs:string or xs:anyURI pointing to a document,
 :  or a node in a document.
 : @return a validation report.
 :)
declare function jvalidate:validate-jlptei(
  $node-or-uri as item(),
  $additional-grammars as xs:string*)
  as element(report) {
  let $doc :=
    typeswitch($node-or-uri)
      case $u as xs:string
        return doc($u)
      case $u as xs:anyURI
        return doc($u)
      case $u as node()
        return root($u)
      default
        return error('jvalidate:validate-jlptei' cast as xs:QName,
          '$node-or-uri must be a URI or a node in a document.', $node-or-uri)
  let $rng-report := 
    jvalidate:validate-relaxng($doc, $jvalidate:path-to-relaxng-schema)
  return
    jvalidate:concatenate-reports(
      ($rng-report,
      let $grammars as xs:string* :=
          for $schema-ptr in $jvalidate:special-schemas
          return 
            if ($doc//tei:div[@type=$schema-ptr/@key] or 
              $additional-grammars=$schema-ptr/@key) 
            then concat($jvalidate:schema-location, $schema-ptr/@value)
            else ()
      return
        for $grammar in $grammars
        return
         jvalidate:validate-iso-schematron-svrl($doc, $grammar cast as xs:anyURI)
      )
    )
};    

(: jvalidate:validate-jlptei with 1 argument :)
declare function jvalidate:validate-jlptei(
  $node-or-uri as item())
  as element(report) {
  jvalidate:validate-jlptei($node-or-uri, ())
};

(:~ Concatenate a number of validation reports into a single-
 : result report 
 :)
declare function jvalidate:concatenate-reports(
  $reports as element(report)*)
  as element(report) {
  <report>
    <status>{
      let $texts := $reports/status/text()
      return
        if ($texts='invalid') 
        then 'invalid'
        else if ($texts='not available')
        then 'not available'
        else if ($texts=('ok', 'valid'))
        then 'valid'
        else 'not available'
    }</status>
    {$reports/*[not(name()='status')]}
  </report> 
};
