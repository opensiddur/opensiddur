(: Unit test code for the jupdate:prepare-update()
 : followed by a canceled update.
 : Should be run in the context of /db/tests/contributors.xml
 : Copyright 2009 Efraim Feinstein
 : Licensed under the GNU Lesser GPL version 3 or later
 :
 : $Id: test_jupdate_prepare.xql 411 2010-01-03 06:58:09Z efraim.feinstein $
 :)
xquery version "1.0";
import module namespace
  util="http://exist-db.org/xquery/util";
import module namespace 
  jupdate="http://jewishliturgy.org/ns/functions/nonportable/update"
  at "xmldb:exist:///db/queries/jupdate.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

let $item-to-update := //id('toby.prepared')/tei:surname
let $temp-item := jupdate:prepare-update($item-to-update)
let $new-root := root($temp-item)
return
  <tests>
    <to-update>{$item-to-update}</to-update>
    <doc>{document-uri($new-root)}</doc>
    <collection>{util:collection-name($new-root)}</collection>
    <name>{util:document-name($new-root)}</name>
    <path>{jupdate:numerical-path($temp-item)}</path>
    <uri>{jupdate:make-uri($temp-item)}</uri>
    <data>{jupdate:retrieve-node(jupdate:make-uri($temp-item))}</data>
  </tests>