xquery version "1.0";
(: original text data api controller.
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
	at "/code/api/modules/data.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
	at "/code/modules/debug.xqm";
import module namespace nav="http://jewishliturgy.org/modules/nav"
	at "/code/api/modules/nav.xqm";
	
declare namespace exist="http://exist.sourceforge.net/NS/exist";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

(: queries that handle specific subresources :)
declare variable $local:query-base := concat($exist:controller, '/../queries');

debug:debug($debug:info,
  "/api/data/original",
	<debug from="data/original api controller">
		<user>{app:auth-user()}:{app:auth-password()}</user>
	  <uri>{request:get-uri()}</uri>
	  <path>{$exist:path}</path>
	  <root>{$exist:root}</root>
	  <controller>{$exist:controller}</controller>
	  <prefix>{$exist:prefix}</prefix>
	  <resource>{$exist:resource}</resource>
	</debug>
	),
  element exist:dispatch {
    app:pass-credentials-xq(),
    element exist:forward {
      attribute url { concat($local:query-base, "/nav.xql") }
    }
  }
