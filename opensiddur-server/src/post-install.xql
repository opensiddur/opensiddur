xquery version "3.1";

import module namespace format="http://jewishliturgy.org/modules/format"
  at "modules/format.xqm";
import module namespace didx="http://jewishliturgy.org/modules/docindex"
  at "modules/docindex.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "modules/refindex.xqm";
import module namespace src="http://jewishliturgy.org/api/data/sources"
  at "api/data/sources.xqm";
import module namespace sty="http://jewishliturgy.org/api/data/styles"
  at "api/data/styles.xqm";
import module namespace upg="http://jewishliturgy.org/modules/upgrade"
  at "modules/upgrade.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
  
(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

util:log("info", "starting post-install..."),
util:log("info", "removing caches..."),
for $cache in $format:caches
where xmldb:collection-available($cache)
return
    try { xmldb:remove($cache) }
    catch * { util:log("info", ("Error removing ", $cache)) },
util:log("info", "setup format..."),
format:setup(),
util:log("info", "setup refindex..."),
ridx:setup(),
util:log("info", "setup docindex..."),
didx:setup(),
util:log("info", "install default sources..."),
(: add $target/data/sources/Born Digital using src:post() or src:put() :)
xmldb:store(
    "/db/data/sources",
    "Born%20Digital.xml",
    doc($target || "/data/sources/Born%20Digital.xml")
    ),
util:log("info", "install default styles..."),
(: add $target/data/styles/generic.xml using sty:post() or sty:put() :)
xmldb:store(
    "/db/data/styles/en",
    "generic.xml",
    doc($target || "/data/styles/en/generic.xml")
    ),
util:log("info", "install default users..."),
xmldb:store(
    "/db/data/user",
    "admin.xml",
    <j:contributor>
        <tei:idno>admin</tei:idno>
        <tei:orgName>Open Siddur Project</tei:orgName>
    </j:contributor>
),
xmldb:store(
        "/db/data/user",
        "SYSTEM.xml",
        <j:contributor>
            <tei:idno>SYSTEM</tei:idno>
            <tei:orgName>Open Siddur Project</tei:orgName>
        </j:contributor>
),
util:log("info", "upgrades: update existing JLPTEI for schema changes..."),
upg:all-schema-changes(),
util:log("info", "upgrades: reindex reference index"),
ridx:reindex(collection("/db/data")),
util:log("info", "upgrades: reindex document index"),
didx:reindex(collection("/db/data")),
util:log("info", "reindex all data collections"),
xmldb:reindex("/db/data"),
util:log("info", "force registration for RESTXQ..."),
for $module in (
            "/api/data/conditionals.xqm",
            "/api/data/styles.xqm",
            "/api/data/original.xqm",
            "/api/group.xqm",
            "/api/data/linkage.xqm",
            "/api/data/transliteration.xqm",
            "/api/index.xqm",
            "/api/login.xqm",
            "/api/test.xqm",
            "/api/data/dindex.xqm",
            "/api/data/notes.xqm",
            "/api/data/dictionaries.xqm",
            "/api/jobs.xqm",
            "/api/user.xqm",
            "/api/data/sources.xqm",
            "/api/changes.xqm",
            "/api/static.xqm",
            "/api/data/outlines.xqm",
            "/api/utility/utilityindex.xqm",
            "/api/utility/translit.xqm"
)
return exrest:register-module(xs:anyURI("/db/apps/opensiddur-server" || $module)),
util:log("info", "done")

