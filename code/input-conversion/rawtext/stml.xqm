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
    case element(r:FileCommand) return stml:FileCommand($n)
    case element(r:EndFileCommand) return ()
    case element(r:IncludeCommand) return stml:IncludeCommand($n)
    case element(r:IncludeBlockCommand) return stml:IncludeCommand($n)
    case element(r:RemarkCommand) return ()
    case element(r:DivineNameCommand) return stml:DivineNameCommand($n)
    case element(r:DivineName) return stml:pass-through($n)
    case element(r:TranslitCommand) return stml:TranslitCommand($n)
    case element(r:AsWritten) return stml:pass-through($n)
    case element(r:OriginalLanguage) return stml:pass-through($n)
    case element(r:SicCommand) return stml:SicCommand($n)
    case element(r:IncorrectText) return stml:IncorrectText($n)
    case element(r:CorrectedText) return stml:CorrectedText($n)
    case element(r:PageBreakCommand) return stml:PageBreakCommand($n)
    case element(r:FootnotePageBreakCommand) return stml:FootnotePageBreakCommand($n)
    case element(r:BookPage) return stml:pass-through($n)
    case element(r:ScanPage) return stml:pass-through($n)
    case element(r:NamedCommand) return stml:NamedCommand($n)
    case element(r:EndNamedCommand) return stml:EndNamedCommand($n)
    case element(r:NoteCommand) return stml:note-like-commands($n)
    case element(r:FootNoteCommand) return stml:note-like-commands($n)
    case element(r:InstructCommand) return stml:note-like-commands($n)
    case element(r:EndNoteCommand) return stml:EndNoteCommand($n)
    case element(r:EndInstructCommand) return stml:EndInstructCommand($n)
    case element(r:NoteContent) return stml:pass-through($n)
    case element(r:Escape) return stml:Escape($n)
    case element(r:BeginFormattingCommand) return stml:formatting-commands($n)
    case element(r:EndFormattingCommand) return stml:formatting-commands($n)
    case element(r:EmphasisCommand) return stml:EmphasisCommand($n)
    case element(r:ParagraphBreak) return stml:end-p($n)
    case element(r:LineBreak) return stml:end-l($n)
    case element(r:HorizontalRuleCommand) return stml:end-p($n)
    case element(r:SectionCommand) return stml:SectionCommand($n)
    case element(r:SectionName) return stml:SectionName($n)
    case element(r:VerseDivision) return stml:VerseDivision($n)
    case element(r:PoetryMode) return stml:PoetryMode($n)
    case element(r:EndPoetryMode) return stml:EndPoetryMode($n)
    case element(r:Pausal) return stml:Pausal($n)
    case element(r:SegmentContent) return stml:SegmentContent($n)
    case element(r:ReferenceCommand) return stml:ReferenceCommand($n)
    case element(r:Text) return stml:pass-through($n)
    case element(r:HebrewCommand) return stml:HebrewCommand($n)
    case element(r:FootRefCommand) return stml:FootRefCommand($n)
    case element(r:PageReferenceCommand) return stml:PageReferenceCommand($n)
    case element(r:ContCommand) return ()
    case text() return 
      let $s := normalize-space($n)
      where $s
      return text { concat(" ", $s, " ") } 
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

declare function stml:file-path(
  $e as element(r:FileCommand)
  ) {
  let $resource :=
    substring-before(
      data:new-path-to-resource(
        "original", 
        stml:convert($e/r:Title)
      )[2],
      ".xml"
    )
  let $location := stml:file-location($e)
  return concat($location, "/", $resource)
      
};

