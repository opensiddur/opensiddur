xquery version "1.0";
(: api to check for user existence or list available profile resources
 : 
 : Method: GET
 : Return: 
 :		200 + menu (list available data types)
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
import module namespace response="http://exist-db.org/xquery/response";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare namespace err="http://jewishliturgy.org/errors";

declare option exist:serialize "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes 
        doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
        doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd";

declare variable $local:test-uri := "/code/tests/api/data/data.t.xml";

declare function local:get(
	) as element() {
	let $base := '/code/api/data'
	let $list := 
		<ul class="common">{
      api:list-item("Contributor lists",
        concat($base, "/contributors"), 
        ("GET", "POST"),
        api:html-content-type(),
        api:tei-content-type("tei:div")
      ),
      api:list-item("Original texts",
        concat($base, "/original"),
        "GET",
        api:html-content-type(),
        ()
      ),
      api:list-item("Parallel text tables",
        concat($base, "/parallel"),
        "GET",
        api:html-content-type(),
        ()
      ),
      api:list-item("Bibliographic data",
        concat($base, "/sources"),
        ("GET", "POST"),
        api:html-content-type(),
        api:tei-content-type("tei:biblStruct")
      ),
      api:list-item("Translation texts",
        concat($base, "/translation"),
        ("GET"),
        api:html-content-type(),
        ()
      ),
      api:list-item("Transliteration tables",
        concat($base, "/transliteration"),
        ("GET"),
        api:html-content-type(),
        ()
      ),
      api:list-item("Generated output",
        concat($base, "/output"),
        ("GET"),
        api:html-content-type(),
        ()
      )
		}</ul>
	return
		api:list(
			<title>Open Siddur Data API</title>,
			$list,
			0 (: the list here is a common menu, not results, so the number of results = 0 :),
      false(),
      "GET",
      api:html-content-type(),
      (),
      $local:test-uri
		)
}; 

(
api:tests($local:test-uri),
if (api:allowed-method('GET'))
then
	(: $user-name the user name in the request URI :)
  local:get()
else
	(: disallowed method :) 
	()
)[1]
