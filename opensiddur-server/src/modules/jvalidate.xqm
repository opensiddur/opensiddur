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
 :  <message location=""><!-- text --></message>+
 : </report>
 :)
declare function jvalidate:validate-iso-schematron-svrl(
  $content as item(), $grammar as item()) 
  as element(report) {
  let $grammar-doc :=
    typeswitch($grammar)
    case xs:anyAtomicType
    return doc($grammar)
    default
    return $grammar
  let $result-transform :=
    transform:transform($content, $grammar-doc, 
      <parameters>
        <param name="exist:stop-on-error" value="yes"/>
      </parameters>)
  return (
    <report>
      <status>{
        if ($result-transform/svrl:failed-assert[not(@role="nonfatal")] | 
            $result-transform/svrl:successful-report[not(@role="nonfatal")])
        then 'invalid'
        else 'valid'
      }</status>
      {
        for $failure in $result-transform/svrl:failed-assert | $result-transform/svrl:successful-report
        return
            <message>{
                $failure/@location,
                $failure/svrl:text/node()
            }</message>
      }
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
    {$reports/(* except status)}
  </report> 
};
