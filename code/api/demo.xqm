xquery version "3.0";
(: API module for demos 
 : 
 : Functions assume that the following has already been done:
 :  authentication,
 :  content negotiation
 : 
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed Under the GNU Lesser General Public License, version 3 or later
 :)
module namespace demo="http://jewishliturgy.org/api/demo";

import module namespace api="http://jewishliturgy.org/modules/api"
  at "xmldb:exist:///code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "xmldb:exist:///code/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "xmldb:exist:///code/api/modules/data.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "xmldb:exist:///code/modules/format.xqm";
  
declare namespace rest="http://exquery.org/ns/rest/annotation/";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

(:~ transliterate the given data, which is wrapped in XML :)
declare function local:transliterate(
  $data as element(),
  $schema as xs:string
  ) as node()* {
  let $user := app:auth-user()
  let $password := app:auth-password()
  let $data-with-selected-schema :=
    (: default language is Hebrew; a different language can 
     : be specified by the data
     :)
    <jx:relationship type="set" xml:lang="he">
      <jx:linked-relationship>
        <tei:fs type="Transliterator">
          <tei:f name="Table">
            <tei:symbol value="{$schema}"/>
          </tei:f>
          <tei:f name="Alignment-Namespace">
            <tei:string>{namespace-uri($data)}</tei:string>
          </tei:f>
          <tei:f name="Alignment-Element">
            <tei:string>{local-name($data)}</tei:string>
          </tei:f>
        </tei:fs>
      </jx:linked-relationship>
      {$data}
    </jx:relationship>
  let $transliterated :=
    format:transliterate($data-with-selected-schema, $user, $password)
  return $transliterated/*/j:parallelGrp/j:parallel/*
};

(:~ post arbitrary XML for transliteration by a given schema 
 : @return XML of the same structure 
 :)
declare  
  %rest:POST("{$body}")
  %rest:path("/demo/transliteration/{$schema}")
  %rest:consumes("application/xml")
  %rest:produces("application/xml", "text/xml")
  function demo:transliterate-xml(
    $body as document-node(),
    $schema as xs:string
  ) as item()* {
  let $schema-exists := data:doc("transliteration", $schema)
  return
    if ($schema-exists)
    then
      let $transliterated := local:transliterate($body/*, $schema)
      return $transliterated
    else
      api:rest-error(404, "Schema cannot be found", $schema)
};

declare 
  %rest:POST("{$body}")
  %rest:path("/demo/transliteration/{$schema}")
  %rest:consumes("text/plain")
  %rest:produces("text/plain")
  function demo:transliterate-text(
    $body as item(),
    $schema as xs:string
    ) as item()+ {
    let $text :=
      typeswitch($body)
      case xs:base64Binary
      return util:binary-to-string($body)
      default return $body
    let $transliterated := 
      demo:transliterate-xml(
        document {
          <transliterated xml:lang="he">{
            $text
          }</transliterated>
        },$schema)
    return
      if ($transliterated[2] instance of element(error))
      then $transliterated
      else (
        <rest:response>
          <output:serialization-parameters>
            <output:method value="text"/>
          </output:serialization-parameters>
        </rest:response>,
        data($transliterated)
      )
};