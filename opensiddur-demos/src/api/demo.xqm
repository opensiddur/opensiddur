xquery version "3.0";
(: API module for demos 
 : 
 : Functions assume that the following has already been done:
 :  authentication,
 :  content negotiation
 : 
 : Copyright 2012-2013 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed Under the GNU Lesser General Public License, version 3 or later
 :)
module namespace demo="http://jewishliturgy.org/api/demo";

import module namespace api="http://jewishliturgy.org/modules/api"
  at "/db/apps/opensiddur-server/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "/db/apps/opensiddur-server/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "/db/apps/opensiddur-server/modules/data.xqm";
import module namespace translit="http://jewishliturgy.org/transform/transliterator"
  at "/db/apps/opensiddur-server/transforms/translit/translit.xqm";
import module namespace tran="http://jewishliturgy.org/api/transliteration"
  at "/db/apps/opensiddur-server/api/data/transliteration.xqm";
  
declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(:~ transliterate the given data, which is wrapped in XML :)
declare function local:transliterate(
  $data as element(),
  $schema as document-node()
  ) as node()* {
  let $in-lang := ($data/@xml:lang/string(), "he")[1]
  let $out-lang := $in-lang || "-Latn"
  let $table := $schema/tr:schema/tr:table[tr:lang[@in=$in-lang][@out=$out-lang]]
  let $transliterated := translit:transliterate($data, map { "translit:table" := $table })
  return 
    element { 
      QName(namespace-uri($transliterated), name($transliterated)) 
    }{
      $transliterated/(
        @* except @xml:lang,
        attribute xml:lang { $out-lang },
        node()
      )
    }
};

(:~ index function for the demo services 
 : @return An HTML list of available demo service APIs
 :)
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
        let $api-base := api:uri-of("/api/demo")
        return (
          (:<li class="api">
            <a class="discovery" href="{$api-base}/stml">STML</a>
          </li>,:)
          <li class="api">
            <a class="discovery" href="{$api-base}/transliteration">Transliteration</a>
          </li>
        )
        }
      </ul>
    </body>
  </html>
};

(:~ list all available transliteration demos
 : @param $query Limit the search to a particular query
 : @param $start Start the list at the given item number
 : @param $max-results Show this many results 
 : @return An HTML list of all transliteration demos that match the given query
 :)
declare 
  %rest:GET
  %rest:path("/api/demo/transliteration")
  %rest:query-param("q", "{$q}", "")
  %rest:query-param("start", "{$start}", 1)
  %rest:query-param("max-results", "{$max-results}", 100)  
  %rest:produces("application/xhtml+xml", "application/xml", "text/html", "text/xml")
  %output:method("html5")
  function demo:transliteration-list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
  ) as item()+ {
  let $q := string-join(($q[.]), " ")
  let $start := $start[1]
  let $count := $max-results[1]
  let $list := tran:list($q, $start, $count)
  return
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Transliteration demo API</title>
      {$list//head/(* except title)}
    </head>
    <body>
      <p>This API supports HTTP POST only.</p>
      <p>If you POST some data to be transliterated to 
      {api:uri-of("/api/demo/")}<i>schema-name</i>, where you can choose a schema from
      <a href="{api:uri-of('/api/data/transliteration')}">any transliteration schema</a>,
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
 : @param $schema The schema to transliterate using 
 : @return XML of the same structure, containing transliterated text. Use @xml:lang to specify which table should be used. 
 : @error HTTP 404 Transliteration schema not found
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
      let $transliterated := local:transliterate($body/*, $schema-exists)
      return $transliterated
    else
      api:rest-error(404, "Schema cannot be found", $schema)
};

(:~ Transliterate plain text
 : @param $body The text to transliterate, which is assumed to be Hebrew
 : @return Transliterated plain text
 : @error HTTP 404 Transliteration schema not found
 :)
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
