(:~
 : XQuery functions to output a given XML file in a format.
 : 
 : Copyright 2011-2013 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace format="http://jewishliturgy.org/modules/format";

declare namespace exist="http://exist.sourceforge.net/NS/exist";
declare namespace error="http://jewishliturgy.org/errors";
declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";

import module namespace app="http://jewishliturgy.org/modules/app" 
  at "xmldb:exist:///db/code/modules/app.xqm";
import module namespace mirror="http://jewishliturgy.org/modules/mirror" 
  at "xmldb:exist:///db/code/modules/mirror.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths" 
  at "xmldb:exist:///db/code/modules/paths.xqm";

import module namespace flatten="http://jewishliturgy.org/transform/flatten"
  at "xmldb:exist:///db/code/transforms/flatten/flatten.xqm";
import module namespace unflatten="http://jewishliturgy.org/transform/unflatten"
  at "xmldb:exist:///db/code/transforms/flatten/unflatten.xqm";
  
declare variable $format:temp-dir := '.format';
declare variable $format:path-to-xslt := '/db/code/transforms';
declare variable $format:rest-path-to-xslt := app:concat-path($paths:internal-rest-prefix, $format:path-to-xslt);

declare variable $format:flatten-cache := "/db/cache/flatten";
declare variable $format:merge-cache := "/db/cache/merge";
declare variable $format:resolve-cache := "/db/cache/resolved";
declare variable $format:unflatten-cache := "/db/cache/unflattened";

declare function local:wrap-document(
  $node as node()
  ) as document-node() {
  if ($node instance of document-node())
  then $node
  else document {$node}
};


(:~ setup to allow format functions to work :)
declare function format:setup(
  ) as empty-sequence() {
  for $collection in (
    $format:flatten-cache,
    $format:merge-cache,
    $format:resolve-cache,
    $format:unflatten-cache
    )
  where not(xmldb:collection-available($collection))
  return
    mirror:create($collection, "/db/data", true())
};

(:~ make a cached version of a flattened document,
 : and return it
 : @param $doc The document to flatten
 : @param $params Parameters to send to the transform
 : @param $original-doc The original document that was flattened, if not $doc 
 : @return The mirrored flattened document
 :) 
declare function format:flatten(
  $doc as document-node(),
  $params as map,
  $original-doc as document-node()
  ) as document-node() {
  let $flatten-transform := flatten:flatten-document(?, $params)
  return
    mirror:apply-if-outdated(
      $format:flatten-cache,
      $doc,
      $flatten-transform,
      $original-doc
    )
};

(:~ perform the transform up to the merge step 
 : @param $doc Original document
 : @param $params Parameters to pass to the transforms
 : @param $original-doc The original document that was merged, if not $doc 
 : @return The merged document (as an in-database copy)
 :)
declare function format:merge(
  $doc as document-node(),
  $params as map,
  $original-doc as document-node()
  ) as document-node() {
  let $merge-transform := flatten:merge-document(?, $params)
  return
    mirror:apply-if-outdated(
      $format:merge-cache,
      format:flatten($doc, $params, $original-doc),
      $merge-transform,
      $original-doc
    )
};

(:~ perform the transform up to the resolve-stream step 
 : @param $doc Original document
 : @param $params Parameters to pass to the transforms
 : @param $original-doc The original document that was resolved, if not $doc 
 : @return The merged document (as an in-database copy)
 :)
declare function format:resolve(
  $doc as document-node(),
  $params as map,
  $original-doc as document-node()
  ) as document-node() {
  let $resolve-transform := flatten:resolve-stream(?, $params)
  return
    mirror:apply-if-outdated(
      $format:resolve-cache,
      format:merge($doc, $params, $original-doc),
      $resolve-transform,
      $original-doc
    )
};

(:~ provide a display version of the flattened/merged hierachies  
 :)
declare function format:display-flat(
  $doc as document-node(),
  $params as map,
  $original-doc as document-node()
  ) as document-node() {
  flatten:display(
    format:resolve($doc, $params, $original-doc),
    $params
  )
};

(:~ perform the transform up to the unflatten step 
 : @param $doc Original document
 : @param $params Parameters to pass to the transforms
 : @param $original-doc The original document that was unflattened, if not $doc 
 : @return The unflattened document (as an in-database copy)
 :)
declare function format:unflatten(
  $doc as document-node(),
  $params as map,
  $original-doc as document-node()?
  ) as document-node() {
  let $unflatten-transform := unflatten:unflatten-document(?, $params)
  return
    mirror:apply-if-outdated(
      $format:unflatten-cache,
      format:resolve($doc, $params, $original-doc),
      $unflatten-transform,
      ($original-doc, $doc)[1]
    )
};
declare function format:transliterate(
  $uri-or-node as item(),
  $user as xs:string?,
  $password as xs:string?
  ) as document-node() {
  local:wrap-document(
    app:transform-xslt($uri-or-node, 
      app:concat-path($format:rest-path-to-xslt, 'translit/translit-main.xsl2'),
      (
        if ($user)
        then (
          <param name="user" value="{$user}"/>,
          <param name="password" value="{$password}"/>
        )
        else (), 
        <param name="transliteration-tables" value="{
          string-join(
            collection("/data/transliteration")/tr:schema/document-uri(root(.)),
            " ")
        }"/>
      ), ()
    )
  )
};

