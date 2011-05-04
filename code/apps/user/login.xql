xquery version "1.0";
(: login.xql 
 : Perform a login or logout action
 : accepts a parameter action=login or action=logout.
 : If a user doesn't exist on the db, but does on the wiki, create the db user  
 : Return a login instance for XForms. 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: login.xql 708 2011-02-24 05:40:58Z efraim.feinstein $
 :) 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace err="http://jewishliturgy.org/apps/errors";

import module namespace util="http://exist-db.org/xquery/util";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace app="http://jewishliturgy.org/modules/app"
	at "../../modules/app.xqm";
import module namespace user="http://jewishliturgy.org/modules/user"
	at "../../modules/user.xqm";
import module namespace wiki="http://jewishliturgy.org/modules/wiki"
	at "../../modules/wiki.xqm";

let $data := request:get-data()
return
  util:catch('*',
    let $action := request:get-parameter('action','')
    return ( 
      <login>{
      if ($action = 'login')
      then
        let $name := $data/name
        let $password := $data/password
        let $db-user-exists := xmldb:exists-user($name)
        let $wiki-user-exists := $db-user-exists or wiki:valid-user($name, $password)
        let $user-exists-or-created := 
          $db-user-exists or (
            if (not($db-user-exists) and $wiki-user-exists)
            then user:create($name, $password)='ok'
            else false()
          )
        return
          if ($user-exists-or-created and xmldb:login('/db', $name, $password, true() ))
          then (
          	<loggedin>{string($name)}</loggedin>,
          	<name>{string($name)}</name>,
          	<password>{string($password)}</password>,
          )
          else error(xs:QName('err:LOGIN'), 'Invalid login on wiki and database')
      else if ($action = 'logout')
      then (
        session:invalidate(),
        let $loggedout := xmldb:login('/db','guest','guest', true())
        	or error(xs:QName('err:INTERNAL'), 'Cannot log you out by logging in as guest.')
        return (
        	<loggedin/>,
        	<name/>,
        	<password/>
        	)
        )
      else ((: no action, just copy what we got in or query current login. :)
      	let $name := app:auth-user() 
      	let $password := ()
      	return (
	        <loggedin>{$name}</loggedin>,
	        <name>{$name}</name>,
	        <password>{$password}</password>
        )
      )
      }
      </login>
      ),
      (: result if error :)
      <login>
        <loggedin/>
        <name>{string($data/name)}</name>
        <password>{string($data/password)}</password>
        {app:error-message()}
      </login>
     
  )
