xquery version "1.0";
(: Run the XSpec test suite.  All tests can be run except the
 : coverage test, because it requires a special Java class.
 : Assumes the xspec XSLTs are in $xspec:collection
 : 
 : Copyright 2010 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: xspec.xqm 738 2011-04-15 02:21:55Z efraim.feinstein $
 :)

module namespace xspec="http://jewishliturgy.org/modules/xspec";

import module namespace app="http://jewishliturgy.org/modules/app"
  at "app.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "paths.xqm";

declare namespace t="http://www.jenitennison.com/xslt/xspec";
declare namespace xsl="http://www.w3.org/1999/XSL/Transform";
declare namespace err="http://jewishliturgy.org/errors";
(:declare namespace xxml="http://jewishliturgy.org/ns/xml-alias";:)

declare variable $xspec:collection as xs:string := 
  '/code/modules/resources/xspec';
(:
declare variable $xspec:xxml-namespace-uri := 
  'http://jewishliturgy.org/ns/xml-alias';
:)

(:~ Load a document or flag an err:NOTFOUND error if the document cannot be loaded. :)
declare function xspec:_doc-or-error(
  $doc as xs:anyURI
  ) as document-node() {
  if (doc-available($doc))
  then doc($doc)
  else error(xs:QName('err:NOTFOUND'), concat('Document ', $doc, ' not found.')) 
};

(:~ load an xml root element, given an item() pointing to it, which may be a URI, document node, string, or element
 : @param $item The item to load
 :)
