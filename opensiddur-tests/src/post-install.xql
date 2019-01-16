xquery version "3.0";
(:~ post-install script for tests :)

util:log-system-out("most of tests post-install disabled due to opensiddur issue #156"),
util:log("info", "Register RESTXQ..."),
exrest:register-module(xs:anyURI("/db/apps/opensiddur-tests/api/tests.xqm"))