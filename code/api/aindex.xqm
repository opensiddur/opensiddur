xquery version "3.0";
(:~ access and sharing API index
 : Mirrors the data index for all data types that have possible 
 : access restrictions
 : 
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace aindex = 'http://jewishliturgy.org/api/access/index';

import module namespace dindex="http://jewishliturgy.org/api/data/index"
  at "/code/api/data/dindex.xqm";

declare namespace rest="http://exquery.org/ns/rest/annotation/";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace error="http://jewishliturgy.org/errors"; 


(:~ access API index functions 
 :)
declare
  %rest:GET
  %rest:path("/api/access")
  %rest:produces("application/xhtml+xml", "application/xml", "text/xml", "text/html")
  %output:method("html5")
  function aindex:list(
  ) as item() {
  let $base := request:get-uri()
  (: TODO: replace request:get-uri() with rest:get-absolute-uri():)
  return
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head>
        <title>Access API index</title>
      </head>
      <body>
        <ul class="results">
          <li class="result">
            <a class="discovery" href="{$base}/transliteration">Transliteration</a>
          </li>
        </ul>
      </body>
    </html>
};

