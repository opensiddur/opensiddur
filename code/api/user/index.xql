xquery version "1.0";
(:~ index for the user API
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
import module namespace index="http://jewishliturgy.org/api/user" 
	at "/code/api/user/index.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 

index:go()