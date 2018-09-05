xquery version "3.1";
(:~ general support functions for the REST API
 :
 : Open Siddur Project
 : Copyright 2011-2014,2018 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :) 
module namespace api="http://jewishliturgy.org/modules/api";

declare default element namespace "http://www.w3.org/1999/xhtml"; 

declare namespace http="http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace rerr="http://exquery.org/ns/restxq/error";

declare variable $api:default-max-results := 50;

(:~ output an API error and set the HTTP response code
 : for RESTXQ 
 : @param $status-code return status
 : @param $message return message (text preferred, but may contain XML)
 : @param $object (optional) error object
 : @return an error element if the status code >= 400, otherwise an info element
 :)
declare function api:rest-error(
  $status-code as xs:integer?,
  $message as item()*, 
  $object as item()*
  ) as item()+ {
  <rest:response>
    <output:serialization-parameters>
      <output:method>xml</output:method>
    </output:serialization-parameters>
    <http:response status="{$status-code}"/>
  </rest:response>,
  element { QName("", if ($status-code lt 400) then "info" else "error") } {
    element { QName("", "path") } {
      if (request:exists())
      then request:get-uri()
      else 
        try {
            rest:uri()
        }
        catch rerr:RQDY0101 { (: called from non-RESTXQ context :)
            ""
        }
    },
    element { QName("", "message") } {$message},
    if (exists($object))
    then
      element { QName("", "object") }{$object}
    else ()
  }
};

declare function api:rest-error(
  $status-code as xs:integer?,
  $message as item()*
  ) as item()+ {
  api:rest-error($status-code, $message, ())
};

(:~ @return a valid root-relative HTTP path for a given API :)
declare function api:uri-of(
  $api as xs:string?
  ) as xs:string {
  try {
    concat(rest:base-uri(), $api)
  }
  catch rerr:RQDY0101 { (: not in a restxq context :)
    $api
  }
};