declare function xspec:_load-xml-from-item(
  $item as item()
  ) as element() {
  typeswitch ($item)
    case $t as xs:string 
      return xspec:_doc-or-error($t cast as xs:anyURI)/*
    case $t as xs:anyURI
      return xspec:_doc-or-error($t)/*
    case $t as element() 
      return $t
    case $t as document-node()
      return $t/*
    default
      return error(xs:QName('err:INVALID'), concat('Cannot load ', $item, ': it is of unknown type.'))
  
};

(:~ Absolutize a URI in an attribute, assuming it's pointing to a location in the database :)
declare function xspec:_relative-to-absolute(
  $attribute as attribute()*
  ) as attribute()* {
  for $attr in $attribute
  let $element := $attr/..
  return
    attribute {node-name($attr)}{
      let $str-val := string($attr)
      let $resolved := resolve-uri($str-val, document-uri(root($attr)))
      let $value :=
      	if (matches($resolved,'^(http|xmldb:exist)://'))
        then $resolved
        else string-join((
        	if (namespace-uri($element) = 'http://www.jenitennison.com/xslt/xspec' and 
        		local-name($element) = ('description','import'))
        	then 'http://localhost:8080'
        	else 'xmldb:exist://', 
        	if (starts-with($resolved, '/')) then '' else '/', 
        	$resolved), '')
      return (
      	$value,
        util:log-system-out(('resolving ', $resolved, ' into ', $value))
      )
    }
};

(:~ find attributes from xxml namespace, translate to xml namespace :)
(:
declare function xspec:_xxml-to-xml(
  $attribute as attribute()*
  ) as attribute()* {
  for $attr in $attribute
  return
    if (namespace-uri($attr) = $xspec:xxml-namespace-uri)
    then
      attribute {concat('xml:', local-name($attr))} {string($attr)}
    else
      $attr
};
:)

(:~ Find all instances of @stylesheet and @href elements and make them absolute URIs pointing into the db
 : Find all instances of @xxml:* and turn them into @xml:*
 : @param $xspec An element from an XSpec file
 :)
declare function xspec:_transform-attributes(
  $xspec as element()
  ) as element() {
  element {node-name($xspec)}
    {
      $xspec/(@* except (@stylesheet,@href (:, @xxml:* :))),
      xspec:_relative-to-absolute(($xspec/@stylesheet, $xspec/@href)),
      for $child in $xspec/node()
        return 
          if ($child instance of element())
          then xspec:_transform-attributes($child)
          else $child
    }
}; 

(:~ Convert XSpec XML to a stylesheet.
 : @param $xspec-xml The XSpec file: either a pointer or a node()
 : @return The compiled stylesheet
 :)
declare function xspec:create-test-stylesheet(
  $xspec-xml as item()
  ) as element() {
  let $xspec-doc := 
    xspec:_load-xml-from-item($xspec-xml)
  let $absolutize-transformed :=
    (: Convert @stylesheet and @href to absolute URIs :)
    xspec:_transform-attributes($xspec-doc)
  let $xspec-transform := (: http://localhost:8080 changed to xmldb: :)
    <xsl:stylesheet version="2.0" 
      xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
      xmlns:t="http://www.jenitennison.com/xslt/xspec"
      xml:base="http://localhost:8080/db/code/modules/resources/xspec/"> 
      <xsl:include href="{app:concat-path($xspec:collection, '/generate-xspec-tests.xsl')}" />
    </xsl:stylesheet>
  return (
    transform:transform($absolutize-transformed, $xspec-transform, ())

  )
};

(:~ Run XSpec tests on a compiled stylesheet 
 : @param $compiled-test The stylesheet as compiled by create-test-stylesheet()
 :)
declare function xspec:run-tests(
  $compiled-test as item()
  ) as document-node() {
  let $test-doc as element(xsl:stylesheet) :=
    xspec:_load-xml-from-item($compiled-test)
  let $xslt :=
    (: add a matched template that duplicates x:main without xsl:result-document :)
    transform:transform(
    $compiled-test,
    <xsl:stylesheet version="2.0" 
      xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
      xmlns:xx="http://www.w3.org/1999/XSL/Transform/NotReally"
      xmlns:x="http://www.jenitennison.com/xslt/xspec"
      >
      <xsl:namespace-alias stylesheet-prefix="xx" result-prefix="xsl"/>
      <xsl:template match="/*">
        <xsl:copy>
          {attribute {'copy-namespaces'}{'yes'}}
          <xsl:copy-of select="@*"/>
          <xsl:sequence select="child::node()"/>
          <xx:template match="a">
            <xsl:variable name="main-template" select="xsl:template[@name='x:main']" />
            <xsl:sequence select="$main-template/* except $main-template/xsl:result-document"/>
            <xsl:sequence select="$main-template/xsl:result-document/*"/>
          </xx:template>
        </xsl:copy>
      </xsl:template>
    </xsl:stylesheet>, 
    ())
  return
    document {
      transform:transform(<a/>, $xslt, ())
    }
};

(:~ format an XSpec report 
 : @param $report The report from run-tests()
 :)
declare function xspec:format-report(
  $report as item()) 
  as element() {
  let $report-doc as element() :=
    xspec:_load-xml-from-item($report)
  return
    transform:transform($report-doc, 
      doc(concat($xspec:collection, '/format-xspec-report.xsl')),
      ())
};


(:~ front end to all XSpec tests.  Run the tests and generate an HTML
 : report.
 : @param $tests The test scenario file
 :)
declare function xspec:test(
  $tests as item()
  ) as document-node() {
  let $formatted-report :=
    xspec:format-report(
      xspec:run-tests(
        xspec:create-test-stylesheet($tests)
      )
    )
  return
    document {
      transform:transform($formatted-report,
        <xsl:stylesheet version="2.0" 
          xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
          xmlns:html="http://www.w3.org/1999/xhtml"
          >
          <xsl:template match="element()">
            <xsl:copy>
              <xsl:copy-of select="@*"/>
              <xsl:apply-templates />
            </xsl:copy>
          </xsl:template>
        
          <!-- replace the link to the stylesheet with a hardcoded link -->
          <xsl:template match="html:link">
            <xsl:copy>
              <xsl:copy-of select="(@type,@rel)"/>
              <xsl:attribute name="href" select="'{$paths:rest-prefix}{$xspec:collection}/test-report.css'"/>
            </xsl:copy>
          </xsl:template>
        </xsl:stylesheet>
        ,
        ())
    }
};
