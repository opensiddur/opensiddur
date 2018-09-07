xquery version "3.0";

util:log-system-out("Register RESTXQ..."),
exrest:register-module(xs:anyURI("/db/apps/opensiddur-demos/api/demo.xqm")),
util:log-system-out("Done.")
