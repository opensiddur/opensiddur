xquery version "1.0";

(:~ application-global functions 
 :
 : mostly authentication issues.
 :
 : Open Siddur Project
 : Copyright 2010-2013 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later 
 :)
module namespace app="http://jewishliturgy.org/modules/app";

import module namespace debug="http://jewishliturgy.org/transform/debug"
    at "debug.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
    at "../magic/magic.xqm";

declare namespace expath="http://expath.org/ns/pkg";
declare namespace error="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";

(:~ @return server version as a string :)
declare function app:get-version(
	) as xs:string {
	collection(repo:get-root())//expath:package[@name = "http://jewishliturgy.org/apps/opensiddur-server"]/@version/string()
};

(:~ Authenticate and return authenticated user.  
 : HTTP Basic authentication and Username/Password in header takes priority
 : over the logged in user. :)
declare function app:auth-user()
  as xs:string? {
  (session:get-attribute('app.user'),
  let $id := sm:id()
  return ($id//sm:effective, $id//sm:real)[1]/sm:username/string()[not(. = 'guest')])[1]
};

(:~ Return authenticated user's password; only works for HTTP Basic authentication :)
declare function app:auth-password()
  as xs:string? {
  (session:get-attribute('app.password'))[1]
};

(:~ make a collection path that does not exist; (like mkdir -p)
 : create new collections with the given mode, owner and group
 : @param $path directory path
 : @param $origin path begins at
 : @param $permissions an sm:permission document
 :)
declare function app:make-collection-path(
  $path as xs:string, 
  $origin as xs:string,
  $permissions as document-node()
  ) as empty-sequence() {
  let $origin-sl := 
    if (ends-with($origin, '/'))
    then $origin
    else concat($origin, '/')
  let $path-no-sl :=
    if (starts-with($path, '/'))
    then substring($path, 2)
    else $path
  let $first-part := substring-before($path-no-sl, '/')
  let $second-part := substring-after($path-no-sl, '/')
  let $to-create := 
    if ($first-part) 
    then $first-part 
    else $path-no-sl
  return
    if ($to-create)
    then 
      let $current-col := concat($origin-sl, $to-create)
      return (
        if (xmldb:collection-available($current-col))
        then 
          debug:debug($debug:detail, "app", ($current-col, ' already exists'))
        else (
          debug:debug($debug:detail, "app", ($origin-sl, $to-create, ' creating')),
          let $path := xmldb:create-collection($origin-sl, $to-create)
          return
            if ($path)
            then app:copy-permissions(xs:anyURI($path),$permissions)
            else error(xs:QName('error:CREATE'), concat('Cannot create collection', $origin-sl, $to-create))
        ),
        if ($second-part) 
        then app:make-collection-path($second-part, $current-col, $permissions)
        else ()
        )
    else ()
};

(:~ concatenate two components together as a path, making sure that the result
 : is separated by a / :)
declare function app:concat-path(
  $a as xs:string,
  $b as xs:string
  ) as xs:string {
  let $a-s := 
    if (ends-with($a,'/'))
    then $a
    else concat($a, '/')
  let $b-s :=
    if (starts-with($b, '/'))
    then substring($b, 2)
    else $b
  return
    concat($a-s, $b-s)
};

(:~ concatenate a sequence of strings together as a path :)
declare function app:concat-path(
  $a as xs:string+
  ) as xs:string {
  let $n := count($a)
  return
  	if ($n = 1)
  	then $a
  	else if ($n = 2)
  	then app:concat-path($a[1], $a[2])
  	else app:concat-path((subsequence($a,1,$n - 2), app:concat-path($a[$n - 1], $a[$n])))
};

(:~ store login credentials in the session 
 : @param $user login username
 : @param $password login password
 :) 
declare function app:login-credentials(
	$user as xs:string,
	$password as xs:string
	) as empty-sequence() {
	if (session:exists())
	then (
	  session:set-attribute('app.user', $user),
	  session:set-attribute('app.password', $password)
	)
	else ()
};

(:~ remove login credentials from the session :)
declare function app:logout-credentials(
	) as empty-sequence() {
	if (session:exists())
	then 
	  let $guest-login := xmldb:login("/db", "guest", "guest")
	  return session:invalidate()
	else ()
};

(: return an XPath that points to the given node :)
declare function app:xpath(
  $node as node()?
  ) as xs:string? {
  string-join((
    let $p := $node/parent::node()
    where exists($p) 
    return
      if (not($p instance of document-node()))
      then app:xpath($p)
      else "",
    typeswitch ($node)
    case document-node() 
    return "/"
    case element() 
    return
      let $nn := node-name($node)
      return concat(
        $nn,
        let $ctp := count($node/preceding-sibling::element()[node-name(.)=$nn])
        let $ctf := count($node/following-sibling::element()[node-name(.)=$nn])
        where ($ctp + $ctf) > 0 
        return concat("[", $ctp + 1, "]")
      )
    case text() 
    return concat(
      "text()",
      let $ctp := count($node/preceding-sibling::text())
      let $ctf := count($node/following-sibling::text())
      where ($ctp + $ctf) > 0 
      return concat("[", $ctp + 1, "]")
    )
    case attribute() return concat("@", node-name($node))
    case comment() 
    return concat(
      "comment()",
      let $ctp := count($node/preceding-sibling::comment())
      let $ctf := count($node/following-sibling::comment())
      where ($ctp + $ctf) > 0 
      return concat("[", $ctp + 1, "]")
    )
    case processing-instruction() 
    return 
      let $nn := node-name($node)
      return
        concat(
          "processing-instruction(", $nn, ")",
          let $ctp := count($node/preceding-sibling::processing-instruction()[node-name(.)=$nn])
          let $ctf := count($node/following-sibling::processing-instruction()[node-name(.)=$nn])
          where ($ctp + $ctf) > 0 
          return concat("[", $ctp + 1, "]")
        ) 
    default return ()
  ), "/"
  )
};

(:~ copy permissions from $permissions to $dest 
 : @param $permissions A permissions document from sm:get-permissions()
 :)
declare function app:copy-permissions(
  $dest as xs:anyAtomicType,
  $permissions as document-node()
  ) as empty-sequence() {
  let $dest := $dest cast as xs:anyURI
  let $owner := $permissions/*/@owner/string()
  let $group := $permissions/*/@group/string()
  let $mode := $permissions/*/@mode/string() 
  return 
    system:as-user("admin", $magic:password,
    (
      sm:chmod($dest, $mode),
      sm:chgrp($dest, $group),
      sm:chown($dest, $owner),
      sm:clear-acl($dest),  (: clear ACE, so we can just copy everything :)
      for 
        $acl in $permissions/*/sm:acl,
        $ace in $acl/sm:ace
      let $who := $ace/@who/string()
      let $allowed := $ace/@access_type = "ALLOWED"
      let $mode := $ace/@mode/string()
      order by $ace/@index/number()
      return
        if ($ace/@target="USER")
        then sm:add-user-ace($dest, $who, $allowed, $mode)
        else sm:add-group-ace($dest, $who, $allowed, $mode)
    )
  )
};

(:~ set the permissions of the path $dest to 
 : be equivalent to the permissions of the path $source
 :)
declare function app:mirror-permissions(
  $source as xs:anyAtomicType,
  $dest as xs:anyAtomicType
  ) as empty-sequence() {
  let $source := $source cast as xs:anyURI
  let $permissions := sm:get-permissions($source) 
  return app:copy-permissions($dest, $permissions)
};