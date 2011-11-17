xquery version "1.0";
(: api login action front-end
 : 
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
import module namespace login="http://jewishliturgy.org/api/user/login"
  at "/code/api/user/login.xqm";
  
login:go()