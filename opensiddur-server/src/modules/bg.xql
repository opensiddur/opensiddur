xquery version "3.0";
(: background task runner.
 : runs every 1s from a cron job, and reads commands submitted by status:submit()
 :)
import module namespace status="http://jewishliturgy.org/modules/status"
    at "xmldb:exist://db/apps/opensiddur-server/modules/status.xqm";

status:run()
