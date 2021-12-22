xquery version "3.1";
(: convert text to a separated tei:name structure
 :
 : Copyright 2010-2011 Efraim Feinstein <efraim.feinstein@gmail.com>
 :  Licensed under the GNU Lesser General Public License, version 3 or later
 : 
 : $Id: name.xqm 708 2011-02-24 05:40:58Z efraim.feinstein $ 
 :)
module namespace name="http://jewishliturgy.org/modules/name";

declare namespace tei="http://www.tei-c.org/ns/1.0";

(:~ convert a name in the given string to tei:*name 
 : @param $n the string to convert
 :)
declare function name:string-to-name(
  $n as xs:string
  ) as element()* {
  let $roles := '(Dr|M|Mme|Mr|Mrs|Ms|Rabbi|R|Rev)\.?$'
  let $links := '(ben|de|den|der|ibn|van|von)$'
  let $gens := '((Jr|Jr)\.?)|(I|II|III|IV|V|VI|VII|VIII|IX|X|1st|2nd|3rd|4th|5th|6th|7th|8th|9th|10th)$'
  let $tokens := tokenize($n, '[,\s]+')
  let $is-role := 
    for $token in $tokens return matches($token, $roles)
  let $is-link :=
    for $token in $tokens return matches($token, $links)
  let $is-gen :=
    for $token in $tokens return matches($token, $gens)
  return
    for $token at $pos in $tokens
    return
      if ($is-role[$pos])
      then 
        element tei:roleName {$token}
      else if ($is-link[$pos])
      then 
        element tei:nameLink {$token}
      else if ($is-gen[$pos])
      then 
        element tei:genName {$token}
      else if (
        $pos = count($tokens) or
        (every $token-pos in (($pos + 1) to count($tokens))            
          satisfies ($is-role[$token-pos] or $is-link[$token-pos] or $is-gen[$token-pos]))
        )
      then 
        element tei:surname {$token}
      else
        element tei:forename {$token}
};

(: convert a tei:name into a string :)
declare function name:name-to-string(
  $name as element(tei:name)
  ) as xs:string {
  string-join($name//text(), ' ')
};
