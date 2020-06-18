xquery version "3.1";
(:~
 : XQuery functions to output a given XML file in a format.
 : 
 : Copyright 2011-2014,2019 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace format="http://jewishliturgy.org/modules/format";

declare namespace exist="http://exist.sourceforge.net/NS/exist";
declare namespace error="http://jewishliturgy.org/errors";
declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";

import module namespace data="http://jewishliturgy.org/modules/data" 
  at "data.xqm";
import module namespace mirror="http://jewishliturgy.org/modules/mirror" 
  at "mirror.xqm";
import module namespace status="http://jewishliturgy.org/modules/status" 
  at "status.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri" 
  at "follow-uri.xqm";
import module namespace pla="http://jewishliturgy.org/transform/parallel-layer"
  at "../transforms/parallel-layer.xqm";
import module namespace phony="http://jewishliturgy.org/transform/phony-layer"
  at "../transforms/phony-layer.xqm";
import module namespace flatten="http://jewishliturgy.org/transform/flatten"
  at "../transforms/flatten.xqm";
import module namespace unflatten="http://jewishliturgy.org/transform/unflatten"
  at "../transforms/unflatten.xqm";
import module namespace combine="http://jewishliturgy.org/transform/combine"
  at "../transforms/combine.xqm";
import module namespace compile="http://jewishliturgy.org/transform/compile"
  at "../transforms/compile.xqm";
import module namespace segment="http://jewishliturgy.org/transform/segment"
at "../transforms/segment.xqm";
import module namespace tohtml="http://jewishliturgy.org/transform/html"
  at "../transforms/tohtml.xqm";
import module namespace translit="http://jewishliturgy.org/transform/transliterator"
  at "../transforms/translit/translit.xqm";
import module namespace reverse="http://jewishliturgy.org/transform/reverse"
  at "../transforms/reverse.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";
declare namespace http="http://expath.org/ns/http-client";

declare variable $format:temp-dir := '.format';

declare variable $format:parallel-layer-cache := "/db/cache/parallel-layer";
declare variable $format:phony-layer-cache := "/db/cache/phony-layer";
declare variable $format:dependency-cache := "/db/cache/dependency";
declare variable $format:segment-cache := "/db/cache/segment";
declare variable $format:flatten-cache := "/db/cache/flatten";
declare variable $format:merge-cache := "/db/cache/merge";
declare variable $format:resolve-cache := "/db/cache/resolved";
declare variable $format:unflatten-cache := "/db/cache/unflattened";
declare variable $format:combine-cache := "/db/cache/combined";
declare variable $format:compile-cache := "/db/cache/compiled";
declare variable $format:html-cache := "/db/cache/html";
declare variable $format:caches := (
    $format:parallel-layer-cache,
    $format:phony-layer-cache,
    $format:dependency-cache,
    $format:segment-cache,
    $format:flatten-cache,
    $format:merge-cache,
    $format:resolve-cache,
    $format:unflatten-cache,
    $format:combine-cache,
    $format:compile-cache,
    $format:html-cache
    );

(:~ setup to allow format functions to work :)
declare function format:setup(
  ) as empty-sequence() {
  for $collection in $format:caches
  where not(xmldb:collection-available($collection))
  return
    mirror:create($collection, "/db/data", true(),
      if ($collection = $format:html-cache)
      then map { "xml" : "html" }
      else map {}
    ),
  status:setup()
};

(:~ clear all format caches of a single file 
 : @param $path database path of the original resource
 :)
declare function format:clear-caches(
  $path as xs:string
  ) as empty-sequence() {
  for $cache in $format:caches
  where doc-available($path)
  return 
    let $doc := doc($path)
    return
      mirror:remove($cache, util:collection-name($doc), util:document-name($doc))
};

(:~ add a format:status-job-id parameter pointing to the job where status should be updated
 : should be updated and format:stage-number to $params if they do not already exist  :)
declare function format:status-param(
    $params as map(*),
    $original-doc as document-node()
    ) as map(*) {
  map:merge((
      $params,
      map {
          "format:status-job-id" : ($params("format:status-job-id"), status:get-job-id($original-doc))[1],
          "format:stage-number" : ($params("format:stage-number") + 1, 0)[1]
      }
  ))
};

declare function format:apply-if-outdated(
    $stage as xs:string,
    $params as map(*),
    $mirror-path as xs:string,
    $transformee as item(),
    $transform as function(node()*) as node()*,
    $original-doc as document-node()
    ) as document-node()? {
    format:apply-if-outdated($stage, $params, $mirror-path, $transformee, $transform, $original-doc, ())
};

declare function format:apply-if-outdated(
    $stage as xs:string,
    $params as map(*),
    $mirror-path as xs:string,
    $transformee as item(),
    $transform as function(node()*) as node()*,
    $original-doc as document-node(),
    $up-to-date-function as (function(xs:string, item()) as xs:boolean)?
    ) as document-node()? {
    let $status-resource := ($params("format:status-job-id"), status:get-job-id($original-doc))[1]
    let $is-first := 
        (: if the status document does not exist, it should be created :)
        let $sd := status:doc($status-resource)
        return empty($sd) or exists($sd/*/@status:completed)
    let $job-start :=
        if ($is-first)
        then status:start-job($original-doc)
        else ()
    return
      try {
            let $stage-start := status:start($status-resource, $original-doc, $stage)
            let $transformed :=
              mirror:apply-if-outdated($mirror-path, $transformee, $transform, $original-doc, $up-to-date-function)
            let $stage-finish := status:finish($status-resource, $original-doc, $stage)
            let $job-end := 
                if ($params("format:stage-number") = 0)
                then status:complete-job($status-resource, document-uri($original-doc))
                else ()
            return $transformed
       }
        catch * {
            let $error-message := 
                concat(
                    $err:module, ":", $err:line-number, ":", $err:column-number, 
                    ":"[$err:value], $err:value, 
                    ": "[$err:description], $err:description
                )
            return (
                status:fail-job($status-resource, $original-doc, $stage, $error-message),
                error($err:code, $error-message)    (: rethrow the exception :)
            )
        }
};

(:~ @return true() if the document requires special processing for parallel documents :)
declare function format:is-parallel-document(
    $doc as document-node()
    ) as xs:boolean {
    exists($doc//j:parallelText)
};

(:~ make a cached version of a parallel text document,
 : and return it
 : @param $doc The document to run parallel text transform on
 : @param $params Parameters to send to the transform
 : @param $original-doc The original document  
 : @return The mirrored parallel text document
 :) 
declare function format:parallel-layer(
  $doc as document-node(),
  $params as map(*),
  $original-doc as document-node()
  ) as document-node() {
  let $params := format:status-param($params, $original-doc)
  let $pla-transform := pla:parallel-layer-document(?, $params)
  return
    format:apply-if-outdated(
      "parallel-layer",
      $params,
      $format:parallel-layer-cache,
      $doc,
      $pla-transform,
      $original-doc
    )
};


(:~ make a cached version of a phony layer text document,
 : and return it
 : @param $doc The document to run phony layer transform on
 : @param $params Parameters to send to the transform
 : @param $original-doc The original document  
 : @return The mirrored phony layer document
 :) 
declare function format:phony-layer(
  $doc as document-node(),
  $params as map(*),
  $original-doc as document-node()
  ) as document-node() {
  let $params := format:status-param($params, $original-doc)
  let $pho-transform := phony:phony-layer-document(?, $params)
  return
    format:apply-if-outdated(
      "phony-layer",
      $params,
      $format:phony-layer-cache,
      $doc,
      $pho-transform,
      $original-doc
    )
};


(:~ make a cached version of a segmented document,
 : and return it
 : @param $doc The document to segment
 : @param $params Parameters to send to the segment
 : @param $original-doc The original document that was segmented
 : @return The mirrored segmented document
 :)
declare function format:segment(
  $doc as document-node(),
  $params as map(*),
  $original-doc as document-node()
) as document-node() {
  let $params := format:status-param($params, $original-doc)
  let $segment-transform := segment:segment(?)
  return
    format:apply-if-outdated(
      "segment",
      $params,
      $format:segment-cache,
      format:phony-layer($doc, $params, $original-doc),
      $segment-transform,
      $original-doc
    )
};

(:~ make a cached version of a flattened document,
 : and return it
 : @param $doc The document to flatten
 : @param $params Parameters to send to the transform
 : @param $original-doc The original document that was flattened 
 : @return The mirrored flattened document
 :) 
declare function format:flatten(
  $doc as document-node(),
  $params as map(*),
  $original-doc as document-node()
  ) as document-node() {
  let $params := format:status-param($params, $original-doc)
  return
    format:apply-if-outdated(
      "flatten", 
      $params, 
      $format:flatten-cache,
      if (format:is-parallel-document($original-doc))
      then
        format:parallel-layer($doc, $params, $original-doc)
      else
        format:segment($doc, $params, $original-doc),
      flatten:flatten-document(?, $params),
      $original-doc
    )
};

(:~ perform the transform up to the merge step 
 : @param $doc Original document
 : @param $params Parameters to pass to the transforms
 : @param $original-doc The original document that was merged 
 : @return The merged document (as an in-database copy)
 :)
declare function format:merge(
  $doc as document-node(),
  $params as map(*),
  $original-doc as document-node()
  ) as document-node() {
  let $params := format:status-param($params, $original-doc)
  let $merge-transform := flatten:merge-document(?, $params)
  return
    format:apply-if-outdated(
      "merge",
      $params,
      $format:merge-cache,
      format:flatten($doc, $params, $original-doc),
      $merge-transform,
      $original-doc
    )
};

(:~ perform the transform up to the resolve-stream step 
 : @param $doc Original document
 : @param $params Parameters to pass to the transforms
 : @param $original-doc The original document that was resolved 
 : @return The merged document (as an in-database copy)
 :)
declare function format:resolve(
  $doc as document-node(),
  $params as map(*),
  $original-doc as document-node()
  ) as document-node() {
  let $params := format:status-param($params, $original-doc)
  let $resolve-transform := flatten:resolve-stream(?, $params)
  return
    format:apply-if-outdated(
      "resolve",
      $params,
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
  $params as map(*),
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
  $params as map(*),
  $original-doc as document-node()
  ) as document-node() {
  let $params := format:status-param($params, $original-doc)
  let $unflatten-transform := unflatten:unflatten-document(?, $params)
  return
    format:apply-if-outdated(
      "unflatten",
      $params,
      $format:unflatten-cache,
      format:resolve($doc, $params, $original-doc),
      $unflatten-transform,
      $original-doc
    )
};

declare function format:dependency-is-transformable(
    $dep-uri as xs:string
    ) as xs:boolean {
    (: TODO: add other transformables here... :)
    matches($dep-uri, "^/db/data/(linkage|notes|original|tests)")
};

declare function format:get-dependencies(
  $doc as document-node()
  ) as document-node() {
  document {
    <format:dependencies>{
      for $dep in uri:dependency($doc, ())
      let $transformable := format:dependency-is-transformable($dep)
      return 
        <format:dependency>{
          if ($transformable)
          then attribute transformable { $transformable }
          else (),
          $dep
        }</format:dependency>
    }</format:dependencies>
  }
};

(:~ set up an XML file containing all dependencies 
 : of a given document
 :)
declare function format:dependencies(
  $doc as document-node(),
  $params as map(*)
  ) as document-node() {
  let $params := format:status-param($params, $doc)
  return
    format:apply-if-outdated(
      "dependencies",
      $params,
      $format:dependency-cache,
      $doc,
      format:get-dependencies#1,
      $doc
    )
};

(:~ unflatten all transformable dependencies of a given document :)
declare function format:unflatten-dependencies(
  $doc as document-node(),
  $params as map(*)
  ) as document-node()* {
  for $dep in format:dependencies($doc, $params)//format:dependency[@transformable]
  return format:unflatten(doc($dep), $params, doc($dep))
};

(:~ flatten all transformable dependencies of a given document, excluding itself :)
declare function format:flatten-external-dependencies(
  $doc as document-node(),
  $params as map(*)
  ) as document-node()+ {
  for $dep in format:dependencies($doc, $params)//format:dependency[@transformable]
  let $dep-doc := doc($dep)
  where not($dep-doc is $doc)
  return format:flatten($dep-doc, $params, $dep-doc)
};

(:~ combine may have dependencies on translations as well as directly referenced documents 
 : fortunately, if a combine cached document exists, it already references all of its dependencies
 :)
declare function format:combine-dependencies-up-to-date(
    $mirror-path as xs:string,
    $original as item()
    ) as xs:boolean {
    let $combine-mirrored :=
      mirror:doc($mirror-path, 
          typeswitch($original)
          case document-node() return document-uri($original)
          default return $original
      )
    let $dependencies := 
        distinct-values((
                        $combine-mirrored//@jf:document/string(), 
                        $combine-mirrored//@jf:linkage-document/string()
        ))
    return
        every $dependency in $dependencies
        satisfies 
            let $path := data:api-path-to-db($dependency)
            let $up-to-date-relative :=
                  (: check if the dependency has changed since 
                   : the combined document was cached :) 
                  let $collection := util:collection-name($path)
                  let $resource := util:document-name($path)
                  let $mirror-collection := util:collection-name($combine-mirrored)
                  let $mirror-resource := util:document-name($combine-mirrored)
                  let $last-modified := 
                      try {
                          xmldb:last-modified($collection, $resource)
                      }
                      catch * { () }
                  let $mirror-last-modified := 
                      try {
                          xmldb:last-modified($mirror-collection, $mirror-resource)
                      }
                      catch * { () } 
                  return
                      not(
                          empty($last-modified) or 
                          empty($mirror-last-modified) or 
                          ($last-modified > $mirror-last-modified)
                      )
            return
                $up-to-date-relative and (
                    (not(format:dependency-is-transformable($path)))
                    or mirror:is-up-to-date($format:unflatten-cache, $path)
                )
};
 
(:~ perform the transform up to the combine step 
 : @param $doc The document to be transformed
 : @param $params Parameters to pass to the transforms
 : @param $original-doc The original document that is being transformed (may be the same as $doc) 
 : @return The combined document (as an in-database copy)
 :)
declare function format:combine(
  $doc as document-node(),
  $params as map(*),
  $original-doc as document-node()
  ) as document-node() {
  let $params := format:status-param($params, $original-doc)
  let $unflats := format:unflatten-dependencies($doc, $params)
  let $cmb := combine:combine-document(?, $params)
  return
    format:apply-if-outdated(
      "combine",
      $params,
      $format:combine-cache,
      mirror:doc($format:unflatten-cache, document-uri($doc)),
      $cmb,
      $original-doc,
      format:combine-dependencies-up-to-date#2
    )
};

(:~ perform the transform up to the compile step 
 : @param $doc The document to be transformed
 : @param $params Parameters to pass to the transforms
 : @param $original-doc The original document that is being transformed (may be the same as $doc) 
 : @return The compiled document (as an in-database copy)
 :)
declare function format:compile(
  $doc as document-node(),
  $params as map(*),
  $original-doc as document-node()
  ) as document-node() {
  let $params := format:status-param($params, $original-doc)
  let $cmp := compile:compile-document(?, $params)
  let $combined := format:combine($doc, $params, $original-doc)
  let $up-to-date-function := mirror:is-up-to-date-cache(?, ?, $format:combine-cache)
  return
    (: compile has to check if the compile cache is outdated against the updated combine cache,
     : not the original document
     :)
    format:apply-if-outdated(
      "compile",
      $params,
      $format:compile-cache,
      $combined,
      $cmp,
      $original-doc,
      $up-to-date-function
    )
};

(:~ perform the transform up to the HTML formatting step 
 : @param $doc The document to be transformed
 : @param $params Parameters to pass to the transforms
 : @param $original-doc The original document that is being transformed (may be the same as $doc) 
 : @param $transclude Use transclusion?
 : @return The combined document (as an in-database copy)
 :)
declare function format:html(
  $doc as document-node(),
  $params as map(*),
  $original-doc as document-node(),
  $transclude as xs:boolean
  ) as document-node() {
  let $params := format:status-param($params, $original-doc)
  let $html := tohtml:tohtml-document(?, $params)
  let $up-to-date-function := 
    if ($transclude)
    then mirror:is-up-to-date-cache(?, ?, $format:compile-cache)
    else ()
  return
    format:apply-if-outdated(
      "html",
      $params,
      $format:html-cache,
      if ($transclude)
      then format:compile($doc, $params, $original-doc)
      else format:unflatten($doc, $params, $original-doc),
      $html,
      $original-doc,
      $up-to-date-function
    )
};

declare function format:reverse(
  $doc as document-node(),
  $params as map(*)
  ) as document-node() {
  reverse:reverse-document($doc, $params)
};


declare function format:transliterate(
  $doc as document-node(),
  $params as map(*)
  ) as document-node() {
  (: TODO: set up a transliteration cache :)
  translit:transliterate-document($doc, $params)
};

