xquery version "3.1";

(:~
: Source package installer.
: A source package contains:
: * a data/ directory with subdirectories for original/, conditionals/, transliterations/, etc.
: * all internal pointers within the package point to paths relative to $PACKAGE$/ (eg, $PACKAGE$/original/document#stream)
: * a post-install script that calls pkginstall:pkginstall(path to data directory).
:
: Copyright 2019 Efraim Feinstein <efraim@opensiddur.org>.
: Licensed under the GNU Lesser General Public License version 3 or later
:)

module namespace pkginstall = "http://jewishliturgy.org/modules/pkginstall";

import module namespace crest="http://jewishliturgy.org/modules/common-rest" at "common-rest.xqm";
import module namespace cnd="http://jewishliturgy.org/api/data/conditionals" at "../api/data/conditionals.xqm";
import module namespace dict="http://jewishliturgy.org/api/data/dictionaries" at "../api/data/dictionaries.xqm";
import module namespace lnk="http://jewishliturgy.org/api/data/linkage" at "../api/data/linkage.xqm";
import module namespace notes="http://jewishliturgy.org/api/data/notes" at "../api/data/notes.xqm";
import module namespace orig="http://jewishliturgy.org/api/data/original" at "../api/data/original.xqm";
import module namespace outl="http://jewishliturgy.org/api/data/outlines" at "../api/data/outlines.xqm";
import module namespace src="http://jewishliturgy.org/api/data/sources" at "../api/data/sources.xqm";
import module namespace sty="http://jewishliturgy.org/api/data/styles" at "../api/data/styles.xqm";
import module namespace tran="http://jewishliturgy.org/api/data/transliteration" at "../api/data/transliteration.xqm";
import module namespace data="http://jewishliturgy.org/modules/data" at "data.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri" at "follow-uri.xqm";

declare namespace http="http://expath.org/ns/http-client";

declare variable $pkginstall:INTERNAL_PTR_PLACEHOLDER := "$PACKAGE$";

(:~ data paths that map to APIs and the APIs that they map to :)
declare variable $pkginstall:api-paths := map {
  "original" : map {
    "title" : crest:tei-title-function#1,
    "post" : orig:post#1
  },
  "conditionals" : map {
    "title" : crest:tei-title-function#1,
    "post" : cnd:post#1
  },
  "dictionaries" : map {
    "title" : crest:tei-title-function#1,
    "post" : dict:post#1
  },
  "linkage" : map {
    "title" : crest:tei-title-function#1,
    "post" : lnk:post#1
  },
  "notes" : map {
    "title" : notes:uri-title-function#1,
    "post" : notes:post#1
  },
  "outlines" : map {
    "title" : outl:title-function#1,
    "post" : outl:post#1
  },
  "sources" : map {
    "title" : src:title-function#1,
    "post" : src:post#1
  },
  "styles" : map {
    "title" : crest:tei-title-function#1,
    "post" : sty:post#1
  },
  "transliteration" : map {
    "title" : tran:title-function#1,
    "post" : tran:post#1
  }
};

(:~ @return a document from this package, with internal pointer replacement, if necessary :)
declare function pkginstall:doc(
  $path as xs:string,
  $relative-path as xs:string
) as document-node()? {
  doc(
    if (contains($relative-path, $pkginstall:INTERNAL_PTR_PLACEHOLDER))
    then
      replace($relative-path, $pkginstall:INTERNAL_PTR_PLACEHOLDER, $path)
    else $path || $relative-path
  )
};

(:~ @return a standardized relative path :)
declare function pkginstall:path-to-relative-path(
  $path as xs:string
) as xs:string {
  let $uri-tokens := fn:tokenize($path, '/')
  return "/" || fn:string-join(fn:subsequence($uri-tokens, count($uri-tokens) - 1), "/")
};

(:~ make sure all titles inside a package with the given resource type will resolve to unique titles
 : Return all duplicate titles within a package
 :)
declare function pkginstall:duplicate-titles(
  $base-path as xs:string,
  $path-type as xs:string,
  $path-apis as map(*)
) as element(title-record)* {
  let $counts :=
    for $doc in collection($base-path || "/" || $path-type)
    let $title-function := $path-apis("title")
    let $title := $title-function($doc)
    group by $title
    return
      <title-record>
        <paths>{string-join(
          for $d in $doc return document-uri($d), ",")}</paths>
        <title>{$title}</title>
        <count>{count($doc)}</count>
      </title-record>
  return
    $counts[count > 1]
};

(:~ make sure all titles inside a package will resolve to unique titles
 : Return all duplicate titles within a package
 :)
declare function pkginstall:duplicate-titles(
  $path as xs:string
) as element(title-record)* {
  map:for-each-entry($pkginstall:api-paths,
    pkginstall:duplicate-titles($path, ?, ?)
  )
};

(:~ get the direct dependencies of a document inside this package :)
declare function pkginstall:dependencies-of(
  $doc as document-node()
) as element()* {
  let $targets :=
    distinct-values(
      for $targets in $doc//*[@targets|@target|@domains|@ref]/(@target|@targets|@domains|@ref)
      return tokenize($targets, '\s+')
    )
  return
    for $target in $targets
    let $target-document-ptr :=
      if (contains($target, "#"))
      then substring-before($target, "#")
      else $target
    return
      if (starts-with($target, $pkginstall:INTERNAL_PTR_PLACEHOLDER))
      then
        (: this is internal to the package :)
        element pkginstall:internal-dependency {
          text { pkginstall:path-to-relative-path($target-document-ptr) }
        }
      else
        (: external, let's make sure it exists :)
        if (not(
          starts-with($target, '#') or
          starts-with($target, 'http:') or
          starts-with(., 'https:')
        ))
        then
          element pkginstall:external-dependency {
            text { $target-document-ptr }
          }
        else
          (: ignorable :)
          ()
};

(:~ find the dependencies of all resources under the given path
 : internal dependencies will be in element internal-dependencies, external in external-dependencies
 :)
declare function pkginstall:dependencies(
  $path as xs:string
  ) as element(pkginstall:dependencies) {
  element pkginstall:dependencies {
    for $resource in collection($path)
    let $uri := document-uri($resource)
    let $relative-path := pkginstall:path-to-relative-path($uri)
    return
      element pkginstall:resource {
        attribute path { $relative-path },
        pkginstall:dependencies-of($resource)
      }
  }
};

(:~ @return element pkginstall:dependency-error for each external entity that cannot be found :)
declare function pkginstall:check-external-dependencies(
  $dependencies as element(pkginstall:dependencies)
) as element(pkginstall:dependency-error)* {
  ()
};

(:~ @return element pkginstall:dependency-error for each resource that has a circular dependency :)
declare function pkginstall:check-circular-dependencies(
  $dependencies as element(pkginstall:dependencies)
) as element(pkginstall:dependency-error)* {
  ()
};

(:~ @return element pkginstall:dependency-error for each internal dependency that does not exist :)
declare function pkginstall:check-internal-dependencies(
  $dependencies as element(pkginstall:dependencies)
) as element(pkginstall:dependency-error)* {
  ()
};

(:~ finalize the resource (file) names of all the resources in the package
 : @return pkginstall:resources element with subelements pkginstall:resource/(pkginstall:name, pkginstall:dependencies)
 :)
declare function pkginstall:finalize-resource-names(
  $path as xs:string,
  $dependencies as element(pkginstall:dependencies)
) as element(pkginstall:resources) {
  element pkginstall:resources {
    for $dependency-record in $dependencies/pkginstall:resource
    return
      element pkginstall:resource {
        $dependency-record/@*,
        element pkginstall:name {
          let $doc := pkginstall:doc($path, $dependency-record/@path)
          let $type := tokenize($dependency-record/@path, "/")[.][1]
          let $title := $pkginstall:api-paths($type)("title")($doc)
          return "/data/" || $type || "/" || data:new-path-to-resource($type, $title)[2]
        },
        $dependency-record/*
      }
  }
};

(:~ maps old path to new path, given the element-style mapping :)
declare function pkginstall:resources-to-map(
  $resources as element(pkginstall:resources)
) as map(xs:string, xs:string) {
  map:merge (
    for $resource-entry in $resources/pkginstall:resource
    return map:entry($resource-entry/@path/string(), $resource-entry/pkginstall:name/string())
  )
};

(:~ rewrite a target given the mapping :)
declare function pkginstall:rewrite-target(
  $target as xs:string,
  $resource-map as map(xs:string, xs:string)
) as xs:string {
  let $tokens := tokenize($target, "#")
  let $resource := $tokens[1]
  let $fragment := $tokens[2]
  return (
    if (contains($resource, $pkginstall:INTERNAL_PTR_PLACEHOLDER))
    then
      let $relative-path := pkginstall:path-to-relative-path($resource)
      return
        if (map:contains($relative-path))
        then $resource-map($relative-path)
        else $resource
    else $resource
  ) || (
    if ($fragment)
    then "#" || $fragment
    else ""
  )
};

(:~ rewrite targeted ptrs that reference $PACKAGE$ to the finalized resource names
 : @param $doc The document to be rewritten
 : @param $resources The list of resources from finalize-uris()
 : @return the rewritten document
 :)
declare function pkginstall:rewrite-ptrs(
  $doc as document-node(),
  $resources as element(pkginstall:resources)
) as document-node() {
  let $resources-map := pkginstall:resources-to-map($resources)
  return pkginstall:rewrite-ptrs-transform($doc, $resources-map)
};

(:~ recursive transform to rewrite pointers :)
declare function pkginstall:rewrite-ptrs-transform(
  $nodes as node()*,
  $resources-map as map(xs:string, xs:string)
) as node()* {
  for $node in $nodes
  return
    typeswitch ($node)
    case document-node() return
      document { pkginstall:rewrite-ptrs-transform($node/node(), $resources-map) }
    case element()
    return
      element { QName(namespace-uri($node), name($node)) } {
        for $attribute in $node/@*
        return
          attribute {QName(namespace-uri($attribute), name($attribute))} {
            if (name($attribute) = ("targets", "target", "domains", "ref"))
            then
              string-join(
                for $target in tokenize($attribute, "\s+")
                return pkginstall:rewrite-target($target, $resources-map),
                " ")
            else string($attribute),
            pkginstall:rewrite-ptrs-transform($node/node(), $resources-map)
          }
      }
    default return $node
};

(:~ order all documents from the write queue into the order they should be written (accounting for dependencies)
 : @param $path The database collection of the documents
 : @param $write-queue Resources to be written
 : @param $completed Resources that have already been written
 : @param $hold-queue Internal. Resources that can't be written yet before the call due to dependencies.
 :  Empty at first call.
 : @return The pkginstall:resource elements in the order in which they should be written
 :)
declare function pkginstall:write-order(
  $path as xs:string,
  $write-queue as element(pkginstall:resource)*,
  $completed as element(pkginstall:resource)*,
  $hold-queue as element(pkginstall:resource)*
) {
  if (empty($write-queue/*))
  then (
    if (empty($hold-queue/*))
    then (
      (: done, return completed :)
      $completed
    )
    else
      (: the hold queue becomes the new write queue :)
      pkginstall:write-order($path, $hold-queue, $completed, ())
  )
  else
    let $next-to-write := $write-queue[1]
    return
      let $completed-internal-dependencies := $completed/@path/string()
      let $unresolved-internal-dependencies :=
        for $internal-dependency in $next-to-write/pkginstall:internal-dependency
        where empty($internal-dependency[.=$completed-internal-dependencies])
        return $internal-dependency
      return
        if (empty($unresolved-internal-dependencies))
        then (
          (: no unresolved dependencies, add this one to completed :)
          (
            pkginstall:write-order($path,
              subsequence($write-queue, 2),
              ($completed, $next-to-write),
              $hold-queue)
          )
        )
        else
          (: there are unresolved dependencies, add to the hold queue :)
          pkginstall:write-order($path,
            subsequence($write-queue, 2),
            $completed,
            ($hold-queue, $next-to-write)
            )
};

(:~ write out all of the resources to the database
 : @param $path base path of the package
 : @param $write-queue ordered list of resources to write (@path has the path relative to $path)
 : @return one pkginstall:written element per element in $write-queue, indicating the success of the write
 :)
declare function pkginstall:write(
  $path as xs:string,
  $write-queue as element(pkginstall:resource)*
) as element(pkginstall:written)* {
  for $entry in $write-queue
  let $relative-path := $entry/@path/string()
  let $doc-type := tokenize($relative-path, "/")[.][1]
  let $absolute-path := $path || $relative-path
  let $posting-function := $pkginstall:api-paths($doc-type)("post")
  let $posted := $posting-function(doc($absolute-path))
  let $successful := $posted//http:response/@status/number() >= 400
  return
    element pkginstall:written {
      attribute absolute-path { $absolute-path },
      attribute relative-path { $relative-path },
      attribute success { string($successful) },
      if (not($successful))
      then $posted
      else ()
    }
};

(:~ Front end to the package installer. A s
 : @param $path Path to the data directory of the package.
 :)
declare function pkginstall:pkginstall(
  $path as xs:string
) {
  if (exists(pkginstall:duplicate-titles($path)))
  then
    error(xs:QName("pkginstall:DUPLICATES"), "There are documents with duplicate titles in this package")
  else
    let $dependencies := pkginstall:dependencies($path)
    let $circular-deps := pkginstall:check-circular-dependencies($dependencies)
    let $bad-external-deps := pkginstall:check-external-dependencies($dependencies)
    let $bad-internal-deps := pkginstall:check-internal-dependencies($dependencies)
    return
      if (exists($circular-deps))
      then
        error(xs:QName("pkginstall:CIRCULAR"), "There are circular dependencies in this package: ", $circular-deps)
      else if (exists($bad-external-deps))
      then
        error(xs:QName("pkginstall:EXTERNAL"),
          "Package requires external dependencies that are not present or accessible", $bad-external-deps)
      else if (exists($bad-internal-deps))
      then
        error(xs:QName("pkginstall:INTERNAL"),
          "Package requires internal dependencies that are not present or accessible", $bad-internal-deps)
      else ()
};