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
 :)

import module namespace logout="http://jewishliturgy.org/api/user/logout"
	at "logout.xqm";

declare namespace err="http://jewishliturgy.org/errors";

logout:go()
