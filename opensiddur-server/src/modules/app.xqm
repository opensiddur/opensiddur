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
import module namespace paths="http://jewishliturgy.org/modules/paths"
    at "paths.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
    at "../magic/magic.xqm";

declare namespace exist="http://exist.sourceforge.net/NS/exist";
declare namespace xsl="http://www.w3.org/1999/XSL/Transform";
declare namespace error="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";
declare namespace expath="http://expath.org/ns/pkg";

declare variable $app:repo-base := 
  let $descriptor := 
    collection(repo:get-root())//expath:package[@name = "http://jewishliturgy.org/apps/opensiddur-server"]
  return
    util:collection-name($descriptor);

(:~ @return server version as a string :)
declare function app:get-version(
	) as xs:string {
	collection(repo:get-root())//expath:package[@name = "http://jewishliturgy.org/apps/opensiddur-server"]/@version/string()
};

(:~ return decoded authorization string (username, password) or empty 
 : This will probe (in the following order)for:
 : HTTP Basic authentication information
 : 'Authorization' session attribute (containing the HTTP-basic like auth string)
 : 'Authorization' session cookie (containing the HTTP-basic-like auth string)
 : 'user' and 'password' request parameters 
 : 'Username' and 'password' headers    
 :)
declare function local:get-auth-string() as xs:string* {
  if (request:exists())
  then 
    let $authorization := (substring-after(request:get-header('Authorization'),'Basic '))[.]
      cast as xs:base64Binary?
    let $user-name-attribute := session:get-attribute('app.user')[.]
    let $password-attribute := session:get-attribute('app.password')[.]
    let $auth-cookie := request:get-cookie-value('Authorization')[.]
    let $user-name-basic := substring-before(
        util:binary-to-string(($authorization, $auth-cookie)[1]),
        ':')[.]
    let $password-basic := substring-after(
        util:binary-to-string(($authorization, $auth-cookie)[1]),
        ':')[.]
    (: user name and password from the header.  BUG workaround: to get around a bug in betterform 3.1, need to take the last 
     : comma separated value :)
    let $user-name-hdr := tokenize(request:get-header('Username'),',')[last()][.]
    let $password-hdr := tokenize(request:get-header('Password'),',')[last()][.]
    (: last resort: user name and password from parameters user= and password= :)
    let $user-name-param := request:get-parameter('user',())
    let $password-param := request:get-parameter('password',())
    (: return values :)
    let $username := ($user-name-basic, $user-name-hdr, $user-name-attribute, $user-name-param)[1]
    let $password := ($password-basic, $password-hdr, $password-attribute, $password-param)[1]
    return (
      debug:debug(
        $debug:info,
        "app",
        <authenticate>
          <uri>{request:get-uri()}</uri>
          <header>{$authorization, exists($authorization)}</header>
          <attribute>{$user-name-attribute, exists($user-name-attribute)}</attribute>
          <cookie>{$auth-cookie, exists($auth-cookie)}</cookie>
          <hdr>{$user-name-hdr, $password-hdr, exists($user-name-hdr)}</hdr>
          <user-param>{$user-name-param, $password-param, exists($user-name-param)}</user-param>
          <return>
            <user>{$username}</user>
            <password>{$password}</password>
          </return>
        </authenticate>
      ),
      $username, $password)
  else ()
};

(:~ Authenticate and return authenticated user.  
 : HTTP Basic authentication and Username/Password in header takes priority
 : over the logged in user. :)
declare function app:auth-user()
  as xs:string? {
  (session:get-attribute('app.user'), xmldb:get-current-user()[not(. = 'guest')], local:get-auth-string()[1])[1]
};

(:~ Return authenticated user's password; only works for HTTP Basic authentication :)
declare function app:auth-password()
  as xs:string? {
  (session:get-attribute('app.password'), local:get-auth-string()[2])[1]
};

(:~ make a collection path that does not exist; (like mkdir -p)
 : create new collections with the given mode, owner and group
 : @param $path directory path
 : @param $origin path begins at
 : @param $owner owner user of any new collections
 : @param $group owner group of any new collections
 : @param $mode permissions mode of any new collections
 : @deprecated Replaced by app:make-collection-path(..., $permissions)
 :)
declare function app:make-collection-path(
	$path as xs:string, 
	$origin as xs:string,
	$owner as xs:string,
	$group as xs:string,
	$mode as xs:string) 
	as empty() {
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
				then (
					if ($paths:debug)
					then
						util:log-system-out(($current-col, ' already exists'))
					else ()
				)
				else (
					if ($paths:debug)
					then
						util:log-system-out(($origin-sl, $to-create, ' creating'))
					else (),
					if (xmldb:create-collection($origin-sl, $to-create))
					then (
					  sm:chown(xs:anyURI($current-col), $owner),
					  sm:chgrp(xs:anyURI($current-col), $group),
					  sm:chmod(xs:anyURI($current-col), $mode)
					)
					else error(xs:QName('error:CREATE'), concat('Cannot create collection', $origin-sl, $to-create))
				),
				if ($second-part) 
				then app:make-collection-path($second-part, $current-col, $owner, $group, $mode)
				else ()
				)
		else ()
};

