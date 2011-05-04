xquery version "1.0";
(: just echo whatever is posted :) 
declare option exist:serialize "method=xml media-type=application/xml";

<data>
<desc>Echoed data:</desc>
{
request:get-data()
}</data>