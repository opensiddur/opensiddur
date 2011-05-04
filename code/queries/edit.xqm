xquery version '1.0';
(:~ 
 : Editing API
 : Copyright 2010 Efraim Feinstein 
 : Released under the GNU Lesser General Public License version 3 or later
 : $Id: edit.xqm 491 2010-03-28 03:40:29Z efraim.feinstein $
 :)
module namespace edit = 'http://jewishliturgy.org/ns/functions/edit';

import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";

import module namespace app="http://jewishliturgy.org/ns/functions/app";
import module namespace jvalidate="http://jewishliturgy.org/ns/functions/validation";

declare namespace edit='http://jewishliturgy.org/ns/functions/edit';

(: Pointer to a resource that holds the active contexts as XML like:
 : <edit:contexts>
 :  <edit:context>
 :   <edit:source>...</edit:source>
 :   <edit:ref>...</edit:ref>
 :   <edit:owner>...</edit:owner>
 :   <edit:expiry>...</edit:expiry>
 :  </edit:context>+
 : </edit:contexts> :)
declare variable $edit:active-contexts := '/db/opensiddur/__contexts__.xml';

(: pointer to a JLPTEI template :)
declare variable $edit:new-file-template := '/db/opensiddur/template.xml';

(: How much time an edit context is allowed before it expires :)
declare variable $edit:expiry-timeout := xs:dayTimeDuration("P0DT0H5M0S");

(:~ return the record of the current editing context, or empty if none :)
declare function edit:_current_edit_context()
  as element(edit:context)? {
  let $document := document-uri(root(.))
  return
    doc($edit:active-contexts)//edit:context[string(edit:ref)=$document]
};

(:~ determine if the current user has edit permissions :)
declare function edit:_has_permissions() 
  as xs:boolean {
  let $document := root(.)
  let $collection := util:collection-name($document)
  let $resource := util:document-name($document)
  let $owner := xmldb:get-owner($collection, $resource)
  let $group := xmldb:get-group($collection, $resource)
  let $current-user := xmldb:get-current-user()
  let $current-groups := xmldb:get-user-groups($current-user) 
  return
    ($current-user eq $owner) or ($current-groups = $group)
};

(:~ edit:source for current context :)
declare function edit:source() 
  as element(edit:context)? {
  string(edit:_current_edit_context()/edit:ref)
};

(:~ Open an editing context for a new document :)
declare function edit:new(
  $uri as xs:string) 
  as element(report) {
  let $authenticated := app:authenticate()
    or error(xs:QName('edit:ERR_NOT_AUTHORIZED'),'Authentication failed.')
  let $auth-user := app:auth-user()
  let $collection := util:collection-name($uri)
  let $collection-owner := xmldb:get-owner($collection)
  let $collection-group := xmldb:get-group($collection)
  let $current-groups := xmldb:get-user-groups($auth-user)
  let $collection-permissions := xmldb:permissions-to-string(xmldb:get-permissions($collection))
  let $has-collection-permissions :=
    (($auth-user = $collection-owner) and contains(substring($collection-permissions,1,3),'w'))
    or
    (($current-groups = $collection-group) and contains(substring($collection-permissions,4,3),'w'))
    or
    (contains(substring($collection-permissions,7,3),'w'))
    or
    error(xs:QName('edit:ERR_NOT_AUTHORIZED'),'No write permission to the collection.') 
  let $resource := util:document-name($uri)
  let $user-collection := xmldb:get-user-home($auth-user)
  let $active-contexts := doc($edit:active-contexts)/edit:contexts
  let $context-for-this as element(edit:context)* := 
    $active-contexts/edit:context[string(edit:source)=$uri]
  let $cleaned-context := 
    for $c-f-t in $context-for-this
    return
      if (xs:time($c-f-t/edit:expiry) gt current-time())
      then error(xs:QName('edit:ERR_CONFLICT'), 
        string-join(('Document ', $uri, ' is being edited by ', 
          string($c-f-t/edit:owner), ' until ', 
          string($c-f-t/edit:expiry), '.'),''))
      else edit:clean($c-f-t)
  return
    if (doc-available($uri))
    then error(xs:QName('edit:ERR_EXISTS'), 'Document exists')
    else 
      let $new-context-uri-collection := concat($user-collection, '/contexts')
      let $new-context-uri-collection-exists := 
        xmldb:collection-available($new-context-uri-collection) 
        or
        boolean(
          (xmldb:create-collection($user-collection, 'contexts'),
          xmldb:set-collection-permissions($new-context-uri-collection, 
            $auth-user, $auth-user, util:base-to-integer(0700,8))))
      let $new-context-uri-resource := concat(util:uuid(),'.xml')
      let $new-context-uri := 
        if ($new-context-uri-collection-exists)
        then
          (
          xmldb:store($new-context-uri-collection, $new-context-uri-resource, doc($edit:new-file-template)),
          xmldb:chmod-resource($new-context-uri-collection, $new-context-uri-resource,
            util:base-to-integer(0700,8)))
        else
          error(xs:QName('edit:ERR_NEW'), 'Collection error')
      return
        if (not($new-context-uri))
        then error(xs:QName('edit:ERR_NEW'), 'New file error') 
        else (
          update insert 
            <edit:context>
              <edit:source>{$uri}</edit:source>
              <edit:ref>{$new-context-uri}</edit:ref>
              <edit:owner>{$auth-user}</edit:owner>
              <edit:expiry>{current-time() + $edit:expiry-timeout}</edit:expiry>
            </edit:context>
            into $active-contexts,
          <report>
            <status>ok</status>
            <uri>{$new-context-uri}</uri>
          </report>
      )
}; 

