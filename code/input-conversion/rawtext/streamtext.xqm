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

    case text() return $n
    default return (
      util:log-system-out(("Not implemented in streamtext: ", name($n))),
      stxt:convert($n/node())
    )
      
};

