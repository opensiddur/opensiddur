xquery version "3.0";

(:~ reference index module
 :
 : Manage an index of references in the /db/refindex collection
 : In this index, the keys are the referenced URI or a node
 : and the type of reference. The index stores node id's of
 : the linking elements that make the references
 :
 : Open Siddur Project
 : Copyright 2011-2012 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later 
 :)
module namespace ridx = 'http://jewishliturgy.org/modules/refindex';

import module namespace app="http://jewishliturgy.org/modules/app"
  at "xmldb:exist:///code/modules/app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "xmldb:exist:///code/modules/debug.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "xmldb:exist:///code/modules/follow-uri.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:///code/magic/magic.xqm";

declare namespace err="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";

(: the default cache is under this directory :)
declare variable $ridx:ridx-collection := "refindex";

(: if this file exists, reference indexing should be skipped.
 :)
declare variable $ridx:disable-flag := "disabled.xml";

(:~ given a collection, return its index :)
declare function ridx:index-collection(
  $collection as xs:string
  ) as xs:string {
  app:concat-path(("/", $ridx:ridx-collection, $collection))
};

(:~ make an index collection path that mirrors the same path in 
 : the normal /db hierarchy 
 : @param $path-base the constant base at the start of the path
 : @param $path the path to mirror
 :)
declare function local:make-mirror-collection-path(
  $path-base as xs:string,
  $path as xs:string
  ) as empty() {
  let $steps := tokenize(replace($path, '^(/db)?/', concat($path-base,"/")), '/')[.]
  for $step in 1 to count($steps)
  let $this-step := concat('/', string-join(subsequence($steps, 1, $step), '/'))
  where not(xmldb:collection-available($this-step))
  return
    let $mirror-this-step := concat("/",string-join(subsequence($steps, 2, $step - 1),"/"))
    let $previous-step := concat('/', string-join(subsequence($steps, 1, $step - 1), '/'))
    let $new-collection := $steps[$step]
    let $null := 
      debug:debug(
        $debug:info,
        "refindex",
        (("step ", $step, ":", $this-step, " new-collection=",$new-collection, " from ", $previous-step))
      )
    return (
      debug:debug(
        $debug:info,
        "refindex",
        ('creating new index collection: ', $this-step, ' from ', $previous-step, ' to ', $new-collection ,' owner/group/permissions=', $owner, '/',$group, '/',util:integer-to-base($mode,8))
      ),
      if (xmldb:create-collection($previous-step, $new-collection))
      then 
        app:mirror-permissions(
          if ($step = 1)
          then "/db"
          else $mirror-this-step, $this-step)
      else error(xs:QName('err:CREATE'), concat('Cannot create index collection ', $this-step))
    )
};

(:~ index or reindex a document given its location by collection
 : and resource name :)
declare function ridx:reindex(
  $collection as xs:string,
  $resource as xs:string
  ) {
  ridx:reindex(doc(app:concat-path($collection, $resource)))
};

(:~ index or reindex a document from the given document node
 : which may be specified as a node or an xs:anyURI or xs:string
 :)
