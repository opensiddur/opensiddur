xquery version "1.0";

module namespace apitest="http://jewishliturgy.org/modules/apitest";

declare variable $apitest:server := concat('http://', request:get-server-name(), ':', request:get-server-port());

declare function apitest:clear() {
  httpclient:clear-all()
};

declare function apitest:auth-header(
  $user as xs:string,
  $password as xs:string
  ) as element(header) {
  element header {
    attribute name { "Authorization" },
    attribute value { concat("Basic ", util:base64-encode(concat($user, ":", $password))) } 
  }
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

(: $content is in <httpclient:field.../> :)
declare function apitest:post-form(
  $uri as xs:string, 
  $headers as element()*,
  $content as element()*
  ) {
  httpclient:post-form(xs:anyURI(concat($apitest:server, $uri)),
    <fields>{
      $content
    }</fields>,
    true(),
    <headers>
      {$headers}
    </headers>
  )
};

(: $content is in <httpclient:field.../> :)
declare function apitest:put-form(
  $uri as xs:string, 
  $headers as element()*,
  $content as element()*
  ) {
  httpclient:post-form(xs:anyURI(concat($apitest:server, $uri)),
    element httpclient:fields { $content },
    true(),
    <headers>
      {$headers}
      <header name="X-HTTP-Method-Override" value="PUT"/>
    </headers>
  )
};
  

declare function apitest:delete($uri as xs:string, $headers as element()*) {
  httpclient:post(xs:anyURI(concat($apitest:server, $uri)), "",
    true(), 
    <headers>
      {$headers}
      <header name="X-HTTP-Method-Override" value="DELETE"/>
    </headers>)
};

