xquery version "1.0";
(: passthrough kluge to avoid an eXist bug where an XML resource
 : won't be loaded if it's protected through authentication
 : unless via XQuery 
 :
 : $Id: passthrough.xql 706 2011-02-21 01:18:10Z efraim.feinstein $
 :)

declare option exist:serialize "method=xml";

let $doc := request:get-parameter('doc',()) 
return (
	util:log-system-out(('passthrough for ', $doc, ' as ', xmldb:get-current-user())),
  doc($doc)
)
