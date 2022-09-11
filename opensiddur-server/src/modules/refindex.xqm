xquery version "3.1";

(:~ reference index module
 :
 : Manage an index of references in the /db/refindex collection
 : In this index, the keys are the referenced URI or a node
 : and the type of reference. The index stores node id's of
 : the linking elements that make the references
 :
 : Open Siddur Project
 : Copyright 2011-2014,2019 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later 
 :)
module namespace ridx = 'http://jewishliturgy.org/modules/refindex';

import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "debug.xqm";
import module namespace mirror="http://jewishliturgy.org/modules/mirror"
  at "mirror.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "follow-uri.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "../magic/magic.xqm";

declare namespace error="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";

(: the default cache is under this directory :)
declare variable $ridx:ridx-collection := "refindex";
declare variable $ridx:ridx-path := concat("/db/", $ridx:ridx-collection);
declare variable $ridx:indexed-base-path := "/db/data";

(: if this file exists, reference indexing should be skipped.
 :)
declare variable $ridx:disable-flag := "disabled.xml";

(:~ initial setup :)
declare function ridx:setup(
    ) {
    if (xmldb:collection-available($ridx:ridx-path))
    then (
        (: (re)write the mirror configuration :)
        xmldb:store($ridx:ridx-path, $mirror:configuration,
            <mirror:configuration>
              <mirror:of>/db/data</mirror:of>
              <mirror:universal-access>false</mirror:universal-access>
            </mirror:configuration>
        ),
        let $uri := xs:anyURI(concat($ridx:ridx-path, "/", $mirror:configuration))
        return (
            sm:chown($uri, "admin"),
            sm:chgrp($uri, "dba"),
            sm:chmod($uri, "rw-rw-r--")
        )
    )
    else mirror:create($ridx:ridx-path, "/db/data")
};

(:~ given a collection, return its index :)
declare function ridx:index-collection(
  $collection as xs:string
  ) as xs:string {
  mirror:mirror-path($ridx:ridx-path, $collection)
};

(:~ index or reindex a document given its location by collection
 : and resource name.
 : If the resource is empty, clear and reindex the collection.
 : Note that this is the only way to clear documents by collection name.
 :)
declare function ridx:reindex(
  $collection as xs:string,
  $resource as xs:string?
  ) {
  if (not($resource))
  then
    let $remove := mirror:remove($ridx:ridx-path, $collection, ())
    return ridx:reindex(collection($collection))
  else ridx:reindex(doc(concat($collection, "/", $resource)))
};

declare function ridx:is-enabled(
  ) as xs:boolean {
  not(doc-available(concat($ridx:ridx-path, "/", $ridx:disable-flag)))
};

declare function local:make-index-collection(
  $collection as xs:string
  ) as empty-sequence() {
  system:as-user("admin", $magic:password, (
    if (not(xmldb:collection-available($ridx:ridx-path)))
    then
      mirror:create($ridx:ridx-path, $ridx:indexed-base-path)
    else (),
    mirror:make-collection-path($ridx:ridx-path, $collection)
    )
  )
};

