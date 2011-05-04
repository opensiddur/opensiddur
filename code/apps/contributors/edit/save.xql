xquery version "1.0";
(: Contributors list saver
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: save.xql 709 2011-02-24 06:37:44Z efraim.feinstein $
 :)
import module namespace app="http://jewishliturgy.org/modules/app"
	at "../../../modules/app.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "../../../modules/paths.xqm";
import module namespace common="http://jewishliturgy.org/apps/contributors/common"
	at "../modules/common.xqm";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace cc="http://web.resource.org/cc/";
declare namespace err="http://jewishliturgy.org/errors";

declare option exist:serialize "method=xhtml media-type=text/xml indent=no process-pi-xsl=no";

let $original-data := request:get-data()
return
util:catch('*',
  let $edit-id as xs:string? := request:get-parameter('id','')
  let $data as element(tei:list) :=
    app:contract-data($original-data, true())
  let $expanded as element(tei:list) := 
    <tei:list>{
      app:expand-prototype($data, $common:prototype, true())
    }</tei:list>
  let $user := app:auth-user()
  let $contrib-template as element(tei:TEI) :=
    <tei:TEI>
      <tei:teiHeader>
        <tei:fileDesc>
          <tei:titleStmt>
            <tei:title xml:lang="en">Global contributors list</tei:title>
          </tei:titleStmt>
          <tei:publicationStmt>
            <tei:availability status="free">
              <tei:p xml:lang="en" xmlns="http://www.tei-c.org/ns/1.0">
                To the extent possible under law, the contributors who associated
                <tei:ref type="license" target="http://www.creativecommons.org/publicdomain/zero/1.0">Creative Commons Zero
                </tei:ref>
                with this work have waived all copyright and related or neighboring rights to this work.
              </tei:p>
              <rdf:RDF>
                <cc:License rdf:about="http://creativecommons.org/publicdomain/zero/1.0/">
                  <cc:legalcode
                    rdf:resource="http://creativecommons.org/publicdomain/zero/1.0/legalcode" />
                  <cc:permits rdf:resource="http://creativecommons.org/ns#Reproduction" />
                  <cc:permits rdf:resource="http://creativecommons.org/ns#Distribution" />
                </cc:License>
              </rdf:RDF>
            </tei:availability>
          </tei:publicationStmt>
          <tei:sourceDesc>
            <tei:bibl><tei:p>Born digital</tei:p></tei:bibl>
          </tei:sourceDesc>
        </tei:fileDesc>
      </tei:teiHeader>
      <tei:text>
        <tei:body>
          <tei:div type="contributors">
            {$data}    						
          </tei:div>
        </tei:body>
      </tei:text>
    </tei:TEI>
  return (
    if ($edit-id and count($data/tei:item) > 1)
    then
      error(xs:QName('err:INVALID'), 'You may only provide a $id parameter if you are changing the identifier of a single item.')
    else if (not($user))
    then
      error(xs:QName('err:LOGIN'), concat('Not logged in. $user=', $user))
    else if (doc-available($common:list))
    then
      let $contrib-doc := doc($common:list)
      return
        (: save is an update of an existing file :)
        for $item in $data/tei:item
        let $replace-item := 
          if ($edit-id)
          then $contrib-doc/id($edit-id)
          else $contrib-doc/id($item/@xml:id)
        let $list := $contrib-doc//tei:div[@type='contributors']/tei:list
        return
          if ($replace-item)
          then update replace $replace-item with $item
          else update insert $item into $list
    else ( (: save means creating a new contributor list :)
      app:make-collection-path(
        $common:collection, '/db', 'admin',	'everyone', util:base-to-integer(0775,8)),
      if (xmldb:store($common:collection, $common:resource, $contrib-template))
      then (
        xmldb:set-resource-permissions(
          $common:collection, $common:resource, 
          $user,
          'everyone',
          util:base-to-integer(0775, 8)),
          $data)
      else error(xs:QName('err:SAVE'), 'Cannot store!')
    ),
    util:log-system-out(('original id = ', $edit-id,' incoming data = ', $data, ' outgoing data=', $expanded )),
    $expanded
    )
  ,
  (: on error, return back what we got in with an error message :)
  (
  <tei:list>{
    app:expand-prototype($original-data, $common:prototype, true()),
    app:error-message()
  }</tei:list>  
  )
)
