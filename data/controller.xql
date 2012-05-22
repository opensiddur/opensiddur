xquery version "3.0";
(: This controller behaves like a fill-in for RESTXQ.
 : It does not do content negotiation.
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace api="http://jewishliturgy.org/modules/api"
  at "xmldb:exist:///code/api/modules/api.xqm";
import module namespace dindex="http://jewishliturgy.org/api/data/index"
  at "xmldb:exist:///code/api/data/dindex.xqm";

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
        if ($exist:resource="OpenSearchDescription")
        then
          dindex:open-search(request:get-parameter("source", ""))
        else
          dindex:list()
      default
      return api:rest-error(405, "Method not allowed")
    )