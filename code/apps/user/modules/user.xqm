xquery version "1.0";
(: Application support module for the user code
 : 
 :
 : Copyright 2011 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: user.xqm 728 2011-04-05 14:23:33Z efraim.feinstein $
 :)
module namespace user="http://jewishliturgy.org/apps/user/controls";

declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";


import module namespace request="http://exist-db.org/xquery/request";
import module namespace util="http://exist-db.org/xquery/util"; 

declare variable $user:app-location := '/code/apps/user';

(:~ application header for user :)
declare function user:app-header(
	$control-id as xs:string,
	$save-button-control as element()+
	) as element() {
	let $uri := string(request:get-uri())
	let $active-tab-id := replace(substring-after($uri, concat(util:collection-name($uri), '/')), '.xql$', '')
	return 
	<xf:group id="{$control-id}">
		<div class="nav-header">
			<div class="nav-buttons">
				<ul>
					<li>
						{
						if ($active-tab-id = 'edit')
						then attribute class {'nav-active'}
						else ()
						}
						<xf:trigger appearance="minimal">
							<xf:label>Edit user profile</xf:label>
							<xf:action ev:event="DOMActivate">
								<xf:load resource="{$user:app-location}/edit.xql" show="replace"/>
							</xf:action>
						</xf:trigger>
					</li>
				</ul>
				<div class="save-status">{
					$save-button-control
				}</div>
			</div>
		</div>
	</xf:group>
}; 
