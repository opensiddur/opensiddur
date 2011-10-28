(:~ navigation API helper module
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace nav = 'http://jewishliturgy.org/modules/nav';

import module namespace api="http://jewishliturgy.org/modules/api"
  at "api.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "xmldb:exist:///code/modules/debug.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare variable $nav:accept-content-types :=
    (
      api:html-content-type(),
      api:xml-content-type(),
      for $x in api:xml-content-type() 
      return concat($x, "; flat"),
      api:tei-content-type(), 
      concat(api:tei-content-type(), "; flat")
    );
declare variable $nav:request-content-types :=
    (
      api:xml-content-type(),
      for $x in api:xml-content-type() 
      return concat($x, "; flat"),
      api:tei-content-type(), 
      concat(api:tei-content-type(), "; flat")
    );

(:~ convert a nav URL to an XPath expression
 : if the URL contains any illegal characters, 
 : return an api:error 
 :) 
declare function nav:url-to-xpath(
  $url as xs:string
  ) as element() {
  if (matches($url, "[()':]|(update\s)"))
  then
    api:error(404, "The given URL contains illegal characters", $url)
  else 
    let $url-tokens := tokenize($url, "/")[.]
    return
      element nav:xpath {
        if ($url-tokens[1] = "id")
        then 
          let $id-token := $url-tokens[2] 
          let $id := 
            if (contains($id-token, ";"))
            then substring-before($id-token, ";")
            else $id-token
          return (
            element nav:path {
              concat("id('", $id-token  , "')")
            },
            element nav:position {
              substring-after($id-token, ";")
            }
          )
        else (
          element nav:path { 
            string-join(("",
              for $token at $n in $url-tokens
              let $regex :=
                concat("(([^.]+)\.)?([^,;@]+)(@([^,;]+))?(,(\d+))?", 
                  if ($n = count($url-tokens)) 
                  then "(;(\S+))?"
                  else "")
              let $groups := text:groups($token, $regex)
              let $prefix := $groups[3]
              let $element := $groups[4]
              let $type := $groups[6]
              let $index := $groups[8]
              return string-join((
                $prefix, ":"[$prefix], 
                if ($element castable as xs:integer)
                then ("*[", $element, "]")
                else $element, ("[@type='", $type, "']")[$type], ("[", $index, "]")[$index]
                ),"")
              ),
              "/"
            )
          },
          element nav:position {
            substring-after($url-tokens[last()], ";")
          }
        )
      }
      
};

declare function nav:xpath-to-url(
  $xpath as xs:string
  ) as xs:string {
  if (matches($xpath, "^/?id\("))
  then
    let $groups := text:groups($xpath, "/?id\('([^']+)'\)")
    return concat("/id/", $groups[2])
  else
    let $xpath-tokens := tokenize($xpath, "/")[.]
    return
      string-join(
        for $token in $xpath-tokens
        let $groups := text:groups($token, "(([^:]+):)?(([^\[\*]+)|(\*\[(\d+)\]))(\[@type='(\S*)'\])?(\[(\d+)\])?")
        let $prefix := $groups[3]
        let $element := $groups[5]
        let $nelement := $groups[7]
        let $type := $groups[9]
        let $index := $groups[11]
        return 
          string-join(($prefix, "."[$prefix], $element, $nelement, ("@", $type)[$type], (",", $index)[$index]), ""),
        "/"
      )
};

(:~ return an XML hierarchy as an HTML navigation page :)
declare function nav:xml-to-navigation(
  $root as element(),
  $position as xs:string?
  ) as element() {
  api:serialize-as("xhtml"),
  let $methods := ("GET", "POST", "DELETE")
  let $this-url := request:get-uri()
  return
    api:list(
      element title { attribute class {"service"}, 
        string-join(($root/name(), ("(", $root/@xml:id, ")")[$root/@xml:id/string()]), "") },
      let $children := $root/*
      return
        element ul {
          if (empty($children))
          then
            element li { attribute class {"literal-value"}, string($root) }
          else
            for $child in $children
            let $name := $child/name()
            let $type := $child/@type/string()
            let $n := count($child/preceding-sibling::*[name()=$name][($type, true())[1]]) + 1
            let $link := 
              concat($this-url, "/",
                nav:xpath-to-url(
                  string-join(($name,
                    ("[@type='", $type, "']")[$type], 
                    "[", $n, "]"),"")
                )
              )
            return 
              api:list-item(
                  element span { attribute class {"service"}, 
                    string-join(($name, ("(", $type, ")")[$type], ("[", $n, "]")),"")
                  }, 
                  $link,
                  $methods,
                  $nav:accept-content-types,
                  $nav:request-content-types,
                  (
                    "before", 
                    concat($link, ";before"), 
                    "after", 
                    concat($link, ";after")
                  )
                )
      },
      0,
      false(),
      $methods,
      $nav:accept-content-types,
      $nav:request-content-types    
    )
};