declare function ridx:reindex(
  $doc-items as item()*
  ) as empty() {
  let $disabled := doc-available(concat("/", $ridx:ridx-collection, "/", $ridx:disable-flag))
  where not($disabled)
  return
    for $doc-item in $doc-items
    let $doc := 
      typeswitch($doc-item)
      case document-node() 
        return 
          $doc-item
            [not(util:is-binary-doc(document-uri(.)))]
      default 
        return 
          if (util:is-binary-doc($doc-item))
          then ()
          else doc($doc-item)
    (: do not index binary documents :)
    where exists($doc)
    return
      let $collection := replace(util:collection-name($doc), "^/db", "")
      let $resource := util:document-name($doc)
      let $make-mirror-collection :=
       (: TODO: this should not have to be admin-ed. really, it should
       be setuid! :)
       try {
        system:as-user("admin", $magic:password, 
          local:make-mirror-collection-path($ridx:ridx-collection, $collection)
        )
       }
       catch * {
        (: TODO: this code is here to account for a bug where, in the
         : restore process, the admin password is considered to be blank
         : even though it had been set. It affects eXist r14669 under 
         : circumstances that I can't figure out. Hopefully, it will not
         : affect future versions, but if it does, we need this code
         : to work around it. A warning will be displayed when this code
         : executes. The warning is irrelevant to a user.
         :)
        debug:debug($debug:warn, "refindex", "The admin password is blank. This is a bug in eXist, I think."),
        system:as-user("admin", "", 
          local:make-mirror-collection-path($ridx:ridx-collection, $collection)
        )
       }
      let $mirror-collection :=
        app:concat-path(("/", $ridx:ridx-collection, $collection))
      let $original-path := concat($collection, "/", $resource)
      let $mirror-path := concat($mirror-collection, "/", $resource)
      let $last-modified := xmldb:last-modified($collection, $resource)
      let $idx-last-modified := xmldb:last-modified($mirror-collection, $resource)
      where empty($last-modified) or empty($idx-last-modified) or ($last-modified > $idx-last-modified)
      return
        let $stored := 
          if (xmldb:store($mirror-collection, $resource, 
            element ridx:index {
              ridx:make-index-entries($doc//@target|$doc//@targets)
            }
          ))
          then
            app:mirror-permissions($original-path, $mirror-path)
          else ()
        return () 
};

declare function ridx:make-index-entries(
  $reference-attributes as attribute()*
  ) as element()* {
  for $rattr in $reference-attributes
  let $element := $rattr/parent::element()
  let $ptr-node-id := util:node-id($element)
  let $type := ($element, $element/(ancestor::tei:linkGrp|ancestor::tei:joinGrp)[1])[1]/@type/string()
  for $follow at $n in tokenize($rattr/string(), "\s+")
  let $returned := 
    if (matches($follow, "^http[s]?://"))
    then ()
    else uri:fast-follow($follow, $element, uri:follow-steps($element), true())
  for $followed in $returned
  where $followed/@xml:id
  return
    element ridx:entry {
      attribute ref { uri:absolutize-uri(concat("#", $followed/@xml:id/string()), $followed) },
      attribute ns { namespace-uri($element) },
      attribute local-name { local-name($element) },
      attribute n { $n },
      attribute type { $type },
      attribute node { $ptr-node-id }
    }
};

declare function ridx:lookup(
  $node as node(),
  $context as document-node()*,
  $ns as xs:string*,
  $local-name as xs:string*
  ) as node()* {
  ridx:lookup($node,$context,$ns,$local-name,(),(),())
};

declare function ridx:lookup-document(
  $docs as item()*
  ) as node()* {
  ridx:lookup-document($docs, false())
};

(:~ return all references to a document
 : @param $accept-same if true(), include all references that
 :  are in the same document. Default false()
 :)
declare function ridx:lookup-document(
  $docs as item()*,
  $accept-same as xs:boolean
  ) as node()* {
  for $doc in $docs
  let $doc-uri :=
    typeswitch ($doc)
    case node() return document-uri(root($doc))
    default return 
      (: this code will normalize the URI to the same as the document-uri
      function will return :)
      document-uri(doc($doc))
  let $mirror-uri :=
      app:concat-path(("/", $ridx:ridx-collection, replace($doc-uri, "^/db", "")))
  let $mirror-doc := doc($mirror-uri)
  let $idx-collection := ridx:index-collection("/")
  let $db-idx-collection := concat("^/db/", $ridx:ridx-collection)
  for $entry in 
    collection($idx-collection)//ridx:entry
      [starts-with(@ref, $doc-uri)]
      [$accept-same or not(root(.) is $mirror-doc)]
  let $original-doc := doc(replace(document-uri(root($entry)), $db-idx-collection, ""))
  return
    try {
      util:node-by-id($original-doc, $entry/@node)
    }
    catch * {
      debug:debug($debug:info, 
        "refindex", 
        ("A query could not find a node in ", $original-doc, " - is the index expired?")
      )
    }    
};

(:~ Look up if the current node specifically or, including any
 : of its ancestors (default true() unless $without-ancestors is set)
 : is referenced in a reference of type $ns:$local-name/@type, 
 : in the $n-th position
 : If any of the optional parameters are not found, do not limit
 : based on them.
 : The search is performed for nodes only within $context, which may be 
 : a collection or a document-node()
 :)
declare function ridx:lookup(
  $node as node(),
  $context as document-node()*,
  $ns as xs:string*,
  $local-name as xs:string*,
  $type as xs:string*,
  $n as xs:integer*,
  $without-ancestors as xs:boolean?
  ) as node()* {
  let $defaulted-context :=
    if (exists($context))
    then 
      for $c in $context
      return 
        doc(
          replace(document-uri($c), "^(/db)?/", 
            concat("/", $ridx:ridx-collection, "/")
          )
        )
    else collection(concat("/db/", $ridx:ridx-collection))
  let $nodes :=
    if ($without-ancestors) 
    then $node[@xml:id]
    else $node/ancestor-or-self::*[@xml:id]
  where exists($nodes)
  return
    let $uris := 
      for $nd in $nodes
      return 
        uri:absolutize-uri(
          concat("#", $nd/@xml:id/string()), $nd
        )
    for $entry in $defaulted-context//ridx:entry
        [@ref=$uris]
        [
          if (exists($ns))
          then @ns=$ns
          else true()
        ]
        [
          if (exists($local-name))
          then @local-name=$local-name
          else true() 
        ]
        [
          if (exists($n))
          then @n=$n
          else true()
        ]
    let $original-doc := doc(
        replace(document-uri(root($entry)), concat("/", $ridx:ridx-collection), "")
      )
    return 
      try {
        util:node-by-id($original-doc, $entry/@node)
      }
      catch * {
        debug:debug($debug:warn,"refindex", ("A query for ", $node, " failed on util:node-by-id. ", " The entry was: ", $entry))(:,
        ridx:reindex(root($entry)),
        ridx:lookup($node, $context, $ns, $local-name, $type, $n, $without-ancestors):)
      }
};

(:~ disable the reference index: you must be admin! :)
declare function ridx:disable(
  ) as xs:boolean {
  let $user := xmldb:get-current-user()
  let $idx-collection := concat("/",$ridx:ridx-collection)
  return
    xmldb:is-admin-user($user)
    and (
      if (xmldb:store(
        $idx-collection,
        $ridx:disable-flag,
        <ridx:index-disabled/>
        ))
      then (
        xmldb:set-resource-permissions($idx-collection,
          $ridx:disable-flag, $user, "dba", util:base-to-integer(0774, 8)
        ), true()
      )
      else false()
    )
};

(:~ re-enable the reference index: you must be admin to run! :)
declare function ridx:enable(
  ) as xs:boolean {
  let $idx-collection := concat("/", $ridx:ridx-collection)
  return
    if (xmldb:is-admin-user(xmldb:get-current-user())
      and doc-available(concat($idx-collection, "/", $ridx:disable-flag))
      )
    then (
      xmldb:remove($idx-collection, $ridx:disable-flag),
      true()
    )
    else false()
};