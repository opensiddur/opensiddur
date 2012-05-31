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
import module namespace tran="http://jewishliturgy.org/api/transliteration"
  at "xmldb:exist:///code/api/data/transliteration.xqm";
  
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
  let $tr-element := $transliterated/*/j:parallelGrp/j:parallel/*
  return 
    element { 
      QName(namespace-uri($tr-element), name($tr-element)) 
    }{
      $tr-element/(
        @* except @xml:lang,
        parent::j:parallel/@xml:lang,
        node()
      )
    }
};

declare 
  %rest:GET
  %rest:path("/api/demo")
  %rest:produces("application/xhtml+xml", "application/xml", "text/html", "text/xml")
  %output:method("html5")
  function demo:list(
  ) as item()+ {
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Demo API index</title>
    </head>
    <body>
      <ul class="apis">
        {
        (: TODO: replace request:get-uri() with rest:get-absolute-uri() :)
        let $api-base := request:get-uri()
        return
          <li class="api">
            <a class="discovery" href="{$api-base}/transliteration">Transliteration</a>
          </li>
        }
      </ul>
    </body>
  </html>
};

declare 
  %rest:GET
  %rest:path("/api/demo/transliteration")
  %rest:query-param("q", "{$query}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$count}", 100)  
  %rest:produces("application/xhtml+xml", "application/xml", "text/html", "text/xml")
  %output:method("html5")
  function demo:transliteration-list(
    $query as xs:string,
    $start as xs:integer,
    $count as xs:integer
  ) as item()+ {
  let $list := tran:list($query, $start, $count)
  return
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Transliteration demo API</title>
      {$list//head/(* except title)}
    </head>
    <body>
      <p>This API supports HTTP POST only.</p>
      <p>If you POST some data to be transliterated to 
      /api/demo/<i>schema-name</i>, where you can choose a schema from
      <a href="/api/data/transliteration">any transliteration schema</a>,
      you will get back a transliterated version.</p>
      <ul class="results">
      {
        for $li in $list//li[@class="result"]
        return
          <li class="result">
            <a class="document" href="{replace($li/a[@class="document"]/@href, "/data/", "/demo/")}">{
              $li/a[@class="document"]/node()
            }</a>
          </li>
      }
      </ul>
    </body>
  </html>
};


(:~ post arbitrary XML for transliteration by a given schema 
 : @return XML of the same structure 
 :)
declare  
  %rest:POST("{$body}")
  %rest:path("/api/demo/transliteration/{$schema}")
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
  %rest:path("/api/demo/transliteration/{$schema}")
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