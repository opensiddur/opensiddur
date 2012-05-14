xquery version "3.0";
(: This controller behaves like a fill-in for RESTXQ.
 : It does not do content negotiation.
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace api="http://jewishliturgy.org/modules/api"
  at "xmldb:exist:///code/api/modules/api.xqm";
import module namespace tran="http://jewishliturgy.org/api/transliteration"
  at "xmldb:exist:///code/api/data/transliteration.xqm";

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
        if ($exist:resource)
        then
          tran:get($exist:resource)
        else
          let $query := request:get-parameter("q", "")
          let $start := request:get-parameter("start", 1)
          let $max-results := request:get-parameter("max-results", 100)
          return
            tran:list($query, $start, $max-results)
      case "PUT"
      return tran:put($exist:resource, request:get-data())
      case "POST"
      return tran:post($exist:resource, request:get-data())
      case "DELETE"
      return tran:delete($exist:resource)
      default
      return api:rest-error(405, "Method not allowed")
    )