(:~ Open the context document for editing.  
 : @return A report element with the message containing status='ok' and return/xs:anyURI
 : or message/failure message
 :)
declare function edit:open()
  as element(report) {
  let $auth-ok := app:authenticate() 
    or error(xs:QName('edit:ERR_NOT_AUTHORIZED'),'You must be logged in to edit.')
  let $user-name := app:auth-user() 
  let $user-collection := xmldb:get-user-home($user-name)
  let $edit-permission := edit:_has_permissions() or 
    error (xs:QName('edit:ERR_PERMISSION'),'You do not have edit permissions for this file')
  let $active-contexts := doc($edit:active-contexts)
  let $current-context-uri := document-uri(root(.))
  let $source-context := $active-contexts//edit:context[string(edit:source)=$current-context-uri]
  let $now := current-time()
  return
    if (xs:time($source-context/edit:expiry) gt $now)
    then
      error(xs:QName('edit:ERR_BUSY'), 
        string-join(($current-context-uri,
          ' is opened for editing by ', 
          string($source-context/edit:owner), 
          ' until ',
          string($source-context/edit:expiry),
          '.'),''))
    else (
      if ($source-context)
      then 
        (: remove expired source context :)
        let $ref := string($source-context/edit:ref)
        let $collection := util:collection-name($ref)
        let $resource := util:document-name($ref)
        return (
          xmldb:remove($collection, $resource),
          update delete $source-context
        )
      else (),
      (: add new source context :)
      let $new-context-uri-collection := concat($user-collection, '/contexts')
      let $new-context-uri-resource := concat(util:uuid(),'.xml')
      let $new-context-uri := 
        (xmldb:store($new-context-uri-collection, $new-context-uri-resource, root(.)),
        xmldb:chmod-resource($new-context-uri-collection, $new-context-uri-resource,
          util:base-to-integer(0700,8)))
      return
        if (not($new-context-uri))
        then error(xs:QName('edit:ERR_COPY'), 'Copying error') 
        else (
          update insert 
            <edit:context>
              <edit:source>{$current-context-uri}</edit:source>
              <edit:ref>{$new-context-uri}</edit:ref>
              <edit:owner>{$user-name}</edit:owner>
              <edit:expiry>{$now + $edit:expiry-timeout}</edit:expiry>
            </edit:context>
            into $active-contexts/edit:contexts,
          <report>
            <status>ok</status>
            <uri>{$new-context-uri}</uri>
          </report>
        )
      )
};