(:~ file conversion :)
declare function stml:FileContent(
  $e as element(r:FileContent)
  ) {
  let $file-command := $e/r:FileCommand
  let $file-path := stml:file-path($file-command)
  let $file-location := stml:file-location($file-command)
  let $ShortName := stml:convert($file-command/r:ShortName)
  let $file-title := stml:convert($file-command/r:Title)
  let $converted :=
    <stml:file post-to="{$file-location}">
      <tei:TEI xml:lang="{stml:Language($e)}">{
        stml:header(
          $e/r:FileCommand, 
          <tei:title type="main">{
            $file-title
          }</tei:title>
        ),
        <tei:text>
          <stml:temporary-stream>{
            stml:convert($e/node())
          }</stml:temporary-stream>
        </tei:text>
      }</tei:TEI>
    </stml:file>
  return (
    if ($e/parent::r:STML)
    then 
      stxt:assign-xmlids(
        stxt:convert($converted), 1, 1
      )
    else 
      (: this is a file-in-a-file, resulting in an inclusion :)
      <tei:ptr j:type="external" target="{$file-path}"/>,
    $converted
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
  $e as element(r:FileContent)
  ) {
  let $file-command := $e/r:FileCommand
  return
    <stml:file post-to="{stml:annotation-location($file-command)}">
      <tei:TEI xml:lang="{stml:Language($e)}">{
        stml:header($file-command,
          <tei:title type="main">{
            concat("Notes for ", stml:convert($file-command/r:Title))
          }</tei:title>
        )
      }</tei:TEI>
      <j:annotations>
      </j:annotations>
    </stml:file>
};

declare function stml:DivineNameCommand(
  $e as element(r:DivineNameCommand)
  ) {
  <j:divineName>{stml:convert($e/r:DivineName)}</j:divineName>
};

declare function stml:TranslitCommand(
  $e as element(r:TranslitCommand)
  ) {
  let $lang := $e/r:LangCode/string()
  return
    if (exists($e/r:OriginalLanguage))
    then
      let $original := substring-before($lang, "-")
      return
        <tei:choice>
          <tei:orig>{stml:convert($e/r:AsWritten)}</tei:orig>
          <tei:reg>
            <j:segGen xml:lang="{$original}">{
              stml:convert($e/r:OriginalLanguage)
            }</j:segGen>
          </tei:reg>
        </tei:choice>
    else
      <tei:seg xml:lang="{$lang}">{
        stml:convert($e/r:AsWritten)
      }</tei:seg>
};

declare function stml:SicCommand(
  $e as element(r:SicCommand)
  ) {
  <tei:choice>{
    stml:convert($e/r:IncorrectText),
    stml:convert($e/r:CorrectedText)
  }</tei:choice>
};

declare function stml:IncorrectText(
  $e as element(r:IncorrectText)
  ) {
  <tei:sic>{stml:convert($e/node())}</tei:sic>
};

declare function stml:CorrectedText(
  $e as element(r:CorrectedText)
  ) {
  <tei:corr>{stml:convert($e/node())}</tei:corr>
};

declare function stml:page-image-url(
  $e as element(r:PageBreakCommand)
  ) {
  let $page-images := root($e)/r:STML/r:BiblCommand/
    r:PageRefCommand[r:Type="page-images"]
  return
    replace($page-images/r:URL, "\{\$page\}", $e/r:ScanPage/string()) 
};

(:~ page breaks do not appear in the stream text,
 : but are useful as milestone elements for intermediate 
 : processing
 :)
declare function stml:PageBreakCommand(
  $e as element(r:PageBreakCommand)
  ) {
  let $continued := stml:is-pagebreak-continued($e)
  return (
    <tei:pb j:continued="{$continued}" ed="original" n="{stml:convert($e/r:BookPage)}"/>,
    if (exists($e/r:ScanPage))
    then
      <tei:pb
        j:continued="{$continued}"
        ed="scan"
        n="{stml:convert($e/r:ScanPage)}"
        facs="{stml:page-image-url($e)}"
        />
    else ()
  )
};

declare function stml:FootnotePageBreakCommand(
  $e as element(r:FootnotePageBreakCommand)
  ) {
  stml:PageBreakCommand(root($e)//r:PageBreakCommand[r:BookPage=$e/r:BookPage])
};

declare function stml:NamedCommand(
  $e as element(r:NamedCommand)
  ) {
  <tei:anchor n="NamedCommand" xml:id="{concat("start-",$e/r:ShortName)}"/>
};

declare function stml:EndNamedCommand(
  $e as element(r:EndNamedCommand)
  ) {
  <tei:anchor n="EndNamedCommand" xml:id="{concat("end-",$e/r:ShortName)}"/>
};

declare function stml:EndNoteCommand(
  $e as element(r:EndNoteCommand)
  ) {
  <tei:anchor n="EndNoteCommand" xml:id="{concat("end-",$e/r:ShortName)}"/>
};

declare function stml:EndInstructCommand(
  $e as element(r:EndInstructCommand)
  ) {
  <tei:anchor n="EndInstructCommand" xml:id="{concat("end-",$e/r:ShortName)}"/>
};

(:~ find out what scan pages a (set of) node(s) is(are) on :)
declare function stml:page(
  $nodes as node()*
  ) {
  distinct-values(
    for $n in $nodes
    let $page-break := 
      if ($n/ancestor::r:FootNoteCommand)
      then 
        let $fp := $n/(preceding-sibling::r:FootNotePageBreakCommand|preceding::r:PageBreakCommand)[last()]
        return 
          if ($fp instance of element(r:FootNotePageBreakCommand))
          then root($n)//r:PageBreakCommand[r:BookPage=$fp/r:BookPage]
          else $fp
      else $n/preceding::r:PageBreakCommand[1]
    return $page-break/(r:ScanPage, r:BookPage)[1]/string()
  )
};

declare function stml:note-id(
  $e as element()
  ) {
  if ($e instance of element(r:FootNoteCommand))
  then concat("fn_", stml:page($e), "_", $e/r:Number/string())
  else $e/r:ShortName
};

declare function stml:note-like-commands(
  $e as element()
  ) {
  element {
    if ($e instance of element(r:InstructCommand))
    then "j:instruct"
    else "tei:note"
  }{
    attribute xml:id { stml:note-id($e) },
    stml:convert($e/r:NoteContent)
  },
  if ($e instance of element(r:FootNoteCommand))
  then ()
  else 
    <tei:anchor n="{local-name($e)}" xml:id="{concat("start-", $e/r:ShortName)}"/>
};

declare function stml:formatting-commands(
  $e as element()
  ) {
  ( (: ignore all formatting :) )
};

declare function stml:end-l(
  $e as element()
  ) {
  <tei:lb/>
};

declare function stml:end-p(
  $e as element()
  ) {
  stml:end-l($e),
  <tei:p/>
};

declare function stml:FileCommand(
  $e as element(r:FileCommand)
  ) {
  <tei:div j:type="file">
    <tei:head>{stml:convert($e/r:Title)}</tei:head>
  </tei:div>
};

(: the section command leaves a div (which should 
 : ends at the end of the file!) and a head in-place
 :)
declare function stml:SectionCommand(
  $e as element(r:SectionCommand)
  ) {
  <tei:div j:type="section">
    {stml:convert($e/*)}
  </tei:div>
};

declare function stml:SectionName(
  $e as element(r:SectionName)
  ) {
  <tei:head>{stml:convert($e/node())}</tei:head>
};

declare function stml:VerseDivision(
  $e as element(r:VerseDivision)
  ) {
  <tei:ab type="verse">
    <tei:label n="chapter">{$e/r:Chapter/string()}</tei:label>
    <tei:label n="verse">{$e/r:Verse/string()}</tei:label>
  </tei:ab>
};

declare function stml:Escape(
  $e as element(r:Escape)
  ) {
  substring-after($e, "\")
};

declare function stml:Pausal(
  $e as element(r:Pausal)
  ) {
  for $t in $e/r:Type
  return
    <tei:pc j:type="pausal">{stml:convert($t/node())}</tei:pc>
};

(:~ poetry mode: just leave a milestone indicating poetry mode beginning :)
declare function stml:PoetryMode(
  $e as element(r:PoetryMode)
  ) {
  <tei:milestone type="Begin-Poetry-Mode"/>
};

(:~ poetry mode: just leave a milestone indicating poetry mode beginning :)
declare function stml:EndPoetryMode(
  $e as element(r:EndPoetryMode)
  ) {
  <tei:milestone type="End-Poetry-Mode"/>
};

(: include and include block commands :)
declare function stml:IncludeCommand(
  $e as element()
  ) {
  let $is-block := $e instance of element(r:IncludeBlockCommand)
  let $inclusion := $e/r:ShortName/string()
  let $inclusion-element := root($e)//*[r:ShortName=$inclusion]
  let $my-file := $e/parent::r:FileContent
  let $inclusion-file := $inclusion-element/parent::r:FileContent
  let $base := 
    if ($my-file is $inclusion-file)
    then ""
    else stml:file-path($inclusion-file/r:FileCommand)
  return
    <tei:ptr j:type="{
      string-join((
        if ($base) 
        then "external"
        else "internal",
        "block"[$is-block]
        ), " "
      )
    }" target="{$base}#{$inclusion}"/>
};

declare function stml:SegmentContent(
  $e as element(r:SegmentContent)
  ) {
  let $text := stml:convert($e/node())
  where exists($text) (: nonzero length :)
  return
    <tei:seg>{
      $text
    }</tei:seg>
};

declare function stml:HebrewCommand(
  $e as element(r:HebrewCommand)
  ) {
  for $xml in stml:convert($e/*) 
  return
    typeswitch ($xml)
    case element() return
      element { QName(namespace-uri($xml), name($xml)) }{
        attribute xml:lang {"he"},
        $xml/node()
      }
    default return $xml
};

declare function stml:EmphasisCommand(
  $e as element(r:EmphasisCommand)
  ) {
  <tei:hi>{stml:convert($e/*)}</tei:hi>
};

declare function stml:ReferenceCommand(
  $e as element(r:ReferenceCommand)
  ) {
  <tei:ref target="{$e/r:Reference/string()}">{
    stml:convert($e/r:SegmentContent)
  }</tei:ref>
};

(:~ for a footnote reference, leave behind an indicator that
 : more processing will need to be done 
 :)
declare function stml:FootRefCommand(
  $e as element(r:FootRefCommand)
  ) {
  let $refers-to := $e/following::r:FootNoteCommand[r:Number=$e/r:Reference]
  return
    <tei:ptr j:type="FootnoteReference" target="#{stml:note-id($refers-to)}"/>
};

declare function stml:PageReferenceCommand(
  $e as element(r:PageReferenceCommand)
  ) {
  let $refers-to := root($e)//*[r:ShortName=$e/r:ShortName]
  let $my-file := $e/ancestor::r:FileContent[1]
  let $reference-file := $refers-to/ancestor::r:FileContent[1]
  let $base := 
    if ($my-file is $reference-file)
    then ""
    else stml:file-path($reference-file/r:FileCommand)
  return
    <tei:ref target="{$base}#{$e/r:ShortName}">{
      string-join((
        "page"[$e/r:ReferenceType = "prr"],
        $e/r:PageNumber
      ), " ")
    }</tei:ref>
};

declare function stml:is-pagebreak-continued(
  $e as element()
  ) {
  let $next-pb :=
    $e/(
      following-sibling::r:PageBreakCommand|
      following-sibling::r:FootnotePageBreakCommand
      )
  return    
    exists(
      $e/following-sibling::r:ContCommand
        [empty($next-pb) or (.<<$next-pb)]
      )  
};

(:~ generic pass-through :)
declare function stml:pass-through(
  $e as element()
  ) {
  stml:convert($e/node())
};

