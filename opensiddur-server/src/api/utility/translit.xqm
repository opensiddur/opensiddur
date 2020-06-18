xquery version "3.1";
(: Utility API for transliteration
 :
 : Functions assume that the following has already been done:
 :  authentication,
 :  content negotiation
 : TODO: change the GET API to return lists of table/from/to combinations
 : TODO: change the POST API to /api/utility/translit?table=&from=&to= 
 :
 : Copyright 2012-2013,2018 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed Under the GNU Lesser General Public License, version 3 or later
 :)

module namespace translit = "http://jewishliturgy.org/api/utility/translit";


import module namespace api="http://jewishliturgy.org/modules/api"
    at "/db/apps/opensiddur-server/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
at "/db/apps/opensiddur-server/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
at "/db/apps/opensiddur-server/modules/data.xqm";
import module namespace xlit="http://jewishliturgy.org/transform/transliterator"
    at "../../transforms/translit/translit.xqm";
import module namespace tran="http://jewishliturgy.org/api/transliteration"
    at "../data/transliteration.xqm";

declare namespace tr="http://jewishliturgy.org/ns/tr/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(:~ transliterate the given data, which is wrapped in XML :)
declare function local:transliterate(
        $data as element(),
        $table as element(tr:table),
        $out-lang as xs:string
) as node()* {
    let $transliterated := xlit:transliterate($data, map { "translit:table" : $table })
    return
        element {
            QName(namespace-uri($transliterated), name($transliterated))
        }{
            $transliterated/(
                @* except @xml:lang,
                attribute xml:lang { $out-lang },
                node()
            )
        }
};


(:~ list all available transliteration demos
 : @param $query Limit the search to a particular query
 : @param $start Start the list at the given item number
 : @param $max-results Show this many results
 : @return An HTML list of all transliteration demos that match the given query
 :)
declare
    %rest:GET
    %rest:path("/api/utility/translit")
    %rest:query-param("q", "{$q}", "")
    %rest:query-param("start", "{$start}", 1)
    %rest:query-param("max-results", "{$max-results}", 100)
    %rest:produces("application/xhtml+xml", "application/xml", "text/html", "text/xml")
    %output:method("xhtml")
    function translit:transliteration-list(
        $q as xs:string*,
        $start as xs:integer*,
        $max-results as xs:integer*
    ) as item()+ {
    let $q := string-join(($q[.]), " ")
    let $start := $start[1]
    let $count := $max-results[1]
    let $list := tran:list($q, $start, $count)
    return
        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
                <title>Transliteration utility API</title>
                {$list//head/(* except title)}
            </head>
            <body>
                <p>This API supports HTTP POST only.</p>
                <p>If you POST some data to be transliterated to
                {api:uri-of("/api/utility/translit/")}<i>schema-name</i>, where you can choose a schema from
                <a href="{api:uri-of('/api/data/transliteration')}">any transliteration schema</a>,
                you will get back a transliterated version.</p>
                <ul class="results">
                {
                    for $li in $list//li[@class="result"]
                    return
                    <li class="result">
                        <a class="document" href="{replace($li/a[@class="document"]/@href, "/data/", "/utility/translit/")}">{
                            $li/a[@class="document"]/node()
                        }</a>
                    </li>
                }
                </ul>
            </body>
        </html>
};


(:~ post arbitrary XML for transliteration by a given schema
 : @param $schema The schema to transliterate using
 : @return XML of the same structure, containing transliterated text. Use @xml:lang to specify which table should be used.
 : @error HTTP 404 Transliteration schema not found
 : @error HTTP 400 table not found
 :)
declare
    %rest:POST("{$body}")
    %rest:path("/api/utility/translit/{$schema}")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
    function translit:transliterate-xml(
        $body as document-node(),
        $schema as xs:string
    ) as item()* {
    let $schema-exists := data:doc("transliteration", $schema)
    let $in-lang := ($body/*/@xml:lang/string(), "he")[1]
    let $out-lang := $in-lang || "-Latn"
    let $table-exists := $schema-exists/tr:schema/tr:table[tr:lang[@in=$in-lang][@out=$out-lang]]
    return
        if ($table-exists)
        then
            let $transliterated := local:transliterate($body/*, $table-exists, $out-lang)
            return $transliterated
        else if ($schema-exists)
        then
            api:rest-error(400, "Table cannot be found to transliterate " || $in-lang || " to " || $out-lang, $schema)
        else
            api:rest-error(404, "Schema cannot be found", $schema)
};

(:~ Transliterate plain text
 : @param $body The text to transliterate, which is assumed to be Hebrew
 : @return Transliterated plain text
 : @error HTTP 404 Transliteration schema not found
 : @error HTTP 400 Transliteration table not found
 :)
declare
    %rest:POST("{$body}")
    %rest:path("/api/utility/translit/{$schema}")
    %rest:consumes("text/plain")
    %rest:produces("text/plain")
    function translit:transliterate-text(
        $body as xs:base64Binary,
        $schema as xs:string
    ) as item()+ {
        let $text := util:binary-to-string($body)
        let $transliterated :=
            translit:transliterate-xml(
                document {
                    <transliterated xml:lang="he">{
                        $text
                    }</transliterated>
                }, $schema)
        return
            if ($transliterated[2] instance of element(error))
            then $transliterated
            else (
                <rest:response>
                    <output:serialization-parameters>
                        <output:method>text</output:method>
                    </output:serialization-parameters>
                </rest:response>,
                data($transliterated)
            )
};
