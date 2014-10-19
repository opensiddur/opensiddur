xquery version "3.0";
(:~ API module for recent changes
 : 
 : Copyright 2014 Efraim Feinstein <efraim@opensiddur.org>
 : Open Siddur Project
 : Licensed Under the GNU Lesser General Public License, version 3 or later
 :)
module namespace chg = 'http://jewishliturgy.org/api/changes';

import module namespace api="http://jewishliturgy.org/modules/api"
  at "../modules/api.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "../modules/data.xqm";


declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace o="http://a9.com/-/spec/opensearch/1.1/";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare function chg:get-recent-changes(
    $type as xs:string?,
    $by as xs:string?,
    $from as xs:string?,
    $to as xs:string?
    ) as node()* {
    let $username := $by 
    let $c := collection(string-join((
        "/db/data",
        $type[.]
        ), "/"))
    return
        (: all empty :)
        if (empty($by) and empty($from) and empty($to))
        then $c//tei:change
        (: $by empty :)
        else if (empty($by) and empty($to))
        then $c//tei:change[@when ge $from]
        else if (empty($by) and empty($from))
        then $c//tei:change[@when le $to]
        else if (empty($by))
        then $c//tei:change[@when ge $from][@when le $to]
        (: $from empty :)
        else if (empty($from) and empty($to))
        then $c//tei:change[@who=$username]
        else if (empty($from))
        then $c//tei:change[@who=$username][@when le $to]
        (: $to empty :)
        else if (empty($to))
        then $c//tei:change[@who=$username][@when ge $from]
        (: no empty :)
        else $c//tei:change[@who=$username][@when ge $from][@when le $to]
};

(:~ List all recent changes 
 : @param $by List only changes made by the given user. List all users if omitted.
 : @param $from List only changes made on or after the given date/time. No restriction if omitted. The expected format is yyyy-mm-ddThh:mm:ss, where any of the smaller sized components are optional.
 : @param $to List only changes made on or before the given date/time. No restriction if omitted.
 : @param $start Start the list from the given index
 : @param $max-results List only this many results
 : @return An HTML list
 :)
declare 
    %rest:GET
    %rest:path("/api/changes")
    %rest:query-param("type", "{$type}")
    %rest:query-param("by", "{$by}")
    %rest:query-param("from", "{$from}")
    %rest:query-param("to", "{$to}")
    %rest:query-param("start", "{$start}", 1)
    %rest:query-param("max-results", "{$max-results}", 100)
    %rest:produces("application/xhtml+xml", "text/html", "application/xml", "text/xml")
    function chg:list(
        $type as xs:string*,
        $by as xs:string*,
        $from as xs:string*,
        $to as xs:string*,
        $start as xs:integer*,
        $max-results as xs:integer*
    ) as item()+ {
    if ($type and not($type=("original", "conditionals", "sources", "notes", "styles", "dictionaries", "linkage", "transliteration")))
    then
        api:rest-error(400, "Invalid type", $type) 
    else (
      <rest:response>
        <output:serialization-parameters>
          <output:method value="html5"/>
        </output:serialization-parameters>
      </rest:response>,
      <html> { ((: xmlns="http://www.w3.org/1999/xhtml"> :)) }
        <head>
          <title>Recent changes</title>
          <meta charset="utf-8"/>
        </head>
        <body>
            <ul class="results">{
                for $change in 
                    subsequence(
                        for $ch in chg:get-recent-changes($type[1], $by[1], $from[1], $to[1])
                        order by $ch/@when/string() descending
                        return $ch, ($start, 1)[1], ($max-results, 100)[1])
                group by $doc := document-uri(root($change))
                order by max($change/@when/string()) descending
                return
                    <li class="result"><a href="{data:db-path-to-api($doc)}">{
                        doc($doc)//tei:titleStmt/tei:title[@type="main" or not(@type)][1]/string()
                    }</a>
                        <ol class="changes">{
                            for $ch in $change
                            order by $ch/@when descending
                            return 
                                <li class="change"><span class="who">{$ch/@who/string()}</span>:<span class="type">{$ch/@type/string()}</span>:<span class="when">{$ch/@when/string()}</span>:<span class="message">{string-join($ch//text(), ' ')}</span></li>
                        }</ol>
                    </li>
            }</ul>
        </body>
      </html>
    )
};
