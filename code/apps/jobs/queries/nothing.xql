xquery version "1.0";

declare variable $local:task-id external;

util:log-system-out(("Testing scheduler at ", current-dateTime(), " id=", $local:task-id))
