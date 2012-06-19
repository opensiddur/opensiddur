xquery version "3.0";
(:~ Convert STML to JLPTEI 
 : 
 : A multipass converter:
 : Pass 1: parse text->grammar parsed XML
 : Pass 2: create finalized headers and file outlines, convert grammar parser XML to (invalid) TEI
 :
 : @author Efraim Feinstein
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace stml="http://jewishliturgy.org/transform/stml";

import module namespace grammar="http://jewishliturgy.org/transform/grammar"
  at "/code/grammar-parser/grammar2.xqm";
import module namespace name="http://jewishliturgy.org/modules/name"
  at "/code/modules/name.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "/code/api/modules/data.xqm";

import module namespace stxt="http://jewishliturgy.org/transform/streamtext"
  at "streamtext.xqm";

declare namespace p="http://jewishliturgy.org/ns/parser";
declare namespace r="http://jewishliturgy.org/ns/parser-result";
declare namespace error="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

declare variable $stml:grammar := "/code/grammar-parser/stml-grammar.xml";

(:~ parse STML, or flag an error
 :
 : @param $text the STML, as text
 : @return The STML file, parsed to XML
 : @error error:PARSE Cannot parse the file, returns the position where the parsing failed.
 :) 
declare function stml:parse(
  $text as xs:string
  ) as element(r:STML) {
  let $parsed :=
    grammar:clean(grammar:parse($text, "STML", doc($stml:grammar)))
  return
    if ($parsed/self::r:no-match)
    then error(xs:QName("error:PARSE"), "Cannot parse the STML", $parsed/self::r:no-match/r:remainder)
    else $parsed 
};

declare function stml:convert-text(
  $text as xs:string
  ) (:as element(stml:file)+ :){
  stml:convert(stml:parse($text))
};

declare function stml:convert(
  $node as node()*
  ) as item()* {
  for $n in $node
  return (
    util:log-system-out($n),
    typeswitch($n)
    case document-node() return stml:convert($n/*)
    case element(r:STML) return stml:STML($n)
    case element(r:STMLCommand) return ()
    case element(r:BiblCommand) return stml:BiblCommand($n) 
    case element(r:TitleCommand) return stml:TitleCommand($n)
    case element(r:PubInfoCommand) return stml:PubInfoCommand($n)
    case element(r:Info) return stml:pass-through($n)
    case element(r:URL) return stml:pass-through($n)
    case element(r:Date) return stml:pass-through($n)
    case element(r:Title) return stml:pass-through($n)
    case element(r:Argument) return stml:pass-through($n)
    case element(r:ShortName) return stml:pass-through($n)
    case element(r:AuthorEditorCommand) return stml:AuthorEditorCommand($n)
    case element(r:PubDateCommand) return stml:PubDateCommand($n)
    case element(r:PageRefCommand) return stml:PageRefCommand($n)
    case element(r:AuthEdit) return stml:AuthEdit($n)
    case element(r:ContributorCommand) return stml:ContributorCommand($n)
    case element(r:Handle) return stml:Handle($n)
    case element(r:ContributorIDCommand) return stml:ContributorIDCommand($n)
    case element(r:FileContent) return stml:FileContent($n)
    case element(r:RemarkCommand) return ()
    case text() return $n
    default return (
      util:log-system-out(("Not implemented:" ,name($n))),
      stml:convert($n/node())
      )
    )
};

declare function stml:STML(
  $e as element(r:STML)
  ) {
  stml:convert($e/node())
};

declare function stml:Language(
  $node as node()
  ) as xs:string {
  string(root($node)/r:STML/r:STMLCommand/r:Language)
};

(:~ Bibliography resource 
 :)
declare function stml:BiblCommand(
  $e as element(r:BiblCommand)
  ) {
  <stml:file post-to="/data/sources">
    <tei:biblStruct xml:lang="{stml:Language($e)}">
      <tei:monogr>
        { $e/stml:convert((
            r:TitleCommand, 
            r:PubInfoCommand[r:Type="edition"], 
            r:AuthorEditorCommand
            ))
        }
        <tei:imprint>{
            $e/stml:convert((
              r:PubInfoCommand[not(r:Type = "edition")],
              r:PubDateCommand
            )),
            <tei:distributor xml:lang="en">The Open Siddur Project</tei:distributor>
        }</tei:imprint>
      </tei:monogr>
      {
        $e/stml:convert(r:PageRefCommand)
      }
    </tei:biblStruct>
  </stml:file>
};

declare function stml:TitleCommand(
  $e as element(r:TitleCommand)
  ) {
  <tei:title>{stml:convert($e/r:Title)}</tei:title>
};

declare function stml:PubInfoCommand(
  $e as element(r:PubInfoCommand)
  ) {
  element {
    switch($e/r:Type)
    case "edition" return "tei:edition"
    case "publisher" return "tei:publisher"
    case "place" return "tei:pubPlace"
    default return error(xs:QName("error:BADNESS"), ("Bad PubInfoCommand type: ", data($e/r:Type)))
  }{
    stml:convert($e/r:Info)
  }
};

declare function stml:AuthorEditorCommand(
  $e as element(r:AuthorEditorCommand)
  ) {
  element {
    switch($e/r:Type)
    case "author" return "tei:author"
    case "editor" return "tei:editor"
    default return error(xs:QName("error:BADNESS"), ("Bad AuthorEditor type: ", data($e/r:Type)))
  }{
    if ($e/r:Type = "edition")
    then stml:convert($e/node())
    else name:string-to-name(stml:convert($e/r:AuthEdit))
  }
};

declare function stml:PubDateCommand(
  $e as element(r:PubDateCommand)
  ) {
  <tei:date>{stml:convert($e/r:Date/node())}</tei:date>
};

declare function stml:PageRefCommand(
  $e as element(r:PageRefCommand) 
  ) {
  if ($e/r:Type = "page-images")
  then ()
  else 
    (: page-ref, where page-images may be a sibling :)
    let $page-images := $e/../r:PageRefCommand[r:Type="page-images"]
    return
      <tei:relatedItem type="scan">{
        attribute target { stml:convert($e/r:URL) },
        if (exists($page-images))
        then
          attribute targetPattern { stml:convert($page-images/r:URL) }
        else ()
      }</tei:relatedItem>
};

declare function stml:AuthEdit(
  $e as element(r:AuthEdit)
  ) {
  stml:convert($e/node())
};

(: Contributor information :)
declare function stml:ContributorCommand(
  $e as element(r:ContributorCommand)
  ) {
  <stml:file post-to="/user">
    <j:contributor>{
      $e/stml:convert((
        r:Handle,
        (: reorder the contributor identifiers :)
        for $type in ("name", "organization", "email", "website")
        return $e/r:ContributorIDCommand[r:Type=$type]
      ))
    }</j:contributor>
  </stml:file>
};

declare function stml:Handle(
  $e as element(r:Handle)
  ) {
  <tei:idno>{stml:convert($e/node())}</tei:idno>
};

declare function stml:ContributorIDCommand(
  $e as element(r:ContributorIDCommand)
  ) {
  switch($e/r:Type)
  case "name"
  return 
    <tei:name>{name:string-to-name(stml:convert($e/r:Argument))}</tei:name>
  case "organization"
  return
    let $org :=
      <tei:orgName>{stml:convert($e/r:Argument)}</tei:orgName>
    return
      if ($e/../r:ContributorCommand[r:Type="name"])
      then
        <tei:affiliation>{
          $org
        }</tei:affiliation>
      else $org 
  case "email"
  return
    <tei:email>{stml:convert($e/r:Argument)}</tei:email>
  case "website"
  return
    <tei:ptr type="url" target="{stml:convert($e/r:Argument)}"/>
  default return ()
};

declare function stml:file-location(
  $n as node()
  ) {
  let $st := root($n)/r:STML/r:STMLCommand
  let $doctype := string($st/r:DocType)
  return 
    if ($doctype = "original")
    then "/data/original"
    else 
      concat(
        "/data/translation/", 
        $st/r:Language/string(), "/", 
        $st/r:Argument/string()
      )
};

declare function stml:annotation-location(
  $n as node()
  ) {
  "/data/notes"
};

declare function stml:license(
  $n as node()
  ) {
  let $st := root($n)/r:STML/r:STMLCommand
  let $license := $st/r:License/string()
  let $license-uri := 
    switch ($license)
    case "cc-zero" return "http://www.creativecommons.org/publicdomain/zero/1.0"
    case "cc-by" return "http://www.creativecommons.org/licenses/by/3.0"
    case "cc-by-sa" return "http://www.creativecommons.org/licenses/by-sa/3.0"
    default return ()
  return 
    <tei:availability 
      status="{
        if ($license = "cc-zero") 
        then "free"
        else "restricted"
      }">
      <tei:licence target="{$license-uri}"/>
    </tei:availability>
};

declare function stml:source(
  $n as node()
  ) {
  let $type := "original" (: does not matter :)
  let $bibl := root($n)/r:STML/r:BiblCommand
  let $path := data:new-path-to-resource($type, stml:convert($bibl/r:TitleCommand))
  let $resource := substring-before($path[2], ".xml") 
  return 
    <tei:link type="bibl" target="#text /data/sources/{$resource}"/>
};

(: write a header :)
declare function stml:header(
  $e as element(r:FileCommand),
  $title as element(tei:title)
  ) {
  <tei:teiHeader>
    <tei:fileDesc>
      <tei:titleStmt>
        {
          $title,
          stml:responsibility($e)
        }
      </tei:titleStmt>
      <tei:publicationStmt>{
        stml:license($e)
        }
        <tei:distributor><tei:ref target="http://opensiddur.org">Open Siddur Project</tei:ref></tei:distributor>
        <tei:date>{year-from-date(current-date())}</tei:date>
      </tei:publicationStmt>
      <tei:sourceDesc>{
        stml:source($e)
      }</tei:sourceDesc>
    </tei:fileDesc>
    <tei:revisionDesc>
      <tei:change type="created" when="{current-date()}">Document converted from STML</tei:change>
    </tei:revisionDesc>
  </tei:teiHeader>
  
};

(: TODO: change this to catch r:FileContent :)
(:~ file conversion :)
declare function stml:FileContent(
  $e as element(r:FileContent)
  ) {
  let $file-command := $e/r:FileCommand
  let $file-location := stml:file-location($file-command)
  let $ShortName := stml:convert($file-command/r:ShortName)
  let $file-title := stml:convert($file-command/r:Title)
  return (
    if ($e/parent::r:STML)
    then () 
    else 
      (: this is a file-in-a-file, resulting in an inclusion :)
      <tei:ptr j:type="external" target="{$file-location}{
        substring-before(data:new-path-to-resource("original", $file-title)[2], ".xml")
      }"/>,
    <stml:file post-to="{$file-location}">
      <tei:TEI xml:lang="{stml:Language($e)}">{
        stml:header(
          $e, 
          <tei:title type="main">{
            $file-title
          }</tei:title>
        ),
        let $temp-text-stream :=
          stxt:convert($e/node())
        return (
          ((: construct page image links :)),
          <tei:text>
            <j:streamText xml:id="text">
              {($temp-text-stream (:construct text stream:))}
            </j:streamText>
            <j:concurrent xml:id="concurrent">{
            ((:construct hierarchy layers:
            division,
            paragraph,
            sentence,
            line group-line,
            biblical verse,
            named division (ab)
            :))
            }</j:concurrent>
          </tei:text>
        )
      }</tei:TEI>
    </stml:file>,
    stml:annotations($e)
  ) 
};

(:~ write a responsibility structure :)
declare function stml:responsibility(
  $e as element(r:FileCommand)
  ) as element(j:responsGrp)? {
  let $ShortName := data($e/r:ShortName)
  let $contributors := root($e)//r:ContributorCommand[data(r:AppliesToCommand/r:ShortName)=$ShortName]
  where exists($contributors)
  return
    <j:responsGrp>{
      for $contributor in $contributors
      return 
        <tei:respons 
          type="trc" 
          locus="value" 
          resp="/user/{stml:convert($contributor/r:Handle)/string()}" 
          target="#text"
          />
    }</j:responsGrp>
};

declare function stml:annotations(
  $e as element(r:FileCommand)
  ) {
  <stml:file post-to="{stml:annotation-location($e)}">
    <tei:TEI xml:lang="{stml:Language($e)}">{
      stml:header($e,
        <tei:title type="main">{
          concat("Notes for ", stml:convert($e/r:Title))
        }</tei:title>
      )
    }</tei:TEI>
    <j:annotations>
    </j:annotations>
  </stml:file>
};

(:~ generic pass-through :)
declare function stml:pass-through(
  $e as element()
  ) {
  stml:convert($e/node())
};

