(:~ navigation API helper module
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace nav = 'http://jewishliturgy.org/modules/nav';

import module namespace api="http://jewishliturgy.org/modules/api"
  at "api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "xmldb:exist:///code/modules/app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "xmldb:exist:///code/modules/debug.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace cc="http://web.resource.org/cc/";

declare variable $nav:accept-content-types :=
    (
      api:html-content-type(),
      api:xml-content-type(),
      api:tei-content-type()
    );
declare variable $nav:request-content-types :=
    (
      api:xml-content-type(),
      api:tei-content-type()
    );

(: these are path shortcuts to specific places
 : note that they are expected to be in a string-join(*, "/")
 : so / => //
 :)
declare variable $nav:shortcuts :=
  <nav:shortcuts>
    <nav:shortcut path="..." to=""/>
    <nav:shortcut path="-selection" to="/j:selection">
      <nav:name>Selection</nav:name>
    </nav:shortcut>
    <nav:shortcut path="-repository" to="/j:repository">
      <nav:name>Repository</nav:name>
    </nav:shortcut>
    <nav:shortcut path="-concurrent" to="/j:concurrent">
      <nav:name>Concurrent</nav:name>
    </nav:shortcut>
    <nav:shortcut path="-view" to="/j:view">
      <nav:name>Views</nav:name>
    </nav:shortcut>
    <nav:shortcut path="-lang" to="tei:TEI/@xml:lang">
      <nav:name>Primary language</nav:name>
    </nav:shortcut>
    <nav:shortcut path="-title" to="/tei:title[@type='main']">
      <nav:name>Title</nav:name>
    </nav:shortcut>
    <nav:shortcut path="-subtitle" to="/tei:title[@type='sub']">
      <nav:name>Subtitle</nav:name>
    </nav:shortcut>
  </nav:shortcuts>;

declare function nav:sequence-to-api-path(
  $node as node()*
  ) as xs:string* {
  for $n in $node
  let $doc := root($n)
  let $doc-uri := document-uri($doc)
  let $purpose := tokenize($doc-uri, "/")[5]
  let $doc-name := replace(util:document-name($doc), "\.[^.]+$", "")
  return
    concat("/code/api/data/", $purpose, "/", $doc-name, 
      if ($n instance of document-node())
      then ""
      else concat("/", nav:xpath-to-url(app:xpath($n))))
};

(:~ given a complete navigation API URL, return a sequence :)
declare function nav:api-path-to-sequence(
  $url as xs:string
  ) as node()* {
  let $excluded := "updated.xml"
  let $tokens := tokenize(replace($url, "^(/code/api/data)?/", ""), "/")[.]
  let $purpose := $tokens[1]
  let $resource := concat($tokens[2], ".xml")[$tokens[2] != "..."]
  let $docs :=
    if ($resource)
    then collection("/group")
      (: the collection name is of the form (1)/db(2)/group(3)/[group](4)/[purpose](5) :)
      [util:document-name(.)=$resource]
      [tokenize(util:collection-name(.),"/")[5]=$purpose]
    else collection("/group")
      [tokenize(util:collection-name(.),"/")[5]=$purpose]
      [not(util:document-name(.)=$excluded)]
  let $xpath := nav:url-to-xpath(string-join(("",subsequence($tokens, 3)), "/"))/nav:path/string()
  where exists($docs)
  return
    if ($xpath)
    then util:eval(concat("$docs", $xpath))
    else $docs
};

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
    let $activities := ("-compiled", "-html", "-expanded", "-license")
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
              concat("^(@)?(([^.]+)\.)?([^,;@]+)(@([^,;]+))?(,(\d+))?", 
                if ($n = count($url-tokens)) 
                then "(;(\S+))?"
                else "")
            let $groups := text:groups($token, $regex)
            let $is-attribute := $groups[2]
            let $prefix := $groups[4]
            let $element := $groups[5]
            let $type := $groups[7]
            let $index := $groups[9]
            let $shortcut := $nav:shortcuts/*[@path=$token]/@to
            return
              if ($n = $n-tokens and $token = $activities)
              then ()
              else if ($token = "-id")
              then
                if ($n = $n-tokens)
                then "*[@xml:id]"
                else concat("id('", $url-tokens[$n + 1] ,"')")
              else if ($url-tokens[$n - 1] = "-id")
              then () 
              else
                if ($shortcut)
                then string($shortcut)
                else
                  string-join((
                    $is-attribute,
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
        },
        element nav:activity {
          (: last() should work here, but an eXist bug(?) is preventing it from doing so :)
          $url-tokens[count($url-tokens)][.=$activities]
        }
      }
      
};

declare function nav:xpath-to-url(
  $xpath as xs:string
  ) as xs:string {
  let $xpath-tokens := tokenize($xpath, "/") 
  return
    string-join(
      (
      if (starts-with($xpath, "/"))
      then ""
      else (),
      for $token at $n in $xpath-tokens
      let $groups := text:groups($token, "^(@)?(([^:]+):)?(([^\[\*]+)|(\*\[(\d+)\]))(\[@type='(\S*)'\])?(\[(\d+)\])?")
      let $is-attribute := $groups[2]
      let $prefix := $groups[4]
      let $element := $groups[6]
      let $nelement := $groups[8]
      let $type := $groups[10]
      let $index := $groups[12]
      return
        if (not($token))  
        then
         (: // tokenizes to an empty token, but at the beginning of the string, 
          an empty token means the path began with / :)
          "..."[$n > 1]
        else if (starts-with($token, "*[@xml:id]"))
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

(:~ return an XML hierarchy as an HTML navigation page
 : TODO: this needs to be reworked :)
declare function nav:xml-to-navigation(
  $root as element()+,
  $position as xs:string?
  ) as element() {
  api:serialize-as("xhtml"),
  let $methods := ("GET", "POST", "DELETE")
  let $this-url := request:get-uri()
  return
    api:list(
      element title { 
        string-join(($root[1]/name(), ("(", $root/@xml:id, ")")[count($root) = 1 and $root/@xml:id/string()]), "") },
      let $children := 
        if (count($root) = 1)
        then $root/*
        else $root
      return (
        element ul {
          attribute class { "common" },
          api:list-item(
            element span { attribute class {"service"}, "compile" },
            concat($this-url, "/-compile"),
            "GET",
            api:html-content-type(),
            (), ()
          )
        },
        element ul {
          if (empty($children))
          then
            (element li { attribute class {"literal-value"}, string($root) })
              [string($root)]
          else
            for $child in $children
            let $name := $child/name()
            let $type := $child/@type/string()
            let $n := count($child/preceding-sibling::*[name()=$name][if ($type) then (@type=$type) else true()]) + 1
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
      }),
      0,
      false(),
      $methods,
      $nav:accept-content-types,
      $nav:request-content-types    
    )
};
