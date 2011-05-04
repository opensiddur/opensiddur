xquery version "1.0";
(:~ delete.xql 
 : delete a contributor from the list (be careful!)
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 : $Id: delete.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)

import module namespace app="http://jewishliturgy.org/modules/app" 
	at "../../../modules/app.xqm";
import module namespace common="http://jewishliturgy.org/apps/contributors/common"
	at "../modules/common.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace err="http://jewishliturgy.org/errors";

(:~ find references to the given id.  If any are found, return them.
 : TODO: find references within the text
 :)
declare function local:find-references(
  $id as xs:string) 
  as element(tei:item)* {
  let $contrib-list := doc($common:list)//tei:div[@type='contributors']/tei:list
  return 
    for $item in $contrib-list/tei:item[ft:query(tei:affiliation/tei:ptr/@target, $id)]
    order by ft:score($item) descending
    return $item
};

util:catch('*',
  let $id := request:get-parameter('id','')
  let $logged-in := app:authenticate() or
    error(xs:QName('err:LOGIN'), 'Not logged in.')
  let $contrib-list := doc($common:list)//tei:div[@type='contributors']/tei:list
  return (
    if ($id)
    then (
      let $references := local:find-references($id)
      return
        if (empty($references))
        then (
          update delete $contrib-list/id($id),
          <ok/>
        )
        else 
          error(xs:QName('err:REFERENCED'), 
            concat('Cannot delete "', $id, '" because it is referenced by other contributor entries: ', 
              string-join(for $xid in $references/@xml:id return concat('"',string($xid),'"'), ',')))
      )
    else	
      error(xs:QName('err:INVALID'), concat('Invalid parameter id="',$id,'".'))
  ),
  <errors xmlns="">{
    app:error-message()
  }</errors>
)	
