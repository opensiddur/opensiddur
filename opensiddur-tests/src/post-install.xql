xquery version "3.0";
(:~ post-install script for tests :)

util:log-system-out("Creating test data collection..."),
if (xmldb:collection-available("/db/data/tests"))
then ()
else xmldb:create-collection("/db/data", "tests"),
sm:chown(xs:anyURI("/db/data/tests"), "testuser"),
sm:chgrp(xs:anyURI("/db/data/tests"), "testuser"),
sm:chmod(xs:anyURI("/db/data/tests"), "rwxrwxr-x"),
util:log-system-out("Register RESTXQ..."),
exrest:register-module(xs:anyURI("/db/apps/opensiddur-tests/api/tests.xqm")),
util:log-system-out("Done.")

