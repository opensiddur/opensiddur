xquery version "3.0";
(:~ task to find uncached resources and schedule the background
 : task to execute them
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "xmldb:exist:///code/modules/paths.xqm";
import module namespace jcache="http://jewishliturgy.org/modules/cache"
  at "xmldb:exist:///code/modules/cache-controller.xqm";
import module namespace jobs="http://jewishliturgy.org/apps/jobs"
  at "xmldb:exist:///code/apps/jobs/modules/jobs.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "xmldb:exist:///code/magic/magic.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $local:task-id external;

declare variable $local:excluded-collections := concat("(",
  string-join(
    ("/output/","/trash/"),
  ")|("),
  ")");

try {
  if ($paths:debug)
  then 
    util:log-system-out(
      concat('In uncached resource scheduler at ', string(current-dateTime()))
    )
  else (),
  let $documents :=
    system:as-user('admin', $magic:password,
      collection('/group')//tei:TEI/document-uri(root(.))
    )
  for $document in $documents
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
catch * ($c, $d, $v) {
  util:log-system-out(('Error in cache scheduler: ', $c, ' ', $d, ' ', $v))
}
