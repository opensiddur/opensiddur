xquery version "3.0";
(:~ task to find uncached resources and schedule the background
 : task to execute them
 :  
 : Copyright 2011-2012 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace jcache="http://jewishliturgy.org/modules/cache"
  at "xmldb:exist:///code/modules/cache-controller.xqm";
import module namespace jobs="http://jewishliturgy.org/apps/jobs"
  at "xmldb:exist:///code/apps/jobs/modules/jobs.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:///code/magic/magic.xqm";
import module namespace debug="http://jewishliturgy.org/transform/debug"
  at "xmldb:exist:///code/modules/debug.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $local:task-id external;

declare variable $local:excluded-collections := concat("(",
  string-join(
    ("/output/","/trash/","/template.xml$"),
  ")|("),
  ")");

try {
  debug:debug(
    $debug:info,
    "jobs",
    concat('In uncached resource scheduler at ', string(current-dateTime()))
    ),
  let $documents :=
    system:as-user('admin', $magic:password,
      collection(("/group","/code"))/tei:TEI/document-uri(root(.))
    )
  for $document in $documents
  let $null :=
    debug:debug($debug:detail, "jobs", ("attempting to schedule:", $document))
  where
    not(matches($document, $local:excluded-collections)) and
    not(system:as-user('admin', $magic:password, jcache:is-up-to-date($document)))
  return
    jobs:enqueue-unique(
      element jobs:job {
        element jobs:run {
          element jobs:query { 'xmldb:exist:///code/apps/jobs/queries/bg-cache.xql' },
          element jobs:param {
            element jobs:name { 'resource' },
            element jobs:value { $document }
          }
        }
      },
      'admin', $magic:password
    )
}
catch * {
  debug:debug($debug:warn,
    "jobs",
    ('Error in cache scheduler: ', 
    debug:print-exception($err:module, $err:line-number, $err:column-number, $err:code, $err:value, $err:description)
    )
  )
}
