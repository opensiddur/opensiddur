xquery version "3.0";
(: STML demo service 
 : 
 : Copyright 2012 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed Under the GNU Lesser General Public License, version 3 or later
 :)
module namespace stdemo="http://jewishliturgy.org/api/demo/stml";

import module namespace api="http://jewishliturgy.org/modules/api"
  at "xmldb:exist:///code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
  at "xmldb:exist:///code/modules/app.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "xmldb:exist:///code/modules/debug.xqm";
import module namespace stml="http://jewishliturgy.org/transform/stml"
  at "xmldb:exist:///code/input-conversion/rawtext/stml.xqm";
  
declare namespace rest="http://exquery.org/ns/rest/annotation/";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";

(:~ @return an HTML page that allows POSTing to this URL  
 :)
declare 
  %rest:GET
  %rest:path("/api/demo/stml")
  %output:method("html5")
  function stdemo:get(
  ) as item()* {
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>STML Demo Service</title>
      {((: yes, this really does need JS in order to submit
       text/plain without prepending x= to it
       :))}
      <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js"></script>
      <script type="text/javascript">//<![CDATA[
      var submitIt = function() {
        $("#status").html("Converting...");
        $.ajax({
                  url: "/api/demo/stml",
                  type: "POST",
                  contentType: "text/plain",
                  dataType: "xml",
                  data: $("#code").val(),
                  processData: false,
                  success: function(data, textStatus, jqXHR) {
                    $("#output").text(jqXHR.responseText); 
                    $("#status").html("Done")
                  },
                  error: function(jqXHR, errorType, exceptionObject) {
                    alert("Submission error: " + errorType)
                  }
                });
      };
      
      $(document).ready(
        function(){
          $("#submission").click(submitIt);
        }
      );
      //]]></script>
    </head>
    <body>
      <h1>STML Input Conversion Demo</h1>
      <fieldset>
        <label for="code">Enter the STML code here:</label>
        <br/>
        <textarea id="code" cols="80" rows="20"></textarea>
        <br/>
        <button id="submission">Convert</button>
        <p id="status"/>
        <pre id="output"/>
      </fieldset>
    </body>
  </html>
};

(:~ Convert text STML to multi-file XML  
 : @param $body STML text
 : @return The STML text converted into multi-part XML files, each of which is enclosed in an stml:files/stml:file element
 : @error HTTP 400 An error occurred during conversion
 :)
declare 
  %rest:POST("{$body}")
  %rest:path("/api/demo/stml")
  %rest:consumes("text/plain")
  %output:method("xml")
  function stdemo:post-text(
    $body as xs:string
  ) as item()+ {
  try {
    element stml:files {
      stml:convert-text($body)
    }
  }
  catch * {
    api:rest-error(400, 
      "Error during STML conversion", 
      debug:print-exception(
        $err:module, $err:line-number, $err:column-number,
        $err:code, $err:value, $err:description)) 
  }
};