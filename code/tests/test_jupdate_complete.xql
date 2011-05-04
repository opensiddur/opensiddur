(: Unit test code for the jupdate:cancel-update()
 : %XPATH% must be replaced with the path to a node 
 : prepared by prepare-update()
 :
 : Copyright 2009 Efraim Feinstein
 : Licensed under the GNU Lesser GPL version 3 or later
 :
 : $Id: test_jupdate_complete.xql 411 2010-01-03 06:58:09Z efraim.feinstein $
 :)
xquery version "1.0";

import module namespace 
  jupdate="http://jewishliturgy.org/ns/functions/nonportable/update"
  at "xmldb:exist:///db/queries/jupdate.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";


let $node-to-update := jupdate:retrieve-node('%XPATH%' cast as xs:anyURI)
return
  (jupdate:value($node-to-update, 'Prepared'),
  jupdate:complete-update($node-to-update))