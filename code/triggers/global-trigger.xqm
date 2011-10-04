xquery version "1.0";
(:~ global trigger executive
 : TODO: ideally, each would be a separate trigger, but eXist seems
 : to have a bug where it will not run more than one trigger at a time
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Released under the GNU Lesser General Public License version 3 or later
 :)
module namespace trigger = 'http://exist-db.org/xquery/trigger';

import module namespace refindex="http://jewishliturgy.org/triggers/refindex"
  at "xmldb:exist:///code/triggers/refindex-trigger.xqm";
import module namespace updateflag="http://jewishliturgy.org/triggers/update"
  at "xmldb:exist:///code/triggers/update-flag.xqm";
import module namespace docuri="http://jewishliturgy.org/triggers/document-uri"
  at "xmldb:exist:///code/triggers/document-uri.xqm";

(: enable the triggers individually by collection 
 : pass in 0 or "" for disabled, anything else for enabled
 :)
declare variable $local:document-uri external;
declare variable $local:update-record external;
declare variable $local:reference-index external;

declare function trigger:after-copy-collection(
  $new-uri as xs:anyURI, 
  $uri as xs:anyURI
  ) {
  if ($local:reference-index)
  then refindex:after-copy-collection($new-uri, $uri)
  else ()
};
 
declare function trigger:after-move-collection(
  $new-uri as xs:anyURI, 
  $uri as xs:anyURI
  ) {
  if ($local:reference-index)
  then refindex:after-move-collection($new-uri, $uri)
  else ()
};

declare function trigger:before-delete-collection(
  $uri as xs:anyURI
  ) {
  if ($local:reference-index)
  then refindex:before-delete-collection($uri)
  else ()
};

declare function trigger:after-create-document(
  $uri as xs:anyURI
  ) {
  if ($local:update-record)
  then updateflag:after-create-document($uri)
  else (),
  if ($local:document-uri)
  then docuri:after-create-document($uri)
  else (),
  if ($local:reference-index)
  then refindex:after-create-document($uri)
  else ()
};

declare function trigger:after-update-document(
  $uri as xs:anyURI
  ) {
  if ($local:update-record)
  then updateflag:after-update-document($uri)
  else (),
  if ($local:document-uri)
  then docuri:after-update-document($uri)
  else (),
  if ($local:reference-index)
  then refindex:after-update-document($uri)
  else ()
};

declare function trigger:after-copy-document(
  $new-uri as xs:anyURI, 
  $uri as xs:anyURI
  ) {
  if ($local:update-record)
  then updateflag:after-copy-document($new-uri, $uri)
  else (),
  if ($local:document-uri)
  then docuri:after-copy-document($new-uri, $uri)
  else (),
  if ($local:reference-index)
  then refindex:after-copy-document($new-uri, $uri)
  else ()
};

declare function trigger:after-move-document(
  $new-uri as xs:anyURI, 
  $uri as xs:anyURI
  ) {
  if ($local:update-record)
  then updateflag:after-move-document($new-uri, $uri)
  else (),
  if ($local:document-uri)
  then docuri:after-move-document($new-uri, $uri)
  else (),
  if ($local:reference-index)
  then refindex:after-move-document($new-uri, $uri)
  else ()
};

declare function trigger:before-delete-document(
  $uri as xs:anyURI
  ) {
  if ($local:reference-index)
  then refindex:before-delete-document($uri)
  else ()
};

declare function trigger:after-delete-document(
  $uri as xs:anyURI
  ) {
  if ($local:update-record)
  then updateflag:after-delete-document($uri)
  else ()
};