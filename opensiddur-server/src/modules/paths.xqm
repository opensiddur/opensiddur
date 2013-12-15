(: Path mnemonics
 : Open Siddur Project
 : Copyright 2010-2011,2013 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Released under the GNU Lesser General Public License, ver 3 or later
 :)
xquery version "1.0";

module namespace paths="http://jewishliturgy.org/modules/paths";

declare namespace expath="http://expath.org/ns/pkg";

declare variable $paths:repo-base := 
  let $descriptor := 
    collection(repo:get-root())//expath:package[@name = "http://jewishliturgy.org/apps/opensiddur-server"]
  return
    util:collection-name($descriptor);

(:~ absolute db location of schema files :)
declare variable $paths:schema-base := 
  concat($paths:repo-base, "/schema");


