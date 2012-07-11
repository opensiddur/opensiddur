xquery version "3.0";
(:~ Intermediate links mode: 
 : finds tei:ptr inside concurrent constructs that would get 
 : "lost" if the links were followed.
 : Insert them in the j:links section as tei:ptr's
 : 
 : @author Efraim Feinstein
 :
 : Copyright 2010-2012 Efraim Feinstein
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License, version 3 and above 
 :)
module namespace intl="http://jewishliturgy.org/transform/intermediate-links";
 
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jf="http://jewishliturgy.org/ns/jlptei/flat/1.0";

declare function intl:intermediate-links(
  $nodes as node()*
  ) {
  for $n in $nodes 
  let $null := util:log-system-out(("int-links:", name($n)))
  return 
    typeswitch($n)
    case text() return ()
    case element(tei:TEI) return intl:tei-TEI($n)
    case element(j:links) return intl:j-links($n)
    case element(j:layer) return intl:j-layer($n)
    case element(tei:ptr) return intl:tei-ptr($n)
    default return intl:intermediate-links($n/node())
};

(:~ Add a j:links section if the document does not 
 : already have one.
 : This template will probably only run if the mode is 
 : executed independently
 :)
declare function intl:tei-TEI(
  $e as element(tei:TEI)
  ) {
  element tei:TEI {
    $e/(@*|node() except j:links),
    if (empty($e/j:links))
    then
      let $int-links := intl:intermediate-links($e/descendant::j:concurrent)
      let $null := util:log-system-out(("intermediate-links from: ", $e/descendant::j:concurrent))
      where exists($int-links)
      return
        element j:links {
          $int-links
        }
    else
      intl:intermediate-links($e/j:links)
  }
};

(:~ If a j:links section exists, copy it exactly, 
 : then run the mode for j:concurrent
 :
 : This function will probably only run if the mode is executed 
 : independently
 :)
declare function intl:j-links(
  $e as element(j:links)
  ) {
  element j:links {
    $e/(@*|node()),
    intl:intermediate-links(root($e)/descendant::j:concurrent)
  }
};

(:~ Copy a tei:ptr for intermediate link :)
declare function intl:copy-intermediate-tei-ptr(
  $e as element(tei:ptr)
  ) {
  element tei:ptr {
    attribute jf:id {$e/@xml:id},
    if (
      base-uri($e) ne 
      root($e)/(.//j:links,.//tei:TEI)[1]/base-uri()
    )
    then
      attribute xml:base { base-uri($e) }
    else (),
    $e/(@* except (@xml:id, @xml:base))
  }
};

(:~ layers disappear in the concurrency process, make them 
 : point to something resembling a layer
 :)
declare function intl:j-layer(
  $e as element(j:layer) 
  ) {
  if ($e/@xml:id)
  then
  	element tei:join {
  	  attribute jf:id { $e/@xml:id },
  	  attribute result { $e/name() },
  	  attribute target {
  	    string-join(
  	      for $x in $e/*/@xml:id 
  	      return concat('#', $x)
  	      , " "
  	    )
  	  },
  	  if (
  	    base-uri(.) ne 
  	    root($e)/(.//j:links,.//tei:TEI)[1]/base-uri()
  	  )
  	  then
        attribute xml:base { base-uri(.) }
      else (),
      $e/(@* except (@xml:id, @xml:base))
  	}
  else (),
  intl:intermediate-links($e/*)
};

(:~ Copy pointers that are not in the streamText :)
declare function intl:tei-ptr(
  $e as element(tei:ptr)
  ) {
    if (not($e/parent::j:streamText) and $e/@xml:id)
    then
      intl:copy-intermediate-tei-ptr($e)
    else ()
};
