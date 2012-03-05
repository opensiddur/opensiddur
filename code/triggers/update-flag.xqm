xquery version "1.0";

(:
	Add updated.xml to a collection, indicating the time of the update

  Copyright 2010-2011 Efraim Feinstein
  Open Siddur Project
  Licensed under the GNU Lesser General Public License, version 3 or later
:)
module namespace trigger='http://jewishliturgy.org/triggers/update';

import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";

(: exempt certain collections and sub-collections from document-uri triggering :)
declare function trigger:is-exempt(
  $uri as xs:anyURI)
  as xs:boolean {
  let $exempt-collections := ('tests', 'test', 'updated.xml')
  let $collections := tokenize($uri,'/')
  return $collections = $exempt-collections or
    util:is-binary-doc($uri) or
    not(doc-available($uri))
};


declare function trigger:log-trigger-event($uri as xs:anyURI, $event as xs:string) {
  util:log-system-out(('TRIGGER: collection update record called: ', $event, ' on ', $uri))
};

declare function trigger:write-update-record($uri as xs:anyURI) {
  if (not(trigger:is-exempt($uri)))
  then
    (: the document is an XML document and it exists :)
    let $root := doc($uri)
    let $collection := util:collection-name(string($uri))
    where exists($root/tei:TEI)
    return
      if (xmldb:store($collection, 'updated.xml', 
        <updated xmlns="">{current-dateTime()}</updated>))
      then ()
      else 
        util:log-system-out(('Error storing collection update record for ', $collection))
  else ()
};

declare function trigger:after-create-document($uri as xs:anyURI) {
  trigger:write-update-record($uri),
  trigger:log-trigger-event($uri, 'create')
};

declare function trigger:after-update-document($uri as xs:anyURI) {
  trigger:write-update-record($uri),
  trigger:log-trigger-event($uri, 'update')
};

declare function trigger:after-copy-document($new-uri as xs:anyURI, $uri as xs:anyURI) {
  trigger:log-trigger-event($new-uri, concat('copy 1 from ', string($uri))),
  trigger:write-update-record($new-uri),
  trigger:log-trigger-event($new-uri, 'copy 2')
};

declare function trigger:after-move-document($new-uri as xs:anyURI, $uri as xs:anyURI) {
  trigger:write-update-record($new-uri),
  trigger:log-trigger-event($new-uri, 'move')
};

declare function trigger:after-delete-document($uri as xs:anyURI) {
  trigger:write-update-record($uri)
};

