xquery version "3.0";
(: pre-install setup script 
 :
 : Open Siddur Project
 : Copyright 2010-2013 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
 
(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare variable $local:supported-languages := ("en", "he");
    

(: from XQuery wikibook :)
declare function local:mkcol-recursive($collection, $components) {
  if (exists($components)) 
  then
    let $newColl := concat($collection, "/", $components[1])
    return (
      if (xmldb:collection-available($newColl))
      then ()
      else xmldb:create-collection($collection, $components[1]),
      local:mkcol-recursive($newColl, subsequence($components, 2))
    )
  else
    ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
  local:mkcol-recursive($collection, tokenize($path, "/")[.])
};

declare function local:mkgroup($name) {
  if (sm:group-exists($name))
  then ()
  else xmldb:create-group($name, "admin")
};

declare function local:mkcollection(
  $collection as element(collection),
  $system-config-base as xs:string
  ) {
  let $path := string-join($collection/ancestor-or-self::*[@name]/@name, "/")
  let $tokens := tokenize($path, "/")
  let $parent := subsequence($tokens, 1, count($path) - 1)
  let $collection-name := $tokens[last()]
  let $config-path := concat($system-config-base, $path)
  let $package-config-path := replace($config-path, "/__target__", $target)
  let $owner := $collection/ancestor-or-self::*[@owner][1]/@owner/string()
  let $group := $collection/ancestor-or-self::*[@group][1]/@group/string()
  let $permissions := $collection/ancestor-or-self::*[@perms][1]/@perms/string()
  return (
    util:log-system-out('make collection ' || $path),
    (: make collection :)
    local:mkcol("/db", substring-after($path, "/db")),
    (: (re)set permissions :)
    util:log-system-out('setting permissions for ' || $path),
    sm:clear-acl(xs:anyURI($path)),
    sm:chown(xs:anyURI($path), $owner),
    sm:chgrp(xs:anyURI($path), $group),
    sm:chmod(xs:anyURI($path), $permissions),
    (: store configuration :)
    util:log-system-out('making configuation collection for ' || $path),
    local:mkcol("/db" || $system-config-base, $path),
    util:log-system-out('storing configuration for ' || $path || ' to ' || $config-path || ' from ' || concat($dir, $package-config-path)),
    xmldb:store-files-from-pattern(
      $config-path, concat($dir, $package-config-path), "*.xconf"
    ),
    util:log-system-out('finished processing ' || $path)
  ),
  (: recurse :)
  for $subcollection in $collection/collection
  return local:mkcollection($subcollection, $system-config-base)
};

declare function local:mkcollections(
  $collections as element(collections),
  $system-config-base as xs:string
  ) {
  for $collection in $collections/collection
  return local:mkcollection($collection, $system-config-base)
};

declare function local:lang-collections(
  ) {
  local:lang-collections(())
};

declare function local:lang-collections(
  $additional-langs as xs:string*
  ) {
  for $lang in ($local:supported-languages, $additional-langs)
  return
    <collection name="{$lang}"/>
};

(: make the 'everyone' group if it does not exist :)
util:log-system-out('making groups...'),
local:mkgroup("everyone"),
util:log-system-out('making collections...'),
(: make collections and store the collection configurations
 : from the package
 :)
let $owner := "admin"
let $group := "everyone"
let $permissions := "rwxrwxr-x"
let $collections := 
  <collections owner="admin" group="everyone" perms="rwxrwxr-x">
    <collection name="/db" owner="admin" group="dba">
      <collection name="refindex" owner="admin" group="everyone" perms="rwxr-xr-x"/>
      <collection name="data" owner="admin" group="everyone" perms="rwxr-xr-x">
        <collection name="conditionals" perms="rwxrwxr-x"/>
        <collection name="dictionaries" perms="rwxrwxr-x">{local:lang-collections()}</collection>
        <collection name="linkage" perms="rwxrwxr-x">{local:lang-collections("none")}</collection>
        <collection name="notes" perms="rwxrwxr-x">{local:lang-collections()}</collection>
        <collection name="original" perms="rwxrwxr-x">{local:lang-collections()}</collection>
        <collection name="sources" perms="rwxrwxr-x"/>
        <collection name="styles" perms="rwxrwxr-x">{local:lang-collections()}</collection>
        <collection name="transliteration" perms="rwxrwxr-x"/>
        <collection name="user" perms="rwxrwxr-x"/>
      </collection>
    </collection>
    <collection name="{$target}" group="dba">
      <collection name="magic" owner="admin" group="dba"/>
      <collection name="static"/>
    </collection>
  </collections>
return  
  local:mkcollections($collections, "/system/config"),
util:log-system-out('done')
