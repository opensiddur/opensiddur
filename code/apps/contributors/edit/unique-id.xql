(:~ unique-id.xql
 : Determine if the parameter 'id' refers to a unique xml:id in the contributor list
 : return <unique>true|false</unique>
 : 
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3
 : $Id: unique-id.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
xquery version "1.0";

import module namespace common="http://jewishliturgy.org/apps/contributors/common"
	at "../modules/common.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

let $data := request:get-data()
let $contrib-list := 
  if (doc-available($common:list))
  then doc($common:list)//tei:div[@type='contributors']/tei:list
  else ()
let $found := $contrib-list/id($data/current-id)
let $is-unique := 
	string(empty($found) or (not($data/is-new = 'true') and ($data/current-id = $data/original-id)))
return
	<unique xmlns="">{
		$is-unique
	}</unique>
