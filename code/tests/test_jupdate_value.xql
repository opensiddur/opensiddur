(: Unit test code for setting the value of an item in the database.
 : Should be run in the context of /db/tests/contributors.xml
 : Copyright 2009 Efraim Feinstein
 : Licensed under the GNU Lesser GPL version 3 or later
 :
 : $Id: test_jupdate_value.xql 411 2010-01-03 06:58:09Z efraim.feinstein $
 :)
xquery version "1.0";
import module namespace 
    jupdate="http://jewishliturgy.org/ns/functions/nonportable/update"
    at "xmldb:exist:///db/queries/jupdate.xqm";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare variable $replacedValueWith := "ianalso@replac.edu";
declare variable $toReplace := 
    //id('toby.replaced')/tei:email;

<a>{jupdate:value($toReplace, $replacedValueWith)}</a>