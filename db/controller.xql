xquery version "3.0";
(: temporary api controller.
 : run the correct API
 :
 :)
import module namespace debug="http://jewishliturgy.org/transform/debug"
	at "/code/modules/debug.xqm";
import module namespace api="http://jewishliturgy.org/modules/api"
  at "/code/api/modules/api.xqm";

import module namespace index="http://jewishliturgy.org/api/index"
	at "/code/api/index.xqm";
import module namespace dindex="http://jewishliturgy.org/api/data/index"
  at "/code/api/data/dindex.xqm";
import module namespace tran="http://jewishliturgy.org/api/transliteration"
  at "/code/api/data/transliteration.xqm";
import module namespace orig="http://jewishliturgy.org/api/data/original"
  at "/code/api/data/original.xqm";
import module namespace user="http://jewishliturgy.org/api/user"
  at "/code/api/user.xqm";
import module namespace grp="http://jewishliturgy.org/api/group"
  at "/code/api/group.xqm";
import module namespace login="http://jewishliturgy.org/api/login"
  at "/code/api/login.xqm";
import module namespace demo="http://jewishliturgy.org/api/demo"
  at "/code/api/demo.xqm";

declare namespace exist="http://exist.sourceforge.net/NS/exist";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

declare variable $local:disallowed := 
  api:rest-error(405, "Method not supported");

declare function local:do-index(
  $tokens as xs:string*
  ) {
  switch (api:get-method())
  case "GET"
  return index:list()
  default return $local:disallowed
};

declare function local:do-data(
  $tokens as xs:string*
  ) {
  if (not($tokens[3]))
  then
    switch (api:get-method())
      case "GET"
      return dindex:list()
      default
      return $local:disallowed
  else
    switch($tokens[3])
    case "OpenSearchDescription"
    return
      dindex:open-search(request:get-parameter("source", ""))
    case "original"
    return
      switch (api:get-method())
      case "GET"
      return 
        if ($tokens[4])
        then
          if ($tokens[5] = "access")
          then orig:get-access($tokens[4])
          else orig:get($tokens[4])
        else
          let $query := request:get-parameter("q", "")
          let $start := request:get-parameter("start", 1)
          let $max-results := request:get-parameter("max-results", 100)
          return
            orig:list($query, $start, $max-results)
      case "PUT"
      return 
        if ($tokens[5] = "access")
        then orig:put-access($tokens[4], request:get-data())
        else orig:put($tokens[4], request:get-data())
      case "POST"
      return orig:post(request:get-data())
      case "DELETE"
      return orig:delete($tokens[4])
      default
      return $local:disallowed
    case "transliteration"
    return
      switch (api:get-method())
      case "GET"
      return 
        if ($tokens[4])
        then
          if ($tokens[5] = "access")
          then tran:get-access($tokens[4])
          else tran:get($tokens[4])
        else
          let $query := request:get-parameter("q", "")
          let $start := request:get-parameter("start", 1)
          let $max-results := request:get-parameter("max-results", 100)
          return
            tran:list($query, $start, $max-results)
      case "PUT"
      return 
        if ($tokens[5] = "access")
        then tran:put-access($tokens[4], request:get-data())
        else tran:put($tokens[4], request:get-data())
      case "POST"
      return tran:post(request:get-data())
      case "DELETE"
      return tran:delete($tokens[4])
      default
      return $local:disallowed
    default return <exist:ignore/>
};

declare function local:do-demo(
  $tokens as xs:string*
  ) {
  if (not($tokens[3]))
  then
    demo:list()
  else if ($tokens[3]="transliteration")
  then
    switch (api:get-method())
    case "GET"
    return demo:transliteration-list(
      request:get-parameter("q", ""),
      request:get-parameter("start", 1),
      request:get-parameter("max-results", 100)
      )
    case "POST"
    return 
      if ($tokens[4])
      then
        switch (
          api:simplify-format(
            api:get-request-format(
              ("text/plain", "application/xml", "text/xml")
            ),
            "txt"
          )
        )
        case "txt"
        return 
          demo:transliterate-text(
            util:binary-to-string(request:get-data()), 
            $tokens[4]
          )
        case "xml"
        return (
          demo:transliterate-xml(
            request:get-data(), $exist:resource)
        )
        default
        return api:rest-error(400, "Content-Type not allowed")
      else
        $local:disallowed
    default
    return $local:disallowed
  else <exist:ignore/>
};

