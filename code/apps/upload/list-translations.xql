xquery version "1.0";
(: list-translations.xql
 : List available translations
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: list-translations.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
import module namespace dataman="http://jewishliturgy.org/ns/functions/dataman";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare option exist:serialize "method=xml media-type=text/xml";

(dataman:list-translations(), <tei:list/>)[1]