xquery version "1.0";
(:
: Module Name: Validation API
: Module Version: $Id: jvalidate.xqm 491 2010-03-28 03:40:29Z efraim.feinstein $
: Date: August 19, 2009
: Copyright: 2009 Efraim Feinstein <efraim.feinstein@gmail.com>. LGPL 3+
: Proprietary XQuery Extensions Used: eXist validation API, 
:   eXist transform API
:   eXist utility API 
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
module namespace 
    jvalidate="http://jewishliturgy.org/ns/functions/validation";

import module namespace validation="http://exist-db.org/xquery/validation";
import module namespace transform="http://exist-db.org/xquery/transform";
import module namespace util="http://exist-db.org/xquery/util";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace svrl="http://purl.oclc.org/dsdl/svrl";
declare namespace jvalidate="http://jewishliturgy.org/ns/functions/validation";

declare variable $jvalidate:not-available := (
  <report>
    <status>not available</status>
  </report>
);

(: map special schematron schemas to div types :)
declare variable $jvalidate:special-schemas := (
  <jvalidate:map key="bibliography" value="biblio.sch"/>,
  <jvalidate:map key="contributors" value="contrib.sch"/>,
  <jvalidate:map key="profile" value="profile.sch"/>
  );

declare variable $jvalidate:schema-location :=
  '/db/code/schema/';

declare variable $jvalidate:CACHE-COLLECTION := '/cache';
declare variable $jvalidate:CACHE-EXTENSION := '.xml';
declare variable $jvalidate:path-to-relaxng-schema :=
  'xmldb:exist:///db/schema/jlptei.rng'
  cast as xs:anyURI;
declare variable $jvalidate:path-to-schematron-include := 
  'xmldb:exist:///db/schema/iso-schematron/iso_dsdl_include.xsl'
  cast as xs:anyURI;
declare variable $jvalidate:path-to-schematron-abstract := 
  'xmldb:exist:///db/schema/iso-schematron/iso_abstract_expand.xsl' 
  cast as xs:anyURI;
declare variable $jvalidate:path-to-schematron-xsl := 
  'xmldb:exist:///db/schema/iso-schematron/iso_svrl_for_xslt2.xsl' 
  cast as xs:anyURI;


(:~ XSLT transform $source using the stylesheet $transform, and save
 : the result in the transform cache.  If the cached result is newer than
 : both the transform and the source, return the cached result.
 : Note: the cache will only work properly for parameters either:
 : given as xs:anyURI or where the document is stored in the database.
 :
 : @param $chain-source The URI of the first file in a processing chain.
 :    May be empty if $source is stored in a document.
 :    The chain source should be the last stored step in the chain.
 : @param $source The source to transform as xs:anyURI or node()
 : @param $transform The XSLT stylesheet as xs:anyURI or node()
 : @param $parameters Parameters to pass to the stylesheet  
 : @param $serialization-options Options to be passed to transform:transform()
 : @return The result of the transform
 :)
declare function jvalidate:transform-cache($chain-source as xs:anyURI?,
  $source as node(), $transform as item(), $parameters as node()?, 
  $serialization-options as xs:string?) 
  as item()? {
  let $source-document-uri := document-uri(root($source))
  let $source-uri := 
    if (empty($source-document-uri)) 
    then $chain-source
    else $source-document-uri
  let $source-available := doc-available($source-uri)
  let $source-collection-name := 
    if ($source-available) 
    then util:collection-name(root($source))
    else ()
  let $source-document-name := 
    if ($source-available) 
    then util:document-name(root($source))
    else ()
  let $source-time := 
    if ($source-available)
    then xmldb:last-modified($source-collection-name, $source-document-name)
    else ()
  let $transform-uri :=
    typeswitch($transform)
      case $t as node()
        return document-uri(root($t))
      case $t as xs:anyURI
        return $t
      case $t as xs:string
        return $t cast as xs:anyURI
      default
        return error('jvalidate:transform-cache' cast as xs:QName,
          '$transform must be a node or URI', $transform)          
  let $transform-available := doc-available($transform-uri)
  let $transform-collection-name := 
    if ($transform-available) 
    then util:collection-name(string($transform-uri))
    else ()    
  let $transform-document-name := 
    if ($transform-available) 
    then util:document-name(string($transform-uri))
    else ()    
  let $transform-time := 
    if ($transform-available)
    then xmldb:last-modified($transform-collection-name, 
      $transform-document-name)
    else ()    
  let $result-cache-collection := 
    if (xmldb:collection-available($jvalidate:CACHE-COLLECTION))
    then $jvalidate:CACHE-COLLECTION
    else if (empty(
      xmldb:create-collection('/db', $jvalidate:CACHE-COLLECTION)))
    then ()
    else $jvalidate:CACHE-COLLECTION
  let $result-cache-name := 
    if ($source-available and $transform-available) 
    then string-join(($source-document-name, '-', $transform-document-name, 
      $jvalidate:CACHE-EXTENSION), '')
    else ()
  let $result-cache-uri := 
    if (empty($result-cache-name))
    then ()
    else string-join(($result-cache-collection, '/', $result-cache-name), '')
  let $result-cache-available := doc-available($result-cache-uri)
  let $result-cache-time := 
    if ($result-cache-available) 
    then xmldb:last-modified($result-cache-collection, $result-cache-name)
    else ()
  return
    if (empty($result-cache-time) or
      ($result-cache-time < $transform-time) or
      ($result-cache-time < $source-time))
    then 
      let $result := 
        if (empty($serialization-options)) 
        then transform:transform($source, $transform, $parameters)
        else transform:transform($source, 
          $transform, $parameters, $serialization-options)
      let $cached := 
        if ($result-cache-available) 
        then xmldb:store($result-cache-collection, 
          $result-cache-name, $result)
        else ()
      return
        (
        util:log('debug',
        ('jvalidate:transform-cache: NOT using cached copy for: ',
        ' source = ', $source, 
        ' transform = ', $transform, 
        ' cached copy = ', $result-cache-name))
        ,
        $result
        )
    else
      (util:log('debug',
        ('jvalidate:transform-cache: using cached copy for: ',
        ' source = ', $chain-source, 
        ' transform = ', $transform, 
        ' cached copy = ', $result-cache-name))
        ,
      doc($result-cache-uri)
      )
};

declare function jvalidate:validate-relaxng(
  $content as item(), $grammar as item()) 
  as element(report) {
  validation:jing-report($content, $grammar)
};

(:~ Validate $content using the ISO Schematron schema $grammar
 : Assumes all failed assertions and activated reports are invalid.
 : @return The result of the validation as:
 : <report>
 :  <status>valid|invalid</status>
 :  <message><!-- a SVRL document --></message>
 : </report>
 :)
declare function jvalidate:validate-iso-schematron-svrl(
  $content as item(), $grammar as item()) 
  as element(report) {
  let $grammar-doc := 
    typeswitch($grammar)
      case $g as xs:anyURI
        return 
            if (doc-available($g))
            then doc($g)
            else error('jvalidate:validate-iso-schematron-svrl' 
                cast as xs:QName,
                'Document cannot be read', $g)
      case $g as node()
        return $g
      default
        return
          error('jvalidate:validate-iso-schematron-svrl' cast as xs:anyURI,
            'second parameter to must be xs:anyURI or node()')
  let $chain-source :=
    document-uri(root($grammar-doc))
  let $include-transform := 
    jvalidate:transform-cache($chain-source, $grammar-doc, 
      $jvalidate:path-to-schematron-include, (), ())
  let $abstract-transform :=
    jvalidate:transform-cache($chain-source, $include-transform, 
      $jvalidate:path-to-schematron-abstract, (), ()) 
  let $grammar-transform :=
    jvalidate:transform-cache($chain-source, $abstract-transform, 
      $jvalidate:path-to-schematron-xsl, (), ())
  let $result-transform :=
    transform:transform($content, $grammar-transform, ())
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