(:~ @return false() if the indexed document has any ridx:broken elements, otherwise true(). :)
declare function ridx:up-to-date-function(
    $mirror-path as xs:string,
    $original as item()
    ) as xs:boolean {
    let $ridx-doc := mirror:doc($mirror-path,
        typeswitch ($original)
        case document-node() return document-uri($original) 
        default return $original
        )
    return exists($ridx-doc) and empty($ridx-doc//ridx:broken)
};

(:~ index or reindex a document from the given document node
 : which may be specified as a node or an xs:anyURI or xs:string
 :)
declare function ridx:reindex(
  $doc-items as item()*
  ) as empty-sequence() {
  let $enabled := ridx:is-enabled()
  where $enabled
  return
    for $doc-item in $doc-items
    let $doc := 
      typeswitch($doc-item)
      case document-node() 
        return 
          $doc-item
            [not(util:is-binary-doc(document-uri(.)))]
      case node() return $doc-item
      default 
        return 
          if (util:is-binary-doc($doc-item))
          then ()
          else doc($doc-item)
    (: do not index binary documents :)
    where exists($doc)
    return
      let $doc-uri := document-uri(root($doc))
      let $collection := util:collection-name(root($doc))
      let $resource := util:document-name($doc)
      let $make-mirror-collection :=
        local:make-index-collection($collection)
      let $debug := debug:debug($debug:detail, "refindex", "reindexing " || $doc-uri || "...")
      where not(mirror:is-up-to-date($ridx:ridx-path, $doc-uri, ridx:up-to-date-function#2))
      return
        if (mirror:store($ridx:ridx-path, $collection, $resource, 
          element ridx:index {
            attribute document { $doc-uri },
            ridx:make-index-entries($doc//@target|$doc//@targets|$doc//@ref|$doc//@domains|$doc//@who)
          }
        ))
        then
          let $mirror-collection := mirror:mirror-path($ridx:ridx-path, $collection)
          let $reindex :=
            system:as-user("admin", $magic:password, (
                xmldb:reindex($mirror-collection, $resource)
            ))
          return ()
        else debug:debug($debug:warn, "refindex", 
          concat("Could not store index for ", $collection, "/", $resource))
};

declare function ridx:remove(
  $collection as xs:string,
  $resource as xs:string?
  ) as empty-sequence() {
  mirror:remove($ridx:ridx-path, $collection, $resource)
};

declare %private function ridx:make-index-entries(
  $reference-attributes as attribute()*
  ) as element()* {
  for $rattr in $reference-attributes
  let $element := $rattr/parent::element()
  let $source-node-id := util:node-id($element)
  for $follow at $position in tokenize($rattr/string(), "\s+")
  let $returned := 
    if (matches($follow, "^http[s]?://"))
    then ()
    else
        let $debug := debug:debug($debug:detail, "refindex", "following " || $follow || "...")
        let $r := uri:fast-follow($follow, $element, uri:follow-steps($element), true())
        return
            if (exists($r))
            then $r
            else 
                element ridx:broken {
                    attribute source-node { $source-node-id },
                    attribute position { $position },
                    attribute target { $follow }
                }
  for $followed in $returned
  return
    if ($followed instance of element(ridx:broken))
    then $followed
    else
        let $target-document := document-uri(root($followed))
        let $target-node-id := util:node-id($followed)
        return
          element ridx:entry {
            attribute source-node { $source-node-id },
            attribute target-doc { $target-document },
            attribute target-node { $target-node-id },
            attribute position { $position }
          }
};

declare function ridx:query(
  $source-nodes as node()*,
  $query-node as node()
  ) {
  ridx:query($source-nodes, $query-node, (), true())
};

declare function ridx:query(
  $source-nodes as node()*,
  $query-node as node(),
  $position as xs:integer*
  ) {
  ridx:query($source-nodes, $query-node, $position, true())
};


(:~ find instances where $source-nodes reference $query-node
 : in position $position
 : @param $source-nodes The nodes doing the targetting
 : @param $query-node The node that is being referenced
 : @param $position Limit results to the position in the link. Otherwise, do not limit.
 : @param $include-ancestors If set, then include in the search the node's ancestors (default true())
 :)
declare function ridx:query(
  $source-nodes as node()*,
  $query-nodes as node()*,
  $position as xs:integer*,
  $include-ancestors as xs:boolean?
  ) as node()* {
  let $nodes :=
    for $query in
      (
      if ($include-ancestors)
      then $query-nodes/ancestor-or-self::node()
      else $query-nodes
      )
    let $query-document := document-uri(root($query))
    let $query-id := util:node-id($query)
    for $source-node in $source-nodes
    let $source-document := document-uri(root($source-node))
    let $source-node-id := 
      if ($source-node instance of document-node())
      then ()
      else util:node-id($source-node)
    for $entry in (
        if (empty($source-node-id) and empty($position))
        then collection($ridx:ridx-path)/ridx:index[@document=$source-document]/ridx:entry
            [@target-node=$query-id]
            [@target-doc=$query-document]
        else if (empty($source-node-id))
        then collection($ridx:ridx-path)/ridx:index[@document=$source-document]/ridx:entry
            [@target-node=$query-id]
            [@target-doc=$query-document]
            [@position=$position]
        else if (empty($position))
        then collection($ridx:ridx-path)/ridx:index[@document=$source-document]/ridx:entry
            [@target-node=$query-id]
            [@source-node=$source-node-id]
            [@target-doc=$query-document]
        else collection($ridx:ridx-path)/ridx:index[@document=$source-document]/ridx:entry
            [@target-node=$query-id]
            [@source-node=$source-node-id]
            [@target-doc=$query-document]
            [@position=$position]
        )
    group by 
      $document-uri := string(root($entry)/*/@document),
      $entry-source-node := string($entry/@source-node)
    return (
      util:node-by-id(doc($document-uri), $entry-source-node)
    )
  return 
    $nodes | ()
};

declare function ridx:query-all(
  $query-nodes as node()*
  ) {
  ridx:query-all($query-nodes, (), true())
};

declare function ridx:query-all(
  $query-nodes as node()*,
  $position as xs:integer*
  ) {
  ridx:query-all($query-nodes, $position, true())
};

(:~ find all instances in the index where there are references to
 : $query-node in position $position
 : @param $query-node The node that is being referenced
 : @param $position Limit results to the position in the link. Otherwise, do not limit.
 : @param $include-ancestors If set, then include in the search the node's ancestors
 :)
declare function ridx:query-all(
  $query-nodes as node()*,
  $position as xs:integer*,
  $include-ancestors as xs:boolean?
  ) as node()* {
  let $nodes := 
    for $query in
      (
      if ($include-ancestors)
      then $query-nodes/ancestor-or-self::node()
      else $query-nodes
      )
    let $query-document := document-uri(root($query))
    let $query-id := util:node-id($query)
    for $entry in (
      if (empty($position))
      then collection($ridx:ridx-path)//
        ridx:entry
          [@target-doc=$query-document]
          [@target-node=$query-id]
      else collection($ridx:ridx-path)//
        ridx:entry
          [@target-doc=$query-document]
          [@target-node=$query-id]
          [@position=$position]
        )
    group by 
      $document-uri := root($entry)/*/@document/string(),
      $source-node := $entry/@source-node/string()
    return
      util:node-by-id(doc($document-uri), $source-node)
  return
    $nodes | ()
};


declare function ridx:query-document(
  $docs as item()*
  ) as node()* {
  ridx:query-document($docs, false())
};

(:~ @return all references to a document
 : @param $docs The documents, as URIs or document-node()
 : @param $accept-same if true(), include only references that
 :  are in the same document. Otherwise, return all references.
 :  Default false()
 :)
declare function ridx:query-document(
  $docs as item()*,
  $accept-same as xs:boolean
  ) as node()* {
  let $nodes :=
    for $doc in $docs
    let $target-document-uri :=
      document-uri(
        typeswitch ($doc)
        case node() return root($doc)
        default return doc($doc)
      )
    let $entries :=
      if ($accept-same)
      then
        collection($ridx:ridx-path)/
          ridx:index[@document=$target-document-uri]/
          ridx:entry[@target-doc=$target-document-uri]
      else 
        collection($ridx:ridx-path)//
          ridx:entry[@target-doc=$target-document-uri]
    for $entry in $entries
    return
      try {
        util:node-by-id(doc(root($entry)/*/@document), $entry/@source-node)
      }
      catch * {
        debug:debug($debug:info, 
          "refindex", 
          ("A query could not find a node from ", $entry, " - is the index expired?")
        )
      }  
  return
    $nodes | () (: avoid duplicates :)
};

(:~ disable the reference index: you must be admin! :)
declare function ridx:disable(
  ) as xs:boolean {
  let $user := sm:id()/(descendant::sm:effective,descendant::sm:real)[1]/sm:username/string()
  let $idx-flag := xs:anyURI(concat($ridx:ridx-path, "/", $ridx:disable-flag))
  return
    sm:is-dba($user)
    and (
      local:make-index-collection($ridx:indexed-base-path),
      if (xmldb:store(
        $ridx:ridx-path,
        $ridx:disable-flag,
        <ridx:index-disabled/>
        ))
      then (
        sm:chown($idx-flag, $user),
        sm:chgrp($idx-flag, "dba"),
        sm:chmod($idx-flag, "rw-rw-r--"), 
        true()
      )
      else false()
    )
};

(:~ re-enable the reference index: you must be admin to run! :)
declare function ridx:enable(
  ) as xs:boolean {
  if (sm:is-dba(sm:id()/(descendant::sm:effective,descendant::sm:real)[1]/sm:username/string())
    and doc-available(concat($ridx:ridx-path, "/", $ridx:disable-flag))
    )
  then (
    xmldb:remove($ridx:ridx-path, $ridx:disable-flag),
    true()
  )
  else false()
};
