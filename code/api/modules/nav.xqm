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
        element nav:path { 
          string-join((
            if (starts-with($url, "/"))
            then ""
            else (),
            let $n-tokens := count($url-tokens)
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
            return
              if ($token = "-id")
              then
                if ($n = $n-tokens)
                then "*[@xml:id]"
                else concat("id('", $url-tokens[$n + 1] ,"')")
              else if ($url-tokens[$n - 1] = "-id")
              then () 
              else
                string-join((
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
      }
      
};

declare function nav:xpath-to-url(
  $xpath as xs:string
  ) as xs:string {
  let $xpath-tokens := tokenize($xpath, "/")[.]
  return
    string-join(
      (
      if (starts-with($xpath, "/"))
      then ""
      else (),
      for $token in $xpath-tokens
      let $groups := text:groups($token, "(([^:]+):)?(([^\[\*]+)|(\*\[(\d+)\]))(\[@type='(\S*)'\])?(\[(\d+)\])?")
      let $prefix := $groups[3]
      let $element := $groups[5]
      let $nelement := $groups[7]
      let $type := $groups[9]
      let $index := $groups[11]
      return
        if (starts-with($token, "*[@xml:id]"))
        then
          "-id"
        else if (matches($token, "^id\("))
        then
          let $id := text:groups($token, "id\('([^']+)'\)")
          return concat("-id/", $id[2])
        else
          string-join(($prefix, "."[$prefix], $element, $nelement, ("@", $type)[$type], (",", $index)[$index]), "")
      ),
        "/"
      )
};

(:~ return an XML hierarchy as an HTML navigation page :)
declare function nav:xml-to-navigation(
  $root as element()+,
  $position as xs:string?
  ) as element() {
  api:serialize-as("xhtml"),
  let $methods := ("GET", "POST", "DELETE")
  let $this-url := request:get-uri()
  return
    api:list(
      element title { attribute class {"service"}, 
        string-join(($root[1]/name(), ("(", $root/@xml:id, ")")[count($root) = 1 and $root/@xml:id/string()]), "") },
      let $children := 
        if (count($root) = 1)
        then $root/*
        else $root
      return
        element ul {
          if (empty($children))
          then
            (element li { attribute class {"literal-value"}, string($root) })
              [string($root)]
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