xquery version "3.0";
(:~ Convert STML to JLPTEI: streamText mode
 :
 : @author Efraim Feinstein
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace stxt="http://jewishliturgy.org/transform/streamtext";

declare namespace p="http://jewishliturgy.org/ns/parser";
declare namespace r="http://jewishliturgy.org/ns/parser-result";
declare namespace error="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

(:~ entry point to constructing a text stream :)
declare function stxt:convert(
  $nodes as node()*
  ) as item()* {
  for $n in $nodes
  return
    typeswitch($n)
    case element(r:RemarkCommand) return ()
    case element(r:DivineNameCommand) return stxt:DivineNameCommand($n)
    case element(r:TranslitCommand) return stxt:TranslitCommand($n)
    case element(r:AsWritten) return stxt:pass-through($n)
    case element(r:OriginalLanguage) return stxt:pass-through($n)
    case element(r:SicCommand) return stxt:SicCommand($n)
    case element(r:IncorrectText) return stxt:IncorrectText($n)
    case element(r:CorrectedText) return stxt:CorrectedText($n)
    case element(r:PageBreakCommand) return stxt:PageBreakCommand($n)
    case element(r:FootnotePageBreakCommand) return stxt:FootnotePageBreakCommand($n)
    case element(r:BookPage) return stxt:pass-through($n)
    case element(r:ScanPage) return stxt:pass-through($n)
    case element(r:NamedCommand) return stxt:NamedCommand($n)
    case element(r:EndNamedCommand) return stxt:EndNamedCommand($n)
    case element(r:NoteCommand) return stxt:note-like-commands($n)
    case element(r:FootNoteCommand) return stxt:note-like-commands($n)
    case element(r:InstructCommand) return stxt:note-like-commands($n)
    case element(r:EndNoteCommand) return stxt:EndNoteCommand($n)
    case element(r:EndInstructCommand) return stxt:EndInstructCommand($n)
    case element(r:Escape) return stxt:Escape($n)
    case element(r:BeginFormattingCommand) return stxt:formatting-commands($n)
    case element(r:EndFormattingCommand) return stxt:formatting-commands($n)
    case element(r:ParagraphBreak) return stxt:end-p($n)
    case element(r:LineBreak) return stxt:end-l($n)
    case element(r:HorizontalRuleCommand) return stxt:end-p($n)
    case element(r:SectionCommand) return stxt:SectionCommand($n)
    case element(r:SectionName) return stxt:SectionName($n)
    case element(r:VerseDivision) return stxt:VerseDivision($n)
    case text() return $n
    default return (
      util:log-system-out(("Not implemented in streamtext: ", name($n))),
      stxt:convert($n/node())
    )
      
};

declare function stxt:DivineNameCommand(
  $e as element(r:DivineNameCommand)
  ) {
  <j:divineName>{stxt:convert($e/node())}</j:divineName>
};

declare function stxt:TranslitCommand(
  $e as element(r:TranslitCommand)
  ) {
  let $lang := $e/r:LangCode/string()
  return
    if (exists($e/r:OriginalLanguage))
    then
      let $original := substring-before($lang, "-")
      return
        <tei:choice>
          <tei:orig>{stxt:convert($e/r:AsWritten)}</tei:orig>
          <tei:reg>
            <j:segGen xml:lang="{$original}">{
              stxt:convert($e/r:OriginalLanguage)
            }</j:segGen>
          </tei:reg>
        </tei:choice>
    else
      <tei:seg xml:lang="{$lang}">{
        stxt:convert($e/r:AsWritten)
      }</tei:seg>
};

declare function stxt:SicCommand(
  $e as element(r:SicCommand)
  ) {
  <tei:choice>{
    stxt:convert($e/r:IncorrectText),
    stxt:convert($e/r:CorrectedText)
  }</tei:choice>
};

declare function stxt:IncorrectText(
  $e as element(r:IncorrectText)
  ) {
  <tei:sic>{stxt:convert($e/node())}</tei:sic>
};

declare function stxt:CorrectedText(
  $e as element(r:CorrectedText)
  ) {
  <tei:corr>{stxt:convert($e/node())}</tei:corr>
};

declare function stxt:pass-through(
  $e as element()
  ) {
  stxt:convert($e/node())
};

declare function stxt:page-image-url(
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
declare function stxt:PageBreakCommand(
  $e as element(r:PageBreakCommand)
  ) {
  <tei:pb ed="original" n="{stxt:convert($e/r:BookPage)}"/>,
  if (exists($e/r:ScanPage))
  then
    <tei:pb
      ed="scan"
      n="{stxt:convert($e/r:ScanPage)}"
      facs="{stxt:page-image-url($e)}"
      />
  else ()
};

declare function stxt:FootnotePageBreakCommand(
  $e as element(r:FootnotePageBreakCommand)
  ) {
  stxt:PageBreakCommand(root($e)//r:PageBreakCommand[r:BookPage=$e/r:BookPage])
};

declare function stxt:NamedCommand(
  $e as element(r:NamedCommand)
  ) {
  <tei:anchor n="NamedCommand" xml:id="{concat("start-",$e/r:ShortName)}"/>
};

declare function stxt:EndNamedCommand(
  $e as element(r:EndNamedCommand)
  ) {
  <tei:anchor n="EndNamedCommand" xml:id="{concat("end-",$e/r:ShortName)}"/>
};

declare function stxt:EndNoteCommand(
  $e as element(r:EndNoteCommand)
  ) {
  <tei:anchor n="EndNoteCommand" xml:id="{concat("end-",$e/r:ShortName)}"/>
};

declare function stxt:EndInstructCommand(
  $e as element(r:EndInstructCommand)
  ) {
  <tei:anchor n="EndInstructCommand" xml:id="{concat("end-",$e/r:ShortName)}"/>
};

(:~ find out what scan pages a (set of) node(s) is(are) on :)
declare function stxt:page(
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

declare function stxt:note-like-commands(
  $e as element()
  ) {
  element {
    if ($e instance of element(r:InstructCommand))
    then "j:instruct"
    else "tei:note"
  }{
    attribute xml:id {
      if ($e instance of element(r:FootNoteCommand))
      then concat("fn_", stxt:page($e), "_", $e/r:Number/string())
      else $e/r:ShortName},
    stxt:convert($e/r:NoteContent)
  },
  if ($e instance of element(r:FootNoteCommand))
  then ()
  else 
    <tei:anchor n="{local-name($e)}" xml:id="{concat("start-", $e/r:ShortName)}"/>
};

declare function stxt:formatting-commands(
  $e as element()
  ) {
  ( (: ignore all formatting :) )
};

declare function stxt:end-l(
  $e as element()
  ) {
  <tei:lb/>
};

declare function stxt:end-p(
  $e as element()
  ) {
  stxt:end-l($e),
  <tei:p/>
};

(: the section command leaves a div (which should 
 : ends at the end of the file!) and a head in-place
 :)
declare function stxt:SectionCommand(
  $e as element(r:SectionCommand)
  ) {
  <tei:div>
    {stxt:convert($e/r:SectionName)}
  </tei:div>
};

declare function stxt:SectionName(
  $e as element(r:SectionName)
  ) {
  <tei:head>{stxt:convert($e/node())}</tei:head>
};

declare function stxt:VerseDivision(
  $e as element(r:VerseDivision)
  ) {
  <tei:ab type="verse">
    <tei:label n="chapter">{$e/r:Chapter/string()}</tei:label>
    <tei:label n="verse">{$e/r:Verse/string()}</tei:label>
  </tei:ab>
};

declare function stxt:Escape(
  $e as element(r:Escape)
  ) {
  substring-after($e, "\")
};