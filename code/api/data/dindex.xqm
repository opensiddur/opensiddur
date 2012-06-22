xquery version "3.0";
(: API module for functions for index URIs 
 : 
 : Functions assume that the following has already been done:
 :  authentication,
 :  content negotiation
 : 
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed Under the GNU Lesser General Public License, version 3 or later
 :)
module namespace dindex = 'http://jewishliturgy.org/api/data/index';

declare namespace rest="http://exquery.org/ns/rest/annotation/";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace o="http://a9.com/-/spec/opensearch/1.1/";

(:~ list all available data APIs :)
declare 
  %rest:GET
  %rest:path("/api/data")
  %rest:produces("application/xhtml+xml", "text/html", "application/xml", "text/xml")
  function dindex:list(
  ) as item()+ {
  <rest:response>
    <output:serialization-parameters>
      <output:method value="html5"/>
    </output:serialization-parameters>
  </rest:response>,
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Open Siddur API Index</title>
    </head>
    <body>
      <ul class="apis">
        <li class="api">
          <a class="discovery" href="{request:get-uri()}/original">Original data</a>
        </li>
        <li class="api">
          <a class="discovery" href="{request:get-uri()}/sources">Sources (Bibliographic data)</a>
        </li>
        <li class="api">
          {((: TODO: replace request:get-uri() with rest:get-absolute-uri() 
            :))}
          <a class="discovery" href="{request:get-uri()}/transliteration">Transliteration</a>
        </li>
      </ul>
    </body>
  </html>
};

declare 
  %rest:GET
  %rest:path("/api/data/OpenSearchDescription")
  %rest:query-param("source", "{$source}", "")
  %rest:produces("application/opensearchdescription+xml","application/xml","text/xml")
  function dindex:open-search(
  $source as xs:string
  ) as item()+ {
  <rest:response>
    <output:serialization-parameters>
      <output method="xml"/>
    </output:serialization-parameters>
  </rest:response>,
  <o:OpenSearchDescription
    xmlns:jsearch="http://jewishliturgy.org/ns/search">
    <o:ShortName>Open Siddur Search</o:ShortName>
    <o:Description>Full text search of Open Siddur texts.</o:Description>
    <o:Tags>siddur</o:Tags>
    <o:Contact>efraim@opensiddur.org</o:Contact>
    <o:Url type="application/xhtml+xml" 
      template="{$source}?q={{searchTerms}}&amp;start={{startIndex?}}&amp;max-results={{count?}}"
    />
  </o:OpenSearchDescription>
};
