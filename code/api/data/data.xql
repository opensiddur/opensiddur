xquery version "1.0";
(: api to check for user existence or list available profile resources
 : 
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
import module namespace response="http://exist-db.org/xquery/response";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace dindex="http://jewishliturgy.org/api/data"
	at "data.xqm";

dindex:go()