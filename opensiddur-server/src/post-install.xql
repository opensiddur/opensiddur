xquery version "3.0";

import module namespace format="http://jewishliturgy.org/modules/format"
  at "modules/format.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "modules/refindex.xqm";
import module namespace src="http://jewishliturgy.org/api/data/sources"
  at "api/data/sources.xqm";
import module namespace sty="http://jewishliturgy.org/api/data/styles"
  at "api/data/styles.xqm";
import module namespace upg="http://jewishliturgy.org/modules/upgrade"
  at "modules/upgrade.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
  
(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

util:log-system-out("starting post-install..."),
util:log-system-out("removing caches..."),
for $cache in $format:caches
where xmldb:collection-available($cache)
return
    try { xmldb:remove($cache) }
    catch * { util:log-system-out(("Error removing ", $cache)) },
util:log-system-out("setup format..."),
format:setup(),
util:log-system-out("setup refindex..."),
ridx:setup(),
util:log-system-out("install default sources..."),
(: add $target/data/sources/Born Digital using src:post() or src:put() :)
xmldb:store(
    "/db/data/sources",
    "Born%20Digital.xml",
    doc($target || "/data/sources/Born%20Digital.xml")
    ),
util:log-system-out("install default styles..."),
(: add $target/data/styles/generic.xml using sty:post() or sty:put() :)
xmldb:store(
    "/db/data/styles/en",
    "generic.xml",
    doc($target || "/data/styles/en/generic.xml")
    ),
util:log-system-out("upgrades: update existing JLPTEI for schema changes..."),
upg:schema-changes-0-7-5(),
util:log-system-out("upgrades: reindex reference index"),
ridx:reindex(collection("/db/data")),
util:log-system-out("reindex all data collections"),
xmldb:reindex("/db/data"),
util:log-system-out("done")
