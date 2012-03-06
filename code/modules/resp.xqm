xquery version "3.0";
(:~ module to handle attribution of responsibility within the database
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later 
 :)
module namespace resp = "http://jewishliturgy.org/modules/resp";

import module namespace app="http://jewishliturgy.org/modules/app"
  at "xmldb:exist:///code/modules/app.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "xmldb:exist:///code/modules/refindex.xqm";
import module namespace uri="http://jewishliturgy.org/transform/uri"
  at "xmldb:exist:///code/modules/follow-uri.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace err="http://jewishliturgy.org/errors";

declare variable $resp:tei-ns := "http://www.tei-c.org/ns/1.0";
declare variable $resp:valid-responsibility-types :=
  (: TODO: ideally, we'd read this directly from the schema... :)
  ("transcriber", "proofreader", "scanner", "editor", "author");

(:~ retrieve the full public contributor entry
 : for a given string identifier
 :)
declare function resp:contributor-entry(
  $resp-element as element(tei:respons)*
  ) as element()* {
  for $e in $resp-element
  return
    uri:follow-uri($e/@resp, $e, uri:follow-steps($e)) 
};

(:~ find who is declared responsible for all aspects of a 
 : given node.
 :)
declare function resp:query(
  $node as node()
  ) as node()* {
  ridx:lookup($node, collection("/group"),
   $resp:tei-ns, "respons")
};

(:~ find who is declared responsible for a given aspect
 : of a given node 
 :)
declare function resp:query(
  $node as node(),
  $resp-type as xs:string
  ) as node()* {
  ridx:lookup($node, collection("/group"),
    $resp:tei-ns, "respons", (), (), ())[@j:role=$resp-type]
};

(:~ retrieve the relative URI to the public profile of a user 
 : with identifier $id, relative to the document in $node 
 : if the public profile cannot be found, return empty()
 :)  
declare function local:public-profile-by-id(
  $node as node(),
  $id as xs:string
  ) as xs:string? {
  (: the profile is at /group/$group/contributors/$id.xml 
   : if the current document is at 
   :)
  let $public-profile-uri := concat(
    "/group/everyone/contributors/", $id, ".xml")
  let $doc-uri := replace(document-uri(root($node)), "^(/db)?/", "")
  let $path-tokens := tokenize($doc-uri, "/")
  let $n-tokens := count($path-tokens)
  let $doc-in-group-hierarchy := $path-tokens[1] = "group"
  let $group := 
    if ($doc-in-group-hierarchy)
    then $path-tokens[2]
    else "everyone"
  let $profile-with-id := 
    collection(concat("/group/", $group, "/contributors"))//id($id)
  let $profile-root := root($profile-with-id)
  where exists($profile-with-id)
  return 
    concat(
      if (not($doc-in-group-hierarchy))
      then 
        (: an absolute URI is required :)
        concat(
          replace(util:collection-name($profile-root), "^/db", ""), "/",
          util:document-name($profile-root)
        )
      else
        string-join((
          for $i in 1 to ($n-tokens - 3)
          return "..",
          "contributors",
          util:document-name($profile-root)
        ),
        "/"),
     "#", $id)
};

(: if a public profile does not already exist accessibly at a given 
 : node, make one accessible
 : if a profile is found that fits the parameters, use it and return 
 : the relative path to the profile,
 : otherwise, return empty()
 :)
declare function local:make-public-profile(
  $node as node(),
  $identifier as xs:string
  ) as xs:string? {
  let $has-identifier := collection("/group")//id($identifier)[ends-with(document-uri(root(.)), "profile.xml")]
  where ($has-identifier)
  return
    let $group := replace(document-uri(root($node)), "(^.*/group/)|(/.*$)", "")
    let $group-collection := concat("/group/", $group)
    let $group-profile-collection := "contributors"
    let $profile-collection := 
      let $pc := concat($group-collection, "/", $group-profile-collection)
      return (
        if (xmldb:collection-available($pc))
        then ()
        else
          if (xmldb:create-collection($group-collection, $group-profile-collection))
          then (
            sm:chown(xs:anyURI($pc), $group),
            sm:chgrp(xs:anyURI($pc), $group),
            sm:chmod(xs:anyURI($pc), "rwxrwxr-x")
          )
          else error(xs:QName('err:CREATE'), concat("Cannot create collection", $group-collection, "/", $group-profile-collection)),
        $pc
      )
    let $resource-name := concat($identifier, ".xml")
    let $resource-path := concat($profile-collection, "/", $resource-name) 
    return (
      if (xmldb:store($profile-collection, $resource-name, 
        element tei:ptr { 
          attribute xml:id { $identifier },
          attribute target { 
            replace(document-uri(root($has-identifier)), "^/db", "")  
          } 
        } ))
      then (
        sm:chown(xs:anyURI($resource-path), $group),
        sm:chgrp(xs:anyURI($resource-path), $group),
        sm:chmod(xs:anyURI($resource-path), "rwxrwx---")
      )
      else
        error(xs:QName("err:CREATE"), concat("Cannot create public profile for ", $identifier)),
      local:public-profile-by-id($node, $identifier)
    )
};

declare function local:write-respons-element(
  $begin-element as element()?,
  $end-element as element()?,
  $resp-type as xs:string,
  $locus as xs:string,
  $profile-id as xs:string
  ) as element(tei:respons)? {
  if (exists($end-element))
  then
    element tei:respons {
      attribute locus { $locus },
      attribute resp { $profile-id },
      attribute j:role { $resp-type },
      attribute target {
        if (($begin-element is $end-element) or empty($begin-element))
        then
          concat("#", $end-element/@xml:id/string())
        else
          concat("#range(", $begin-element/@xml:id/string(), 
            ",", $end-element/@xml:id/string() ,")")
      }
    }
  else ()
};

declare function local:make-ranges(
  $targets as element()*,
  $begin-element as element()?,
  $previous-element as element()?,
  $resp-type as xs:string,
  $locus as xs:string,
  $profile-id as xs:string,
  $ignore-nodes as node()*
  ) as element(tei:respons)* {
  if (empty($targets))
  then
    if (empty($previous-element))
    then ((: nothing to do... :))
    else local:write-respons-element($begin-element, $previous-element, $resp-type, $locus, $profile-id)
  else
    let $this := $targets[1]
    let $preceding := $this/preceding-sibling::*[@xml:id][not(. is $ignore-nodes)][1]
    return
      if ((empty($previous-element)) or ($preceding is $previous-element))
      then
        local:make-ranges(
          subsequence($targets,2), ($begin-element, $this)[1], $this, 
            $resp-type, $locus, $profile-id, $ignore-nodes)
      else (
        local:write-respons-element($begin-element,$previous-element, $resp-type, $locus, $profile-id),
        local:make-ranges(subsequence($targets,2), $this, $this, 
          $resp-type, $locus, $profile-id, $ignore-nodes)
      )
}; 

(: collapse the responsibilities of $profile-id in a given document 
 : into ranges; ignore $ignore-nodes, which will be subsequently deleted
 :)
declare function local:collapse-ranges(
  $doc as document-node(),
  $profile-ids as xs:string+,
  $resp-types as xs:string+,
  $ignore-nodes as node()*
  ) {
  (# exist:batch-transaction #) {
    for $profile-id in $profile-ids
    for $resp-type in $resp-types
    let $all-respons := $doc//tei:respons[@j:role=$resp-type][@resp=$profile-id]
      [@target] (: reject uncollapsable @match responsibilities :)
    return (
      for $respons-locus in $all-respons
      group $respons-locus as $l-respons by $respons-locus/@locus as $locus
      return 
        let $all-targets := (
          for $respons in $l-respons
          return uri:follow-tei-link($respons, 1)
          ) | ((: sort into document order:))
        let $new-ranges := 
          local:make-ranges($all-targets, (), (), $resp-type, $locus, $profile-id, $ignore-nodes)
        where exists($new-ranges)
        return 
          update insert $new-ranges into $doc//j:respList,
      update delete $all-respons
    )
  }
};

declare function resp:add(
  $node as element(), 
  $resp-type as xs:string,
  $identifier as xs:string
  ) {
  resp:add($node,$resp-type,$identifier, "location value")
};

(:~ get a relative link to the profile; if it doesn't exist, make one :)
declare function local:get-public-profile(
  $node as node(),
  $identifier as xs:string
  ) as xs:string? {
  let $existing := local:public-profile-by-id($node, $identifier)
  return
    if ($existing)
    then $existing
    else 
      let $new := local:make-public-profile($node, $identifier)
      return
        if ($new)
        then $new
        else error(xs:QName("err:NOPROFILE"), 
          concat("The user ", $identifier, " has no profile and there is no way to make one. Upload a profile manually"))
};
  

(:~ declare that the user with the given $identifier is 
 : responsible for $resp-type on node(). The responsibility extends
 : to $locus (default "value") 
 :)
declare function resp:add(
  $node as element(), 
  $resp-type as xs:string,
  $identifier as xs:string,
  $locus as xs:string
  ) {
  (: does the element have @xml:id? if not, error :)
  if (not($node/@xml:id))
  then
    error(xs:QName("err:INPUT"), "The node must have an @xml:id attribute.")
  else if (not($resp-type=$resp:valid-responsibility-types))
  then
    (: is the resp-type valid? if not, error :)
    error(xs:QName("err:INPUT"), concat(
      "The responsibility type must be selected from: ",
      string-join($resp:valid-responsibility-types, ",")))
  else 
    let $profile-id := local:get-public-profile($node, $identifier)
    let $doc := root($node)
    return (
      update insert 
        local:write-respons-element((),$node,$resp-type,$locus,$profile-id)
        into $doc//j:respList,
      local:collapse-ranges($doc,$profile-id,$resp-type, ())
    )
};

(:~ declare that $identifier is responsible for $attribute 
 : with responsibility type $resp-type and locus $locus
 : Note that these are not indexed properly. 
 :)
declare function resp:add-attribute(
  $attribute as attribute(),
  $resp-type as xs:string,
  $identifier as xs:string,
  $locus as xs:string
  ) {
  (: does the element have @xml:id? if not, error :)
  if (not($resp-type=$resp:valid-responsibility-types))
  then
    (: is the resp-type valid? if not, error :)
    error(xs:QName("err:INPUT"), concat(
      "The responsibility type must be selected from: ",
      string-join($resp:valid-responsibility-types, ",")))
  else 
    let $profile-id := 
      local:get-public-profile($attribute/parent::*, $identifier)      
    let $doc := root($attribute)
    return (
      update insert 
        element tei:respons {
          attribute locus { $locus },
          attribute resp { $profile-id },
          attribute j:role { $resp-type },
          attribute match {
            app:xpath($attribute)
          }
        }
        into $doc//j:respList 
      (: , this kind of resp is not indexed yet, but could be
      local:collapse-ranges($doc,$profile-id,$resp-type):)
    )
};


(:~ declare that $identifier is no longer considered responsible 
 : for $resp-type on $node 
 :)
declare function resp:remove(
  $node as element(), 
  $resp-type as xs:string?,
  $identifier as xs:string
  ) {
  let $doc := root($node)
  where $node/@xml:id
  return
    let $profile-id := local:public-profile-by-id($node, $identifier)
    let $resp-to-remove := resp:query($node, $resp-type)[@resp=$profile-id]
    where exists($resp-to-remove)
    return (
      (#exist:batch-transaction#) {
        for $resp in $resp-to-remove
        let $targets := 
          uri:follow-uri($resp/@target/string(), $resp, uri:follow-steps($resp))
          except $node
        return (
          update insert 
            local:make-ranges($targets, (), (), 
              $resp-type, $resp/@locus/string(), $profile-id, ()) 
              into $doc//j:respList
        ),
        update delete $resp-to-remove
      },
      local:collapse-ranges($doc, $profile-id, $resp-type, ())
    )
};

(:~ remove all responsibility references to a node
 :)
declare function resp:remove(
  $node as element()
  ) {
  let $doc := root($node)
  where $node/@xml:id
  return
    let $resp-to-remove := resp:query($node)
    let $profile-ids := $resp-to-remove/@resp/string()
    let $resp-types := $resp-to-remove/@j:role/string()
    return (
      (# exist:batch-transaction #) {
        for $resp in $resp-to-remove
        let $targets :=
         uri:follow-uri($resp/@target/string(), $resp, uri:follow-steps($resp))
         except $node
        return
          update insert local:make-ranges($targets, (), (),
            $resp/@j:role/string(), $resp/@locus/string(), 
            $resp/@resp/string(), $node) into $doc//j:respList,
        update delete $resp-to-remove
      },
      if (exists($resp-to-remove))
      then local:collapse-ranges($doc, $profile-ids, $resp-types, $node)
      else ()
    )
};
