xquery version "3.0";
(:~
 : XQuery functions to output a given XML file in a format.
 : 
 : Copyright 2011-2014 Efraim Feinstein <efraim.feinstein@gmail.com>
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
import module namespace tohtml="http://jewishliturgy.org/transform/html"
  at "../transforms/tohtml.xqm";
import module namespace translit="http://jewishliturgy.org/transform/transliterator"
  at "../transforms/translit/translit.xqm";
import module namespace reverse="http://jewishliturgy.org/transform/reverse"
  at "../transforms/reverse.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

declare variable $format:temp-dir := '.format';

declare variable $format:parallel-layer-cache := "/db/cache/parallel-layer";
declare variable $format:phony-layer-cache := "/db/cache/phony-layer";
declare variable $format:dependency-cache := "/db/cache/dependency";
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
      then map { "xml" := "html" }
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

declare function format:log-stage(
    $stage-function as function(node()*, map) as node()*,
    $current-resource as document-node(),
    $stage as xs:string,
    $params as map
    ) as node()* {
    let $status-resource := ($params("format:status-resource"), $current-resource)[1]
    let $is-first := 
        let $sd := status:doc($status-resource)
        return empty($sd) or exists($sd/*/@status:completed)
    let $next-params := map:new(
        $params,
        map { "format:status-resource" := $status-resource }
    )
    return
        try {
            let $job-start :=
                if ($is-first)
                then status:start-job($status-resource)
                else ()
            let $stage-start := status:start($status-resource, $current-resource, $stage)
            let $result := $stage-function($current-resource, $next-params),
            let $stage-finish := status:finish($status-resource, $current-resource, $stage),
            let $job-end := 
                if ($is-first)
                then status:complete-job($status-resource, $result)
                else ()
            return $result
        }
        catch * {
            let $error-message := 
                concat(
                    $err:module, ":", $err:line-number, ":", $err:column-number, 
                    ":"[$err:value], $err:value, 
                    ": "[$err:description], $err:description
                )
            return (
                status:fail($status-resource, $current-resource, $stage, $error-message),
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
  $params as map,
  $original-doc as document-node()
  ) as document-node() {
  let $pla-transform := format:log-stage(pla:parallel-layer-document#2, ?, "parallel-layer", $params)
  return
    mirror:apply-if-outdated(
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
  $params as map,
  $original-doc as document-node()
  ) as document-node() {
  let $pho-transform := format:log-stage(phony:phony-layer-document#2, ?, "phony-layer", $params)
  return
    mirror:apply-if-outdated(
      $format:phony-layer-cache,
      $doc,
      $pho-transform,
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
  $params as map,
  $original-doc as document-node()
  ) as document-node() {
  let $flatten-transform := format:log-stage(flatten:flatten-document#2, ?, "flatten", $params)
  return
    mirror:apply-if-outdated(
      $format:flatten-cache,
      if (format:is-parallel-document($original-doc))
      then 
        format:parallel-layer($doc, $params, $original-doc)
      else 
        format:phony-layer($doc, $params, $original-doc),
      $flatten-transform,
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
  $params as map,
  $original-doc as document-node()
  ) as document-node() {
  let $merge-transform := format:log-stage(flatten:merge-document#2, ?, "merge", $params)
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
 : @param $original-doc The original document that was resolved 
 : @return The merged document (as an in-database copy)
 :)
declare function format:resolve(
  $doc as document-node(),
  $params as map,
  $original-doc as document-node()
  ) as document-node() {
  let $resolve-transform := format:log-stage(flatten:resolve-stream#2, ?, "resolve", $params)
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
  $original-doc as document-node()
  ) as document-node() {
  let $unflatten-transform := format:log-stage(unflatten:unflatten-document#2, ?, "unflatten", $params)
  return
    mirror:apply-if-outdated(
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
  $doc as document-node()
  ) as document-node() {
  mirror:apply-if-outdated(
    $format:dependency-cache,
    $doc,
    format:get-dependencies#1
  )
};

(:~ unflatten all transformable dependencies of a given document :)
declare function format:unflatten-dependencies(
  $doc as document-node(),
  $params as map
  ) as document-node()* {
  for $dep in format:dependencies($doc)//format:dependency[@transformable]
  return format:unflatten(doc($dep), $params, doc($dep))
};

(:~ flatten all transformable dependencies of a given document, excluding itself :)
declare function format:flatten-external-dependencies(
  $doc as document-node(),
  $params as map
  ) as document-node()+ {
  for $dep in format:dependencies($doc)//format:dependency[@transformable]
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
  $params as map,
  $original-doc as document-node()
  ) as document-node() {
  let $unflats := format:unflatten-dependencies($doc, $params)
  let $cmb := format:log-stage(combine:combine-document#2, ?, "combine", $params)
  return
    mirror:apply-if-outdated(
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
  $params as map,
  $original-doc as document-node()
  ) as document-node() {
  let $cmp := format:log-stage(compile:compile-document#2, ?, "compile", $params)
  let $combined := format:combine($doc, $params, $original-doc)
  let $up-to-date-function := mirror:is-up-to-date-cache(?, ?, $format:combine-cache)
  return
    (: compile has to check if the compile cache is outdated against the updated combine cache,
     : not the original document
     :)
    mirror:apply-if-outdated(
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
  $params as map,
  $original-doc as document-node(),
  $transclude as xs:boolean
  ) as document-node() {
  let $html := format:log-stage(tohtml:tohtml-document#2, ?, "html", $params)
  let $up-to-date-function := 
    if ($transclude)
    then mirror:is-up-to-date-cache(?, ?, $format:compile-cache)
    else ()
  return
    mirror:apply-if-outdated(
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
  $params as map
  ) as document-node() {
  reverse:reverse-document($doc, $params)
};


declare function format:transliterate(
  $doc as document-node(),
  $params as map
  ) as document-node() {
  (: TODO: set up a transliteration cache :)
  translit:transliterate-document($doc, $params)
};

