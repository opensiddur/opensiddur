xquery version "3.0";
(:~
 : Evaluate conditionals 
 :
 : Open Siddur Project
 : Copyright 2014 Efraim Feinstein, efraim@opensiddur.org 
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 :)
module namespace cond="http://jewishliturgy.org/transform/conditionals";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

(:~ get a feature value from the parameters
 : if the feature value is not set, use the default value
 :)
declare function cond:get-feature-value(
    $params as map,
    $fsname as xs:string,
    $fname as xs:string
    ) as xs:string? {
    let $s := $params("combine:settings")
    let $val :=
        if (exists($s))
        then $s($fsname || "->" || $fname)/string()
        else ()
    return
        if (exists($val))
        then $val
        else
            cond:evaluate(
                collection("/db/data/conditionals")//
                    tei:fsDecl[@type=$fsname]/tei:fDecl[@name=$fname]/tei:vDefault,
                $params
            )
};


declare function cond:tei-default(
    $e as element(tei:default),
    $params as map
    ) as xs:string? {
    let $fname := $e/parent::tei:f/@name/string()
    let $fstype := $e/ancestor::tei:fs[1]/@type/string()
    return
        cond:evaluate(
            collection("/db/data/conditionals")//
                tei:fsDecl[@type=$fstype]/tei:fDecl[@name=$fname]/tei:vDefault,
            $params
        )
}; 

(:~ evaluate a conditional in a given context, using the settings contained in 
 : $params("combine:settings")
 :
 : @param $conditional The condition to evaluate
 : @param $params Current parameters
 :
 : @return A sequence of: "YES", "NO", "MAYBE", "ON", "OFF"
 :)
declare function cond:evaluate(
    $conditional as element()*,
    $params as map
    ) as xs:string* {
    for $e in $conditional
    return
        typeswitch ($e)
        case text() return ()
        case element(j:on) return "ON"
        case element(j:off) return "OFF"
        case element(j:yes) return "YES"
        case element(j:no) return "NO"
        case element(j:maybe) return "MAYBE"
        case element(j:all) return cond:j-all($e, $params)
        case element(j:any) return cond:j-any($e, $params)
        case element(j:oneOf) return cond:j-oneOf($e, $params)
        case element(j:not) return cond:j-not($e, $params)
        case element(tei:default) return cond:tei-default($e, $params)
        case element(tei:vDefault) return cond:tei-vDefault($e, $params)
        case element(tei:if) return cond:tei-if($e, $params)
        case element(tei:f) return cond:tei-f($e, $params)
        case element(tei:fs) return cond:tei-fs($e, $params)
        case element() return cond:evaluate($e/element(), $params)
        default return ()
};

declare function cond:j-all(
    $e as element(j:all),
    $params as map
    ) as xs:string? {
    let $result := cond:evaluate($e/element(), $params)
    return 
        if ($result="NO")           (: if any feature evaluates to NO or OFF, so does all :)
        then "NO"
        else if ($result="OFF")
        then "OFF"
        else if ($result="MAYBE")   (: otherwise if any feature evaluates to MAYBE, so does all :)
        then "MAYBE"
        else if ($result="YES")     (: all that's left is YES/ON :)
        then "YES"
        else if ($result="ON")
        then "ON"
        else ()
};

declare function cond:j-any(
    $e as element(j:any),
    $params as map
    ) as xs:string? {
    let $result := cond:evaluate($e/element(), $params)
    return 
        if ($result="MAYBE")           (: if any feature evaluates to MAYBE, so does any :)
        then "MAYBE"
        else if ($result="YES")         (: next, YES or ON :)
        then "YES"
        else if ($result="ON") 
        then "ON"
        else if ($result="NO")          (: all that's left is NO or OFF :)
        then "NO"
        else if ($result="OFF")
        then "OFF"
        else ()
};

declare function cond:j-oneOf(
    $e as element(j:oneOf),
    $params as map
    ) as xs:string? {
    let $result := cond:evaluate($e/element(), $params)
    let $n-yes := count($result[.="YES"])
    let $n-maybe := count($result[.="MAYBE"])
    let $n-on := count($result[.="ON"])
    let $n-sum := $n-yes + $n-maybe + $n-on
    return 
        if ($n-on=1 and $n-sum=1)
        then "ON"
        else if ($n-yes=1 and $n-sum=1)
        then "YES"
        else if ($n-maybe=1 and $n-sum=1)
        then "MAYBE"
        else if ($result=("YES", "NO", "MAYBE"))
        then "NO"
        else if ($result=("ON", "OFF"))
        then "OFF"
        else ()
};

declare function cond:j-not(
    $e as element(j:not),
    $params as map
    ) as xs:string? {
    let $result := cond:evaluate($e/element(), $params)
    return
        if ($result="ON")
        then "OFF"
        else if ($result="OFF")
        then "ON"
        else if ($result="YES")
        then "NO"
        else if ($result="NO")
        then "YES"
        else if ($result="MAYBE")
        then "MAYBE"
        else ()
};

(: the default value is either a literal or the first matching result of an if :)
declare function cond:tei-vDefault(
    $e as element(tei:vDefault),
    $params as map
    ) as xs:string? {
    cond:evaluate($e/element(), $params)[1]
};

declare function cond:tei-if(
    $e as element(tei:if), 
    $params as map
    ) as xs:string? {
    let $eval := cond:evaluate($e/tei:then/preceding-sibling::*, $params)
    where ($eval=("ON", "YES"))
    return cond:evaluate($e/tei:then/following-sibling::*, $params) (: this will be a YES, NO, etc. :)
};

declare variable $cond:truth-table :=
    (: map setting,condition -> value :) 
    map {
        "ON,ON" := "ON",
        "ON,OFF" := "OFF",
        "OFF,ON" := "OFF",
        "OFF,OFF" := "ON",
        "YES,YES" := "YES",
        "YES,NO" := "NO",
        "YES,MAYBE" := "MAYBE",
        "NO,YES" := "NO",
        "NO,NO" := "YES",
        "NO,MAYBE" := "MAYBE",
        "MAYBE,YES" := "MAYBE",
        "MAYBE,NO" := "MAYBE",
        "MAYBE,MAYBE" := "MAYBE"
    };

declare function cond:tei-f(
    $e as element(tei:f), 
    $params as map
    ) as xs:string? {
    let $fstype := $e/parent::tei:fs/@type/string()
    let $fname := $e/@name/string()
    let $settings-value := cond:get-feature-value($params, $fstype, $fname)
    let $my-value := cond:evaluate($e/element(), $params)
    return $cond:truth-table(string-join(($settings-value, $my-value), ","))
};

declare function cond:tei-fs(
    $e as element(tei:fs),
    $params as map
    ) as xs:string* {
    cond:evaluate($e/element(), $params)
};
