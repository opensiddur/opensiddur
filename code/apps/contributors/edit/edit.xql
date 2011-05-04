xquery version "1.0";

(:~ Editable list of contributor list items
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3
 : $Id: edit.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
import module namespace app="http://jewishliturgy.org/modules/app" 
	at "../../../modules/app.xqm";
import module namespace common="http://jewishliturgy.org/apps/contributors/common"
	at "../modules/common.xqm";
import module namespace contributors="http://jewishliturgy.org/apps/contributors/controls"
	at "../modules/controls.xqm";
import module namespace login="http://jewishliturgy.org/apps/user"
	at "../../../apps/user/modules/login.xqm";
import module namespace site="http://jewishliturgy.org/modules/site"
	at "../../../modules/site.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "../../../modules/paths.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema"; 
declare namespace html="http://www.w3.org/1999/xhtml";

declare option exist:serialize "method=xhtml media-type=text/xml";

site:form(
	<xf:model>{
		login:login-instance('login', 'list-editor'),
		contributors:list-instance('contributorlist'),
		contributors:individual-entry-instance('contributor','contributorlist', 
			(), (), 'editor', true(), 'login')
	}</xf:model>,
	(<html:title>Contributors List</html:title>),
	(<html:h2>Contributors list</html:h2>,
	login:login-ui('login','control-login'),
  <xf:group id="list-editor">
    <xf:toggle ev:event="login" case="list-editor-show"/>
    <xf:toggle ev:event="logout" case="list-editor-hide"/>
    <xf:switch>
      <xf:case id="list-editor-hide">
        <html:p>You must be logged in to edit the contributor list.</html:p>
      </xf:case>
      <xf:case id="list-editor-show">{
       	contributors:list-table-ui('contributorlist','control-contributorlist', true(),"editor"),
	      contributors:editor-ui('contributor', 'contributorlist', 'editor', 'control-contributorlist')
      }</xf:case>
    </xf:switch>
  </xf:group>
	),
  (site:css(),contributors:css()),
  site:header(),
  (site:sidebar(), contributors:sidebar()),
  site:footer()
)
