xquery version "1.0";
(:
: Module Name: Bibliography API
: Module Version: $Id: biblio.xqm 258 2009-09-02 01:46:07Z efraim.feinstein $
: Date: August 12, 2009
: Copyright: 2009 Efraim Feinstein <efraim.feinstein@gmail.com>. LGPL 3+
: Proprietary XQuery Extensions Used: 
: XQuery Specification: January 2007
: Module Overview: Provides an API to a bibliography list.  
:   Requires that the context be set to a valid bibliography file.
:)
(:~
 : 
 : @author Efraim Feinstein
 :)
module namespace 
    biblio="http://jewishliturgy.org/ns/functions/biblio";

import module namespace 
  jvalidation="http://jewishliturgy.org/ns/functions/nonportable/validation";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $biblio:listBibl := 
    //tei:TEI/tei:text/tei:body/tei:div[@type='bibliography']/tei:listBibl;

declare variable $biblio:SCHEMATRON :=
  '/queries/biblio.sch' cast as xs:anyURI;

declare variable $biblio:RELAXNG :=
  '/schema/jlptei.rng' cast as xs:anyURI;

(:~ @return whether the context is a bibliographic file
 :)
declare function biblio:is-valid-file() 
    as xs:boolean {
    validation:jing(root(), $biblio:SCHEMATRON)  
};

(:~ @return why the context is an (in)valid bibliography :)
declare function biblio:why-invalid-file() 
  as element(report) {
  jvalidation:validate-schematron(root(), $biblio:SCHEMATRON)
}; 

(:~ Determine if a given item is a valid bibliographic item
 : @return whether the file is valid :)
declare function biblio:is-valid-item($content as element(tei:biblStruct)) 
    as xs:boolean {
  validate:jing($content, $biblio:SCHEMATRON) 
};

(:~ Determine why a given item is an (in)valid bibliographic item
 : @return a report of the book entry's status :)
declare function biblio:why-invalid-item($content as element(tei:biblStruct)) 
    as element(report) {
  validate:jing-report($content, $biblio:SCHEMATRON) 
};

(:~ Add an item to the bibliography 
 : @return a report element indicating success or failure :)
declare function biblio:add($content as element(tei:biblStruct)) 
  as element(report) {
  if biblio:is-valid-item($content) 
  then 
    <report>
      <status>ok</status>
      {update insert $content into $biblio:listBibl}
    </report>
  else
    biblio:why-invalid-item($content)
};

(:~ edit an existing bibliographic entry
 : @param $content the new content, where @xml:id identifies
 :  which element is being edited
 : @return report with ok status or error
 :)
declare function biblio:edit($content)
    as element() {
    let $contentToEdit :=
        biblio:get-by-id($content/@xml:id) |
    let $numberOfContents := count($contentToEdit)
    return
        if ($numberOfContents eq 0)
        then
            (: this is an add operation :)
            biblio:add($content)
        else
            (: this is an edit operation :)
            if (biblio:is-valid-item($content)
            then
                <report>
                  <status>ok</status>
                    {update replace $contentToEdit with $content}
                </report>
            else
                biblio:why-invalid-item($content)
};


(: Remove an item from the bibliography (referenced by its xml:id).
 : TODO: do not remove it if it's referenced
 :)
declare function biblio:remove($xmlid as xs:string)
  as element(report) {
  <report>
    <status>ok</status>
    {update delete $biblio:listBibl/tei:biblStruct[@xml:id=$xmlid]}
  </report> 
} 

(:~ get a bibliographic entry by xml:id
 : @param $xmlid the xml:id
 : @return the item, or empty
 :)
declare function biblio:get-by-id($xmlid as xs:string)
    as element(tei:biblStruct)? {
  $biblio:listBibl/tei:biblStruct[@xml:id eq $xmlid]  
};

(:~ search the bibliography by string information
 : (eg, author, editor, title, publisher)
 : @param $regex is a regular expression defining the search term
 : @return the tei:item(s) that match
 :)
declare function biblio:get-by-string($regex as xs:string)
    as element(tei:biblStruct)* {
    $biblio:listBibl/tei:biblStruct[matches(.,$regex)]
};

(:~ @return all items :)
declare function biblio:get-all() 
    as element(tei:biblStruct)* {
    $biblio:listBibl/tei:biblStruct   
};
