xquery version "3.0";
(: Utility API index
 :
 :
 : Copyright 2012-2013,2018 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed Under the GNU Lesser General Public License, version 3 or later
 :)

module namespace uindex = "http://jewishliturgy.org/api/utility";

import module namespace api="http://jewishliturgy.org/modules/api"
    at "../../modules/api.xqm";

declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(:~ index function for the demo services
 : @return An HTML list of available demo service APIs
 :)
declare
    %rest:GET
    %rest:path("/api/utility")
    %rest:produces("application/xhtml+xml", "application/xml", "text/html", "text/xml")
    %output:method("xhtml")
    function uindex:list(
) as item()+ {
    <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
            <title>Utility API index</title>
        </head>
        <body>
            <ul class="apis">
                {
                    let $api-base := api:uri-of("/api/utility")
                    return (
                        <li class="api">
                            <a class="discovery" href="{$api-base}/translit">Transliteration</a>
                        </li>
                    )
                }
            </ul>
        </body>
    </html>
};