(:~ make a collection path that does not exist; (like mkdir -p)
 : create new collections with the given mode, owner and group
 : @param $path directory path
 : @param $origin path begins at
 : @param $permissions an sm:permissions document
 :)
declare function app:make-collection-path(
  $path as xs:string, 
  $origin as xs:string,
  $permissions as document-node(element((:sm:permissions:)))
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



(:~ perform an XSLT transformation stored in the database on a document stored in the database
 : This function is a kluge 
 : @param $document-uri Pointer to the document in the database, *must* be absolute relative to db
 : 	Alternatively, if $document-uri contains a node(), the node() is transformed
 : @param $xslt-uri Pointer to the XSLT in the database, *must* be absolute relative to db
 : @param $parameters Parameters to pass to the XSLT (user and password parameters can be passed here)
 : @param $mode mode to execute; use empty sequence or blank string for #default
 :)
declare function app:transform-xslt(
  $document-uri as item(),
  $xslt-uri as xs:string,
  $parameters as element(param)*,
  $mode as xs:string?
  ) as item()* {
  let $xslt-uri-abs := 
    if (contains($xslt-uri,':'))
    then (: already an absolute path with protocol :) $xslt-uri 
    else app:concat-path($paths:rest-prefix, $xslt-uri)
  let $user := (app:auth-user(), $parameters[@name='user']/@value/string())[1]
  let $password := (app:auth-password(), $parameters[@name='password']/@value)[1]
  let $absolute-uri :=
    if ($document-uri instance of xs:anyAtomicType)
    then
      concat('xmldb:exist://', 
        if ($user)
        then concat($user,':',$password,'@')
        else '', 
        $document-uri)
    else ()
  let $xslt :=
    <xsl:stylesheet 
      xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
      xmlns:app="http://jewishliturgy.org/modules/app"
      version="2.0"
      exclude-result-prefixes="app">
        
      <xsl:param name="uri-map" as="document-node()">
        <xsl:document>
          <uri-map xmlns="">{
            let $user-password :=
              if ($user)
              then concat($user, ":", $password, "@")
              else ""
            for $document in collection(("/data","/code"))
              [namespace-uri(*)="http://www.tei-c.org/ns/1.0"]
              [not(contains(document-uri(.), "/output/"))]
            let $doc-uri := document-uri($document)
            return
              <map 
                from="{($document/*/@jx:document-uri, $doc-uri)[1]}" 
                to="xmldb:exist://{$user-password}{$doc-uri}">
                <cache type="fragmentation" to="xmldb:exist://{$user-password}@{replace($doc-uri, '/db', '/db/cache')}"/>
              </map>
          }</uri-map>              
        </xsl:document>
      </xsl:param>
      <xsl:include href="{$xslt-uri-abs}"/>
      <xsl:template match="app:root">
      	<xsl:variable name="to-apply" as="document-node()">{
      		if ($document-uri instance of node())
      		then
      			<xsl:document>{$document-uri}</xsl:document>
      		else 
      			attribute {'select'}{concat('doc("', $absolute-uri, '")')}
        }</xsl:variable>
        <xsl:apply-templates select="$to-apply">
        {
        if ($mode) 
        then attribute {'mode'}{$mode}
        else ()
        }
        </xsl:apply-templates>
      </xsl:template>
    </xsl:stylesheet>
  return (
    debug:debug($debug:detail, 
      "app", 
      string-join(("Running XSLT (as ", $user, ":", $password, "=", 
        xmldb:get-current-user(), ") ", 
        $xslt-uri-abs, " on ", 
        if ($document-uri instance of node()) 
        then "node" 
        else $absolute-uri), "")), 
    transform:transform(<app:root/>, $xslt, (
    	if ($parameters or $user) 
    	then 
    		<parameters>{
    			$parameters, 
    			if ($user) 
    			then (
    				<param name="user" value="{$user}"/>,
    				<param name="password" value="{$password}"/> 
    			)
    			else ()
    		}</parameters>
    	else ()
    	)
    )
  )
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

(:~ copy permissions from $permissions to $dest :)
declare function app:copy-permissions(
  $dest as xs:anyAtomicType,
  $permissions as document-node(element((:sm:permissions:)))
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