xquery version "3.0";
(: API module for demos 
 : 
 : Functions assume that the following has already been done:
 :  authentication,
 :  content negotiation
 : 
 : Copyright 2012-2013,2018 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed Under the GNU Lesser General Public License, version 3 or later
 :)
module namespace demo="http://jewishliturgy.org/api/demo";

import module namespace translit="http://jewishliturgy.org/api/utility/translit"
  at "/db/apps/opensiddur-server/api/utility/translit.xqm";

declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(:~ index function for the demo services 
 : @return An HTML list of available demo service APIs
 :)
declare 
  %rest:GET
  %rest:path("/api/demo")
  %rest:produces("application/xhtml+xml", "application/xml", "text/html", "text/xml")
  %output:method("xhtml")
  function demo:list(
  ) as item()+ {
  translit:list()
};

(:~ list all available transliteration demos
 : @deprecated in favor of [[translit:transliteration-list]]
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
  %output:method("xhtml")
  function demo:transliteration-list(
    $q as xs:string*,
    $start as xs:integer*,
    $max-results as xs:integer*
  ) as item()+ {
  translit:transliteration-list($q, $start, $max-results)
};


(:~ post arbitrary XML for transliteration by a given schema
 : @deprecated
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
  translit:transliterate-xml($body, $schema)
};

(:~ Transliterate plain text
 : @deprecated
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
    $body as xs:base64Binary,
    $schema as xs:string
    ) as item()+ {
  translit:transliterate-text($body, $schema)
};
