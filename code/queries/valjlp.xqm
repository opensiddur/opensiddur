xquery version "1.0";
(:
: Module Name: Validation API for JLPTEI
: Module Version: $Id: valjlp.xqm 269 2009-09-04 02:10:56Z efraim.feinstein $
: Date: August 19, 2009
: Copyright: 2009 Efraim Feinstein <efraim.feinstein@gmail.com>. LGPL 3+
: Proprietary XQuery Extensions Used: 
: XQuery Specification: January 2007
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
module namespace valjlp="http://jewishliturgy.org/ns/functions/validatejlp";

import module namespace 
  jvalidate="http://jewishliturgy.org/ns/functions/nonportable/validation"
  at "xmldb:exist:///db/queries/jvalidate.xqm";
import module namespace 
  contrib="http://jewishliturgy.org/ns/functions/contrib"
  at "xmldb:exist:///db/queries/contrib.xqm";


(:~ Concatenate a number of validation reports into a single-
 : result report 
 :)
declare function valjlp:concatenate-reports(
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

(:~ Validate the document containing the given node as 
 : JLPTEI.  Attempt to determine if it is a special type of file.
 : If it is, validate its additional components.
 : @param $node-or-uri An xs:string or xs:anyURI pointing to a document,
 :  or a node in a document.
 : @return a validation report.
 :)
declare function valjlp:validate-jlptei(
  $node-or-uri as item())
  as element(report) {
  let $doc :=
    typeswitch($doc)
      case $u as xs:string
        return doc($u)
      case $u as xs:anyURI
        return doc($u)
      case $u as node()
        return root($u)
      default
        return error('jvalidate:validate-jlptei' cast as xs:QName,
          '$node-or-uri must be a URI or a node in a document.', $u)
  let $rng-report := 
    jvalidate:validate-relaxng($doc, $jvalidate:path-to-relaxng-schema)
  return
    valjlp:concatenate-reports(
      ($rng-report,
      if ($doc/contrib:is-a()) then contrib:why-invalid-file() else () 
      )
    )
    
};