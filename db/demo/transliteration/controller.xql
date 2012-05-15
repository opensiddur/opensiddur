xquery version "3.0";
(: This controller behaves like a fill-in for RESTXQ.
 : It does only minimal content negotiation.
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace api="http://jewishliturgy.org/modules/api"
  at "xmldb:exist:///code/api/modules/api.xqm";
import module namespace demo="http://jewishliturgy.org/api/demo"
  at "xmldb:exist:///code/api/demo.xqm";

declare namespace exist="http://exist.sourceforge.net/NS/exist";

declare variable $exist:path external;
declare variable $exist:resource external;

let $uri := request:get-uri()
let $authenticated := 
  (: log in if you can, otherwise, let the access be checked
   : by the called function 
   :)
  api:request-authentication()
return
  api:rest-response(
    switch (api:get-method())
      case "GET"
      return
        <html>
          <head><title>Placeholder</title></head>
          <body>Placeholder for discovery API!</body>
        </html>
      case "POST"
      return 
        if ($exist:resource)
        then
          switch (
            api:simplify-format(
              api:get-request-format(
                ("text/plain", "application/xml", "text/xml")
              ), "txt"
            )
          )
          case "txt"
          return 
            demo:transliterate-text(
              util:binary-to-string(request:get-data()), 
              $exist:resource
            )
          case "xml"
          return (
            demo:transliterate-xml(
              request:get-data(), $exist:resource)
          )
          default
          return api:rest-error(400, "Content-Type not allowed")
        else
          api:rest-error(405, "Method not allowed")
      default
      return api:rest-error(405, "Method not allowed")
    )