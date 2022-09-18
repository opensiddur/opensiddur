xquery version "3.1";

(:~ document index module
 :
 : Manage an index of references in the /db/docindex collection
 : This index is keyed by data-type, and document name and the
 : full database path (starting with /db). It can be used to look up either way.
 :
 : Open Siddur Project
 : Copyright 2020 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace didx = 'http://jewishliturgy.org/modules/docindex';

import module namespace magic="http://jewishliturgy.org/magic"
  at "../magic/magic.xqm";

declare namespace error="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";

(: the default cache is under this directory :)
declare variable $didx:didx-collection := "docindex";
declare variable $didx:didx-path := concat("/db/", $didx:didx-collection);
declare variable $didx:didx-resource := "docindex.xml";

(:~ initial setup :)
declare function didx:setup(
    ) {
    let $create-collection :=
        if (xmldb:collection-available($didx:didx-path))
        then ()
        else xmldb:create-collection("/db", $didx:didx-collection)
    let $uri := xs:anyURI($didx:didx-path)
    let $owner-collection := sm:chown($uri, "admin")
    let $group-collection := sm:chgrp($uri, "everyone")
    let $mode-collection := sm:chmod($uri, "rwxr-xr-x")
    let $index-resource :=
        (: write the index configuration :)
        xmldb:store($didx:didx-path, $didx:didx-resource,
            <didx:index/>
        )
    let $index-uri := xs:anyURI(concat($didx:didx-path, "/", $didx:didx-resource))
    let $index-owner := sm:chown($index-uri, "admin")
    let $index-group := sm:chgrp($index-uri, "everyone")
    let $index-mode := sm:chmod($index-uri, "rw-r--r--")
    return ()
};

(:~ index or reindex a document given its location by collection
 : and resource name
 : If only a collection is given, reindex the collection after clearing it
 :)
declare function didx:reindex(
  $collection as xs:string,
  $resource as xs:string?
  ) {
  if (not($resource))
  then
    let $remove := didx:remove($collection)
    return didx:reindex(collection($collection))
  else didx:reindex(doc(concat($collection, "/", $resource)))
};

(:~ index or reindex a document from the given document node
 : which may be specified as a node or an xs:anyURI or xs:string
 :)
declare function didx:reindex(
  $doc-items as item()*
  ) as empty-sequence() {
  for $doc-item in $doc-items
  let $doc := root($doc-item)
  let $doc-uri := document-uri($doc)
  let $collection := util:collection-name($doc)
  let $resource := util:document-name($doc)
  let $resource-extension-removed := replace($resource, "\.[^.]+$", "")
  let $split := tokenize($collection, "/") (: "[1]/[2]db/[3]data/[4]{datatype}/...":)
  let $data-type := $split[4]
  let $index-entry :=
    <didx:entry
        collection="{$collection}"
        data-type="{$data-type}"
        document-name="{$resource}"
        resource="{$resource-extension-removed}"
        db-path="{$doc-uri}"/>
  let $index-collection := collection($didx:didx-path)
  let $existing-entry := $index-collection//didx:entry[@db-path=$doc-uri]
  return
    system:as-user("admin", $magic:password, (
        let $update := if (exists($existing-entry))
            then update replace $existing-entry with $index-entry
            else update insert $index-entry into $index-collection[1]/*
        let $reindex :=
            xmldb:reindex($didx:didx-path, $didx:didx-resource)
        return ()
    ))
};


declare function didx:remove(
    $collection as xs:string
    ) as empty-sequence() {
    system:as-user("admin", $magic:password,
        let $collection-entries := collection($didx:didx-path)//didx:entry[$collection=@collection]
        let $delete := update delete $collection-entries
        let $reindex := xmldb:reindex($didx:didx-path, $didx:didx-resource)
        return ()
    )
};

declare function didx:remove(
  $collection as xs:string,
  $resource as xs:string?
  ) as empty-sequence() {
  if (exists($resource))
  then
      let $doc-uri := $collection || "/" || $resource
      let $index-collection := collection($didx:didx-path)
      let $existing-entry := $index-collection//didx:entry[$doc-uri=@db-path]
      where exists($existing-entry)
      return
          system:as-user("admin", $magic:password, (
               let $update := update delete $existing-entry
               let $reindex := xmldb:reindex($didx:didx-path, $didx:didx-resource)
               return ()
          ))
  else didx:remove($collection)
};

(:~ Query the document index for a path :)
declare function didx:query-path(
  $data-type as xs:string,
  $resource as xs:string
  ) as xs:string? {
  let $query :=
    collection($didx:didx-path)//didx:entry[$data-type=@data-type][$resource=@resource]
  return $query/@db-path/string()
};

(:~ query the document index by a path :)
declare function didx:query-by-path(
  $db-path as xs:string
  ) as element(didx:result)? {
  let $query :=
    collection($didx:didx-path)//didx:entry[$db-path=@db-path]
  where exists($query)
  return <didx:result>{$query/@*}</didx:result>
};
