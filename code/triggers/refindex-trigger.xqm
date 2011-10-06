xquery version "1.0";
(:~ trigger functions for the reference index
 : should be called from the main trigger
 : TODO: ideally, this would be a separate trigger, but eXist seems
 : to have a bug where it will not run more than one trigger at a time
 :
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Released under the GNU Lesser General Public License version 3 or later
 :)
module namespace trigger = 'http://jewishliturgy.org/triggers/refindex';

import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "xmldb:exist:///code/modules/refindex.xqm";

(: namespaces of the root element that the trigger will work on :)
declare variable $trigger:namespaces := 
  ("http://www.tei-c.org/ns/1.0", "http://jewishliturgy.org/ns/jlptei/1.0");

declare function local:is-exempt(
  $uri as xs:anyURI
  ) as xs:boolean {
  util:is-binary-doc($uri) or not(doc-available($uri)) 
    or empty(doc($uri)/*[namespace-uri(.)=$trigger:namespaces])
};

declare function trigger:after-copy-collection(
  $new-uri as xs:anyURI, 
  $uri as xs:anyURI
  ) {
  ridx:reindex(collection($new-uri))
};
 
declare function trigger:after-move-collection(
  $new-uri as xs:anyURI, 
  $uri as xs:anyURI
  ) {
  ridx:reindex(collection($new-uri)),
  xmldb:remove(ridx:index-collection($uri))
};

declare function trigger:before-delete-collection(
  $uri as xs:anyURI
  ) {
  xmldb:remove(ridx:index-collection($uri))
};

declare function trigger:after-create-document(
  $uri as xs:anyURI
  ) {
  if (not(local:is-exempt($uri)))
  then ridx:reindex($uri)
  else ()
};

declare function trigger:after-update-document(
  $uri as xs:anyURI
  ) {
  if (not(local:is-exempt($uri)))
  then ridx:reindex($uri)
  else ()
};

declare function trigger:after-copy-document(
  $new-uri as xs:anyURI, 
  $uri as xs:anyURI
  ) {
  if (not(local:is-exempt($new-uri)))
  then
    ridx:reindex($new-uri)
  else ()
};

declare function trigger:after-move-document(
  $new-uri as xs:anyURI, 
  $uri as xs:anyURI
  ) {
  let $tokens := tokenize($new-uri, "/")[.]
  let $old-resource := $tokens[last()]
  let $old-collection := 
    ridx:index-collection(
      string-join(subsequence($tokens, 1, count($tokens) - 1), "/")
    )
  where not(local:is-exempt($new-uri))
  return (
    xmldb:remove($old-collection, $old-resource),
    ridx:reindex($uri)
  )
};

declare function trigger:before-delete-document(
  $uri as xs:anyURI
  ) {
  if (not(local:is-exempt($uri)))
  then 
    let $doc := doc($uri)
    let $collection := ridx:index-collection(util:collection-name($doc))
    let $resource := util:document-name($doc)
    return xmldb:remove($collection, $resource)
  else ()
};