declare function local:do-group(
  $tokens as xs:string*
  ) {
  if (not($tokens[3]))
  then 
    switch(api:get-method())
    case "GET"
    return 
      grp:list(
        request:get-parameter("start", 1),
        request:get-parameter("max-results", 100)
      )
    default
    return $local:disallowed
  else
    switch(api:get-method())
    case "GET"
    return 
      let $f :=
          api:simplify-format(
            api:get-accept-format(
              ("application/xhtml+xml", "text/html", "application/xml", "text/xml")
            ),
            "none"
          )
      return
        if ($f = ("html", "xhtml"))
        then grp:get-html($tokens[3])
        else if ($f = "xml")
        then grp:get-xml($tokens[3])
        else api:rest-error(400, "Bad content type")
    case "PUT"
    return grp:put($tokens[3], request:get-data())
    case "DELETE"
    return grp:delete($tokens[3])
    default
    return $local:disallowed
};

declare function local:do-login(
  $tokens as xs:string*
  ) {
  if (not($tokens[3]))
  then
    switch (api:get-method())
    case "GET"
    return
      let $f :=
          api:simplify-format(
            api:get-accept-format(
              ("application/xhtml+xml", "text/html", "application/xml", "text/xml")
            ),
            "none"
          )
      return
        if ($f = ("html", "xhtml"))
        then
          login:get-html(
            request:get-parameter("user", ()),
            request:get-parameter("password", ())
          )
        else if ($f = "xml")
        then login:get-xml()
        else api:rest-error(400, "Bad content type")
    case "POST"
    return
      switch(
        api:simplify-format(
          api:get-request-format(
            ("application/x-www-url-formencoded", "application/xml", "text/xml")
          ), 
          "none"
        )
      )
      case "form"
      return 
        login:post-form(
          request:get-parameter("user", ()), 
          request:get-parameter("password", ())
        )
      case "xml"
      return
        login:post-xml(request:get-data())
      default
      return api:rest-error(400, "Bad content type")
    case "DELETE"
    return login:delete()
    default return $local:disallowed
  else
    <exist:ignore/>
    
};

declare function local:do-logout(
  $tokens as xs:string*
  ) {
  switch (api:get-method())
  case "GET"
  return login:get-logout()
  case "POST"
  return login:post-logout()
  default return $local:disallowed
};

declare function local:do-user(
  $tokens as xs:string*
  ) {
  if (not($tokens[3]))
  then
    switch (api:get-method())
    case "GET"
    return 
      user:list(
        request:get-parameter("q", ""), 
        request:get-parameter("start", 1),
        request:get-parameter("max-results", 100)
      )
    case "POST"
    return
      switch(
        api:simplify-format(
          api:get-request-format(
            ("application/x-www-form-urlencoded", "application/xml", "text/xml")
          ),
          "none"
        )
      )
      case "form"
      return user:post-form(
        request:get-parameter("user", ()),
        request:get-parameter("password", ())
        )
      case "xml"
      return user:post-xml(request:get-data())
      default return api:rest-error(400, "Bad content type")
    default return $local:disallowed
  else
    switch (api:get-method())
    case "GET"
    return 
      if ($tokens[4]="groups")
      then grp:get-user-groups($tokens[3])
      else user:get($tokens[3])
    case "PUT"
    return user:put($tokens[3], request:get-data())
    case "DELETE"
    return user:delete($tokens[3])
    default return $local:disallowed
};

let $path-tokens := tokenize($exist:path, "/")[.]
let $which-api := $path-tokens[2]
let $authenticated := 
  (: log in if you can, otherwise, let the access be checked
   : by the called function 
   :)
  api:request-authentication()
let $null := 
  debug:debug($debug:info, "api", string-join(
    for $token at $n in $path-tokens
    return concat($n, ":", $token), ","))
return
  if ($path-tokens[1] = "api")
  then
    api:rest-response(
      if (not($which-api))
      then local:do-index($path-tokens)
      else
        switch($which-api)
        case "data"
        return local:do-data($path-tokens)
        case "demo"
        return local:do-demo($path-tokens)
        case "group"
        return local:do-group($path-tokens)
        case "login"
        return local:do-login($path-tokens)
        case "logout"
        return local:do-logout($path-tokens)
        case "user"
        return local:do-user($path-tokens)
        default 
        return
          <exist:ignore/>
    )
  else <exist:ignore/>