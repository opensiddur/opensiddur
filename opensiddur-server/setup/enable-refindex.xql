xquery version "3.0";
import module namespace magic="http://jewishliturgy.org/magic" 
  at "xmldb:exist:///code/magic/magic.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "xmldb:exist:///code/modules/refindex.xqm";

let $login :=
  try {
    xmldb:login("/db", "admin", $magic:password)
  }
  catch * {
    xmldb:login("/db", "admin", "")
  }
return
  ridx:enable()

