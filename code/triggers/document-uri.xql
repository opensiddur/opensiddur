xquery version "1.0";

(:
	This trigger should run on document creation and update events.

  It adds @jx:document-uri to the root element iff it is tei:TEI, otherwise pass the file through unchanged.
  $exempt-collections excludes collections that end with that name from the trigger

  Also, add .updated.xml to the collection, indicating the time of the update

  Copyright 2010-2011 Efraim Feinstein
  Open Siddur Project
  Licensed under the GNU Lesser General Public License, version 3 or later

  $Id: document-uri.xql 741 2011-04-17 04:30:40Z efraim.feinstein $
:)
module namespace trigger='http://exist-db.org/xquery/trigger';

import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";

(: exempt certain collections and sub-collections from document-uri triggering :)
declare function trigger:is-exempt(
  $uri as xs:anyURI)
  as xs:boolean {
  let $exempt-collections := ('cache', 'tests', 'test', 'updated.xml')
  let $collections := tokenize($uri,'/')
  return $collections = $exempt-collections
};

declare function trigger:log-trigger-event($uri as xs:anyURI, $event as xs:string) {
  util:log-system-out(('TRIGGER: document-uri.xql called: ', $event, ' on ', $uri))
};

declare function trigger:write-update-record($uri as xs:anyURI) {
  let $collection := util:collection-name(string($uri))
  return
    if (xmldb:store($collection, 'updated.xml', 
      <updated xmlns="">{current-dateTime()}</updated>))
    then ()
    else 
      util:log-system-out(('Error storing collection update record for ', $collection))

};

declare function trigger:write-document-uri($uri as xs:anyURI) {
  (: WARNING: these must be changed if the server/port won't be accessible locally this way! :)
  if (not(util:is-binary-doc($uri)) and doc-available($uri) and not(trigger:is-exempt($uri)))
  then
    (: the document is an XML document and it exists :)
    let $server := 'localhost'
    let $port := 8080
    let $root := doc($uri)
    let $TEI := $root/tei:TEI
    let $full-uri := (:concat('http://', $server, ':', $port, document-uri($root)):)
     (: concat('xmldb:exist://', document-uri($root)) :)
      document-uri($root)
    return
      if (exists($TEI))
      then (
        (: write @jx:document-uri :)
        if (not($TEI/@jx:document-uri = $full-uri)) 
        then update insert attribute {'jx:document-uri'}{$full-uri} into $TEI
        else (),
        (: write @xml:base :)
        if (not($TEI/@xml:base = $full-uri))
        then update insert attribute {'xml:base'}{$full-uri} into $TEI
        else (),
        trigger:write-update-record($uri)
      )
      else ()
  else ()
};

declare function trigger:after-create-document($uri as xs:anyURI) {
  trigger:write-document-uri($uri),
  trigger:log-trigger-event($uri, 'create')
};

declare function trigger:after-update-document($uri as xs:anyURI) {
  trigger:write-document-uri($uri),
  trigger:log-trigger-event($uri, 'update')
};

declare function trigger:after-copy-document($new-uri as xs:anyURI, $uri as xs:anyURI) {
  trigger:log-trigger-event($new-uri, concat('copy 1 from ', string($uri))),
  trigger:write-document-uri($new-uri),
  trigger:log-trigger-event($new-uri, 'copy 2')
};

declare function trigger:after-move-document($new-uri as xs:anyURI, $uri as xs:anyURI) {
  trigger:write-document-uri($new-uri),
  trigger:log-trigger-event($new-uri, 'move')
};

declare function trigger:after-delete-document($uri as xs:anyURI) {
  trigger:write-update-record($uri)
};

