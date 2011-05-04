xquery version "1.0";
(: api logout action
 :
 : Method: GET
 : Result: 204 no content
 : 
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 : $Id: logout.xql 714 2011-03-13 21:56:57Z efraim.feinstein $
 :)
import module namespace session="http://exist-db.org/xquery/session";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";


declare namespace err="http://jewishliturgy.org/errors";

if (api:allowed-method(('GET', 'POST')))
then (
  	app:logout-credentials(),
    response:set-status-code(204)
)
else ()

