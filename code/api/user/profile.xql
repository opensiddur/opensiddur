xquery version "1.0";
(: user profile editing API
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
import module namespace prof="http://jewishliturgy.org/api/user/profile"
  at "/code/api/user/profile.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace err="http://jewishliturgy.org/errors";

prof:go()