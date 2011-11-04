xquery version "1.0";

module namespace apitest="http://jewishliturgy.org/modules/apitest";

declare variable $apitest:server := concat('http://', request:get-server-name(), ':', request:get-server-port());

declare function apitest:clear() {
  httpclient:clear-all()
};

declare function apitest:get($uri as xs:string, $headers as element()*) {
  httpclient:get(xs:anyURI(concat($apitest:server, $uri)), true(), 
    element headers { $headers })
};

declare function apitest:post($uri as xs:string, $headers as element()*, $content as item()) {
  httpclient:post(xs:anyURI(concat($apitest:server, $uri)), $content, true(), 
  <headers>{$headers}</headers>)
};

declare function apitest:put($uri as xs:string, $headers as element()*, $content as item()) {
  httpclient:post(xs:anyURI(concat($apitest:server, $uri)), $content, true(), 
    <headers>
      {$headers}
      <header name="X-HTTP-Method-Override" value="PUT"/>
    </headers>)
};

declare function apitest:delete($uri as xs:string, $headers as element()*) {
  httpclient:post(xs:anyURI(concat($apitest:server, $uri)), "",
    true(), 
    <headers>
      {$headers}
      <header name="X-HTTP-Method-Override" value="DELETE"/>
    </headers>)
};

