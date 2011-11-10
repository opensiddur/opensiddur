(:~ 
 : navigation API for an element. Some elements may need special processing
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace navel = 'http://jewishliturgy.org/api/data/navel';

import module namespace api="http://jewishliturgy.org/modules/api" 
  at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "/code/modules/app.xqm";
import module namespace nav="http://jewishliturgy.org/modules/nav"
  at "nav.xqm";
import module namespace navat="http://jewishliturgy.org/api/data/navat"
  at "navat.xqm";
import module namespace resp="http://jewishliturgy.org/modules/resp"
  at "/code/modules/resp.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace err="http://jewishliturgy.org/errors";

declare variable $navel:allowed-methods := ("GET","PUT","POST","DELETE");
declare variable $navel:accept-content-type := (
  api:html-content-type(),
  api:xml-content-type(),
  api:tei-content-type()
  );
declare variable $navel:request-content-type := (
  api:xml-content-type(),
  api:tei-content-type()
  );
declare variable $navel:test-source := "/code/tests/api/original/navel.t.xml";

(: the element can be given as an element() or a uri to the element :)
declare function navel:title(
  $uri-or-element as item()
  ) as xs:string {
  let $element := 
    if ($uri-or-element instance of element())
    then $uri-or-element
    else nav:api-path-to-sequence($uri-or-element)
  let $type := $element/@type/string()
  let $name := name($element)
  let $n := count($element/preceding-sibling::*[name()=$name][if ($type) then (@type=$type) else true()]) + 1
  return string-join(($name, ("(", $type, ")")[$type], ("[", $n, "]")),"")
};

declare function navel:allowed-methods(
  $uri-or-element as item()
  ) as xs:string* {
  let $position := 
    if ($uri-or-element instance of element())
    then ()
    else substring-after($uri-or-element, ";")
  return
    if ($position=("before","after"))
    then ("GET", "PUT")
    else $navel:allowed-methods
};

declare function navel:accept-content-type(
  $uri-or-element as item()
  ) as xs:string* {
  let $position := 
    if ($uri-or-element instance of element())
    then ()
    else substring-after($uri-or-element, ";")
  return
    if ($position=("before","after"))
    then api:html-content-type()
    else $navel:accept-content-type
};

declare function navel:request-content-type(
  $uri-or-element as item()
  ) as xs:string* {
  $navel:request-content-type
};

(:~ return if the given URI supports before/after :)
declare function navel:supports-positional(
  $uri-or-element as item()
  ) as xs:boolean {
  let $element := 
    if ($uri-or-element instance of element())
    then $uri-or-element
    else nav:api-path-to-sequence($uri-or-element)
  return
    name($element)=("tei:ptr")
};

declare function navel:list-entry(
  $uri-or-element as item()
  ) as element(li) {
  let $uri :=
    if ($uri-or-element instance of element())
    then nav:sequence-to-api-path($uri-or-element)
    else $uri-or-element
  return
    api:list-item(
      element span {navel:title($uri-or-element)},
      $uri,
      navel:allowed-methods($uri-or-element),
      navel:accept-content-type($uri-or-element),
      navel:request-content-type($uri-or-element),
      if (navel:supports-positional($uri-or-element))
      then (
        "before", concat($uri, ";before"), 
        "after", concat($uri, ";after")
      )
      else ()
    )
};

declare function local:disallowed() {
  (: This probably needs no changes :)
  api:allowed-method($navdoc:allowed-methods),
  api:error((), "Method not allowed")
};

(: check if we have access to the document and if it exists 
 : if it doesn't exist, use error 404. If we do not have access
 : send 401 (if not logged in) or 403 (if logged in as a different user)
 :)
declare function local:unauthorized-read(
  $uri as xs:string
  ) as element()? {
  let $element := nav:api-path-to-sequence($uri)
  where empty($element) 
  return
    api:error(404, "Element cannot be found", $uri)
};

(: check if the user has write access to a document :)
declare function local:unauthorized-write(
  $uri as xs:string
  ) as element()? {
  let $element := nav:api-path-to-sequence($uri)
  where empty($element) 
  return
    api:error(404, "Element cannot be found", $uri)
};

declare function local:get-position(
  $uri as xs:string,
  $position as xs:string,
  $accepted as element(),
  $format as xs:string
  ) {
  api:serialize-as("xhtml", $accepted),
  api:list(
    <title>{navel:title($uri)}</title>,
    <ul class="common">
      <li>Represents the position {$position} {navel:title(concat($uri, "/.."))}</li>
    </ul>,
    0,
    false(),
    navel:allowed-methods($uri),
    navel:accept-content-type($uri),
    navel:request-content-type($uri),
    $navel:test-source
  )
};

declare function navel:position-links(
  $uri as xs:string
  ) as item()* {
  if (navel:supports-positional($uri))
  then
    for $position in ("before", "after")
    let $with-position := concat($uri, ";", $position)
    return
      api:list-item(
        <span>{$position}</span>,
        $with-position,
        navel:allowed-methods($with-position),
        navel:accept-content-type($with-position),
        navel:request-content-type($with-position),
        ()
      )
  else ()
};

declare function local:get-noposition(
  $uri as xs:string, 
  $accepted as element(), 
  $format as xs:string
  ) {
  let $root := nav:api-path-to-sequence($uri)
  let $children := $root/* 
  return
    if ($format = ("tei", "xml"))
    then (
      api:serialize-as("xml", $accepted),
      $root
    )
    else (
      api:serialize-as("xhtml", $accepted),
      let $list-body := (
        <ul class="common">{
          navel:position-links($uri)
        }</ul>,
        <ul class="results">{
          for $attribute in $root/@*
          return navat:list-entry(concat($uri, "/@", nav:xpath-to-url(name($attribute)))),
          if (empty($children))
          then
            (element li { attribute class {"content"}, string($root) })
              [string($root)]
          else
            for $child in $children
            let $name := $child/name()
            let $type := $child/@type/string()
            let $n := count($child/preceding-sibling::*[name()=$name][if ($type) then (@type=$type) else true()]) + 1
            let $link := 
              concat($uri, "/",
                nav:xpath-to-url(
                  string-join(($name,
                    ("[@type='", $type, "']")[$type], 
                    "[", $n, "]"),"")
                )
              )
            return 
              api:list-item(
                  element span { 
                    attribute class {"service"}, 
                    navel:title($child)
                  }, 
                  $link,
                  navel:allowed-methods($child),
                  navel:accept-content-type($child),
                  navel:request-content-type($child),
                  for $position in ("before", "after")
                  let $position-link := concat($uri, ";", $position)
                  return ($position, $position-link)
                )
        }</ul>
      )
      return
        api:list(
          <title>{navel:title($uri)}</title>,
          $list-body,
          count($list-body/self::ul[@class="results"]/li),
          false(),
          navel:allowed-methods($uri),
          navel:accept-content-type($uri),
          navel:request-content-type($uri),
          $navel:test-source
        )
    )
};

declare function navel:get() {
  let $test-result := api:tests($navel:test-source)
  let $uri := request:get-uri()
  let $accepted := api:get-accept-format(navel:accept-content-type($uri))
  let $format := api:simplify-format($accepted, "xhtml")
  let $unauthorized := local:unauthorized-read($uri)
  let $position := substring-after($uri, ";")
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($test-result)
    then $test-result
    else if ($unauthorized)
    then $unauthorized
    else if ($position = ("before", "after"))
    then local:get-position($uri, $position, $accepted, $format)
    else local:get-noposition($uri, $accepted, $format)
    
};

declare function navel:put() {
  let $uri := request:get-uri()
  let $unauthorized := local:unauthorized-write($uri)
  let $element := nav:api-path-to-sequence($uri)
  let $data := api:get-data()
  let $new-id := (
    $data/@xml:id/string(), 
    concat(local-name($data), "_", util:uuid())
    )[1]
  let $accepted := api:get-accept-format($navdoc:request-content-type)
  let $position := substring-after($uri, ";")[.=("before", "after")]
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($unauthorized)
    then $unauthorized
    else if (count($element) >1)
    then 
      api:error(400, "HTTP PUT can only be used on a single element.")
    else 
      let $doc := root($element)
      let $data-with-id :=
        element { name($data) }{
          attribute xml:id { $new-id },
          $data/(@* except @xml:id),
          $data/*
        }
      let $return :=
        if ($doc/id($new-id)[not(. is $element) and not($position)])
        then 
          api:error(400, "The chosen xml:id is not unique.", $new-id)
        else if ($position="before") 
        then
         update insert $data-with-id preceding $element
        else if ($position="after")
        then 
          update insert $data-with-id following $element
        else if (local-name($data)=local-name($element) 
          and namespace-uri($data)=namespace-uri($element))
        then (
          resp:remove($element),
          update replace $element with $data-with-id
        ) 
        else
          api:error(400, "Content is not the same type as the document")
      return (
        if ($return instance of element(error))
        then ()
        else resp:add($doc/id($new-id), "author", app:auth-user(), "location value"),
        $return
      )
};

declare function navel:post() {
  local:disallowed()
};

declare function navel:delete() {
  let $uri := request:get-uri()
  let $unauthorized := local:unauthorized-write($uri)
  return
    if ($unauthorized)
    then $unauthorized
    else 
      let $element := nav:api-path-to-sequence($uri)
      return (
        resp:remove($element),
        update delete $element,
        response:set-status-code(204)
      )
};

declare function navel:go(
  ) {
  navel:go(nav:api-path-to-sequence(request:get-uri()))
};

declare function navel:go(
  $doc as element()
  ) {
  let $method := api:get-method()
  return
    if ($method = "GET")
    then navel:get()
    else if ($method = "PUT") 
    then navel:put()
    else if ($method = "POST")
    then navel:post()
    else if ($method = "DELETE")
    then navel:delete()
    else local:disallowed()
};

