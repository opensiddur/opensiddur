xquery version "1.0";

(:~ contributor list common variables 
 : 
 : The Open Siddur Project
 : Copyright 2010 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: common.xqm 709 2011-02-24 06:37:44Z efraim.feinstein $
 :)

module namespace contributors="http://jewishliturgy.org/apps/contributors/common";

import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "../../../modules/paths.xqm";

declare namespace xs="http://www.w3.org/2001/XMLSchema"; 
declare namespace err="http://jewishliturgy.org/errors";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $contributors:collection := '/group/everyone/contributors';
declare variable $contributors:resource := 'contributors.xml';
declare variable $contributors:list := concat($contributors:collection, '/', $contributors:resource);

declare variable $contributors:loader := concat($paths:prefix, $paths:apps, '/contributors/load.xql');
declare variable $contributors:saver := concat($paths:prefix, $paths:apps, '/contributors/edit/save.xql');
declare variable $contributors:deleter := concat($paths:prefix, $paths:apps, '/contributors/edit/delete.xql');
declare variable $contributors:searcher := concat($paths:prefix, $paths:apps, '/contributors/search/search.xql');

declare variable $contributors:prototype-path := concat($paths:apps, '/contributors/edit/new-instance.xml'); 
declare variable $contributors:prototype as element(tei:item)? := 
	if (doc-available($contributors:prototype-path))
	then doc($contributors:prototype-path)/tei:list/tei:item
	else error(xs:QName('err:NOT_FOUND'), concat('Resource "', $contributors:prototype-path,'" not found.'));
