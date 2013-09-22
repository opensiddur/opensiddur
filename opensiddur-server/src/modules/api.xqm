xquery version "3.0";
(:~ general support functions for the REST API
 :
 : Open Siddur Project
 : Copyright 2011-2013 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :) 
module namespace api="http://jewishliturgy.org/modules/api";

declare default element namespace "http://www.w3.org/1999/xhtml"; 

declare namespace http="http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare variable $api:default-max-results := 50;

(:~ output an API error and set the HTTP response code
 : for RESTXQ 
 : @param $status-code return status
 : @param $message return message (text preferred, but may contain XML)
 : @param $object (optional) error object
 :)
declare function api:rest-error(
  $status-code as xs:integer?,
  $message as item()*, 
  $object as item()*
  ) as item()+ {
  <rest:response>
    <output:serialization-parameters>
      <output:method value="xml"/>
    </output:serialization-parameters>
    <http:response status="{$status-code}"/>
  </rest:response>,
  <error xmlns="">
    <path>{
      if (request:exists())
      then request:get-uri()
      else rest:uri()
    }</path>
    <message>{$message}</message>
    {
      if (exists($object))
      then
        <object>{$object}</object>
      else ()
    }
  </error>
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
