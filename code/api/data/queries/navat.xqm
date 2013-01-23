(:~ 
 : navigation API for an attribute.
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace navat = 'http://jewishliturgy.org/api/data/navat';

import module namespace api="http://jewishliturgy.org/modules/api" 
  at "/db/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "/db/code/modules/app.xqm";
import module namespace nav="http://jewishliturgy.org/modules/nav"
  at "nav.xqm";
import module namespace resp="http://jewishliturgy.org/modules/resp"
  at "/db/code/modules/resp.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $navat:allowed-methods := ("GET","PUT","DELETE");
declare variable $navat:accept-content-type := (
  api:html-content-type(),
  api:text-content-type()
  );
declare variable $navat:request-content-type := (
  api:text-content-type()
  );
declare variable $navat:test-source := "/code/tests/api/original/navat.t.xml";

declare function navat:title(
  $uri as item()
  ) as xs:string {
  let $attr := 
    if ($uri instance of attribute())
    then $uri
    else nav:api-path-to-sequence($uri)
  return concat("@", name($attr))
};

declare function navat:allowed-methods(
  $uri as item()
  ) as xs:string* {
  $navat:allowed-methods
};

declare function navat:accept-content-type(
  $uri as item()
  ) as xs:string* {
  $navat:accept-content-type
};

declare function navat:request-content-type(
  $uri as item()
  ) as xs:string* {
  $navat:request-content-type
};

declare function navat:list-entry(
  $uri as item()
  ) as element(li) {
  api:list-item(
    element span {navat:title($uri)},
    if ($uri instance of attribute())
    then nav:sequence-to-api-path($uri)
    else $uri,
    navat:allowed-methods($uri),
    navat:accept-content-type($uri),
    navat:request-content-type($uri),
    ()
  )
};

declare function local:disallowed() {
  let $d := api:allowed-method($navdoc:allowed-methods)
  where not($d)
  return api:error((), "Method not allowed")
};

(: check if we have access to the document and if it exists 
 : if it doesn't exist, use error 404. If we do not have access
 : send 401 (if not logged in) or 403 (if logged in as a different user)
 :)
declare function local:unauthorized-read(
  $uri as xs:string
  ) as element()? {
  let $attribute := nav:api-path-to-sequence($uri)
  where empty($attribute) 
  return
    api:error(404, "Attribute cannot be found", $uri)
};

(: check if the user has write access to a document :)
declare function local:unauthorized-write(
  $uri as xs:string
  ) as element()? {
  let $attribute := nav:api-path-to-sequence($uri)
  where empty($attribute) 
  return
    api:error(404, "Attribute cannot be found", $uri)
};

declare function navat:get() {
  let $test-result := api:tests($navat:test-source)
  let $uri := request:get-uri()
  let $accepted := api:get-accept-format(navat:accept-content-type($uri))
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
    else 
      let $value := nav:api-path-to-sequence($uri)/string()
      return
        if ($format = "txt")
        then $value
        else
          api:list(
            <title>{navat:title($uri)}</title>,
            <ul class="content">
              <li>{$value}</li>
            </ul>,
            0,
            false(),
            navat:allowed-methods($uri),
            navat:accept-content-type($uri),
            navat:request-content-type($uri),
            $navat:test-source
          )    
};

declare function navat:put() {
  let $uri := request:get-uri()
  let $unauthorized := local:unauthorized-write($uri)
  let $attribute := nav:api-path-to-sequence($uri)
  let $data := api:get-data()
  let $accepted := api:get-accept-format($navdoc:request-content-type)
  return
    if (not($accepted instance of element(api:content-type)))
    then $accepted
    else if ($unauthorized)
    then $unauthorized
    else 
      (
        resp:remove($attribute),
        update value $attribute with $data,
        resp:add-attribute($attribute, "editor", app:auth-user(), "value")
      ) 
};

declare function navat:post() {
  local:disallowed()
};

declare function navat:delete() {
  let $uri := request:get-uri()
  let $unauthorized := local:unauthorized-write($uri)
  return
    if ($unauthorized)
    then $unauthorized
    else 
      let $attribute := nav:api-path-to-sequence($uri)
      return (
        resp:remove($attribute),
        update delete $attribute,
        response:set-status-code(204)
      )
};

declare function navat:go(
  ) {
  navat:go(nav:api-path-to-sequence(request:get-uri()))
};

declare function navat:go(
  $attr as attribute()
  ) {
  let $method := api:get-method()
  return
    if ($method = "GET")
    then navat:get()
    else if ($method = "PUT") 
    then navat:put()
    else if ($method = "POST")
    then navat:post()
    else if ($method = "DELETE")
    then navat:delete()
    else local:disallowed()
};