(: renew a context to prevent its expiration :)
declare function edit:renew() 
  as element(report) {
  let $context := edit:_current_edit_context()
  let $authenticated := app:authenticate()
  let $auth-user := 
    if ($authenticated)
    then app:auth-user()
    else error(xs:QName('edit:ERR_NOT_AUTHORIZED'), 'Authentication required.')
  let $owner := string($context/edit:owner)
  let $owner-is-authed := 
    if (not($context))
    then 
      (error(xs:QName('edit:ERR_NOT_CONTEXT'),'The URI is not an editing context.'), false())
    else ($auth-user = $owner) 
      or error(xs:QName('edit:ERR_NOT_AUTHORIZED'),
        string-join(('Not authorized. The context is owned by ',$owner,' and you are ', $auth-user,'.'),''))
  let $new-expiry := current-time() + $edit:expiry-timeout
  return
    if ($owner-is-authed) 
    then
      (update value $context/edit:expiry with $new-expiry, 
      <report>
        <status>ok</status>
      </report>)
    else 
      (: we should never get here :)
      <report>
        <status>error</status>
      </report>
};

(:~ Commit the changes to the context document [an edit context] to 
 : its original source document :)
declare function edit:commit() 
  as element(report) {
  let $doc-node := root(.)
  let $context := $doc-node/edit:_current_edit_context()
  let $authenticated := app:authenticate() or
    error(xs:QName('edit:ERR_NOT_AUTHORIZED'),'Not authenticated.')
  let $auth-user := app:auth-user()
  let $owner := string($context/edit:owner)
  let $source := string($context/edit:source)
  let $report := jvalidate:validate-jlptei($doc-node)
  let $collection := util:collection-name($source)
  let $resource := substring-after($source, concat($collection,'/')) (: FAIL: util:document-name($source) :)
  return 
    if (not($context))
    then error(xs:QName('edit:ERR_NOT_CONTEXT'),'Not a context.')
    else if (not($owner = $auth-user))
    then error(xs:QName('edit:ERR_NOT_AUTHORIZED'),'Context is not owned by you.')
    else if (not(jvalidate:validation-boolean($report)))
    then error(xs:QName('edit:ERR_INVALID'),$report)
    else (util:log-system-out(('COMMIT: ', $source, ' ', $collection, ' ', $resource, ' ')),
      if (
        not((
        (if (doc-available($source))  
        then xmldb:chmod-resource($collection, $resource, util:base-to-integer(0700, 8))
        else () (: committing a new document :) ),
        xmldb:store($collection, $resource, $doc-node), 
        xmldb:chmod-resource($collection, $resource, util:base-to-integer(0444, 8))))
      )
      then
        error(xs:QName('edit:ERR_SAVE'),'Cannot save resource.') 
      else 
        $doc-node/edit:renew()
      )
};


(:~ close $context without committing :)
declare function edit:close()
  as element(report) {
  let $context-record := edit:_current_edit_context()
  let $collection := util:collection-name(string($context-record/edit:ref))
  let $resource := util:document-name(string($context-record/edit:ref))
  let $authenticated := app:authenticate()
  let $user := app:auth-user()
  let $owner := string($context-record/edit:owner) 
  return
    if (not($context-record))
    then
      error(xs:QName('edit:ERR_NOT_CONTEXT'),'Not an editing context.')
    else if (not($authenticated) or 
      (not(xmldb:is-admin-user($user)) and not($user = $owner)))
    then
      error(xs:QName('edit:ERR_NOT_AUTHORIZED'), 
        string-join(('The context is owned by ', $owner, '. You are ', $user, '.'),''))
    else (
        xmldb:remove($collection, $resource),
        update delete $context-record,
        <report>
          <status>ok</status>
        </report>  
    ) 
};

(:~ remove expired edit contexts owned by the active user :)
declare function edit:clean()
  as xs:boolean {
  let $authenticated := app:authenticate() or
    error(xs:QName('err:NOT_AUTHORIZED'),'Not authenticated.')
  let $my-expired-contexts := doc($edit:active-contexts)//edit:context
    [edit:owner=app:auth-user() and (xs:time(edit:expiry) lt current-time())]
  return ((
    for $expired in $my-expired-contexts
    return
      edit:clean($expired)
  ), true())
};

(:~ clean a specific expired context :)
declare function edit:clean(
  $context as element(edit:context)) 
  as xs:boolean {
  let $authenticated := app:authenticate() or
    error(xs:QName('err:NOT_AUTHORIZED'),'Not authenticated.')
  return (
    if (xs:time($context/edit:expiry) lt current-time())
    then
      let $ref := string($context/edit:ref)
      let $collection := util:collection-name($ref)
      let $resource := util:document-name($ref)
      return (
        xmldb:remove($collection, $resource),
        update delete $context,
        true()
      )
    else 
      false()
  )
  
};