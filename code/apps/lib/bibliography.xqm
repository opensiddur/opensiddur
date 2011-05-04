(: Bibliography controls
 : Open Siddur Project
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Released under the GNU Lesser General Public License, ver 3 or later
 : $Id: bibliography.xqm 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
xquery version "1.0";
module namespace bibliography="http://jewishliturgy.org/apps/lib/bibliography";

declare namespace xf="http://www.w3.org/2002/xforms";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace ev="http://www.w3.org/2001/xml-events"; 
declare namespace xs="http://www.w3.org/2001/XMLSchema";
declare namespace xrx="http://jewishliturgy.org/ns/xrx";

import module namespace controls="http://jewishliturgy.org/apps/lib/controls" 
	at "../lib/controls.xqm";
import module namespace paths="http://jewishliturgy.org/apps/lib/paths" 
	at "../lib/paths.xqm";

declare variable $bibliography:prototype :=
	<tei:biblStruct xml:id="">
		<tei:monogr>
    	<tei:author/>
	    <tei:editor/>
	    <xrx:titles>
  	  	<tei:title xml:lang="en" type="main"/>
    		<tei:title xml:lang="en" type="subtitle"/>
    	</xrx:titles>
    	<tei:edition/>
    	<tei:idno type="url"/>
    	<tei:imprint>
      	<tei:publisher/>
      	<tei:pubPlace/>
      	<tei:date/>
 	  		<tei:distributor>
  	  		<tei:ref type="url" target=""/>
      		<tei:date type="access"/>
      	</tei:distributor>
    	</tei:imprint>
	  </tei:monogr>
  	<tei:note type="copyright"/>
  	<tei:note/>
	</tei:biblStruct>;

(:~ Entry for a single bibliography instance :)
declare function bibliography:individual-entry-instance(
	$instance-id as xs:string) 
	as element()+ {
	(
	<xf:instance id="{$instance-id}">
		<tei:listBibl>{
			$bibliography:prototype
		}</tei:listBibl>
	</xf:instance>,
	controls:ordered-list-instance(concat($instance-id,'-author'), <tei:author/>),
	controls:ordered-list-instance(concat($instance-id,'-editor'), <tei:editor/>),
	controls:ordered-list-instance(concat($instance-id,'-title'), 
		<xrx:titles>
			<tei:title xml:lang="en" type="main"/>
			<tei:title xml:lang="en" type="subtitle"/>
		</xrx:titles>)
	)
};

(:~ bindings for when the list and individual entries are the same :)
declare function bibliography:individual-entry-bindings(
	$instance-id as xs:string,
	$conditions as xs:string)
	as element(xf:bind)+ {
	bibliography:individual-entry-bindings($instance-id, $instance-id, $conditions)
};

(:~ bindings for an individual bibliography entry
 : @param $instance-id instance where individual entry is stored (may be the same as $list-instance-id)
 : @param $list-instance-id instance where list of entries is stored
 : @param $conditions predicate indicating what entries should be included :)
declare function bibliography:individual-entry-bindings(
	$instance-id as xs:string,
	$list-instance-id as xs:string,
	$conditions as xs:string) 
	as element(xf:bind)+ {
	(
		<xf:bind nodeset="instance('{$instance-id}')/tei:biblStruct{$conditions}/@xml:id" 
			type="xf:NCName"
			constraint="(. != '') and count(instance('{$list-instance-id}')/tei:biblStruct[@xml:id = current()])=1"
			/>,
		<xf:bind nodeset="instance('{$instance-id}')/tei:biblStruct{$conditions}/tei:monogr/tei:author" 
			type="xf:string" required="../tei:editor = ''"
			/>,
		<xf:bind nodeset="instance('{$instance-id}')/tei:biblStruct{$conditions}/tei:monogr/tei:editor" 
			type="xf:string" required="../tei:author = ''"
			/>,
		<xf:bind nodeset="instance('{$instance-id}')/tei:biblStruct{$conditions}/tei:monogr/tei:imprint/tei:date" 
			type="xf:integer" required="true()"
			constraint=". &gt; 0 and . &lt;= 2100"
			/>,
		<xf:bind nodeset="instance('{$instance-id}')/tei:biblStruct{$conditions}/tei:monogr/tei:imprint/tei:distributor/tei:ref/@target" 
			type="xf:anyURI" required=".. != ''"
			/>,
		<xf:bind nodeset="instance('{$instance-id}')/tei:biblStruct{$conditions}/tei:monogr/tei:imprint/tei:distributor/tei:ref[@type='url']" 
			type="xf:string" required="@target != ''"
			/>,
		<xf:bind nodeset="instance('{$instance-id}')/tei:biblStruct{$conditions}/tei:monogr/tei:imprint/tei:distributor/tei:date[@type='access']" 
			type="xf:date" required="../tei:ref != ''"
			/>,
		<xf:bind nodeset="instance('{$instance-id}')/tei:biblStruct{$conditions}/tei:monogr/xrx:titles/tei:title[@type='main']" 
			type="xf:string" required="true()"
			/>,
		<xf:bind nodeset="instance('{$instance-id}')/tei:biblStruct{$conditions}/tei:monogr/xrx:titles/tei:title[@type='main']/@xml:lang" 
			type="xf:language" required="true()"
			/>,
		<xf:bind nodeset="instance('{$instance-id}')/tei:biblStruct{$conditions}/tei:monogr/xrx:titles/tei:title[@type='subtitle']/@xml:lang" 
			type="xf:language" required=".. != ''"
			/>
	)
};

(:~ Individual entry GUI
 : @param $instance-id Instance that this entry will represent 
 : @param $control-id control identifier
 : @param $ref Reference to what this entry will fill in (empty if current context) :)
declare function bibliography:individual-entry-gui(
	$instance-id as xs:string,
	$control-id as xs:string,
	$ref as xs:string?
	) 
	as element(xf:group) {
    <xf:group
      id="{$control-id}" 
      incremental="true">
      {if ($ref)
      then attribute ref {$ref}
      else () }
      <p>
      The convention for record IDs is to use the name of the first author or editor 
      followed by the year of publication (eg, Baer1901).  
      If the publisher is better known or the work is anonymous, use the publisher's name
      followed by publication year (eg, JPS1917).
      If the above are not possible, use all or part of the book's main title, followed by publication year.
      Must begin with an alphabetic letter.  
      Spaces are not allowed, and should be replaced with underscores (_).
      </p>
      <xf:input ref="@xml:id" incremental="true">
        <xf:label>Record id: </xf:label>
        <xf:alert>The record ID is required and must be unique among all other record IDs.  See hint.</xf:alert>
      </xf:input>
      <br/>
      
      {controls:ordered-list-ui(
      	concat($instance-id,'-author'),
      	concat($control-id,'-author'),
      	'Authors',"tei:monogr/tei:author",
        <xf:input ref="."  incremental="true">
          <xf:label>Author: </xf:label>
          <xf:hint>Author of the book, including roles followed by first names then surname (eg, Rabbi Bahya ibn Pekuda).</xf:hint>
        </xf:input>,
        "self::tei:author")
      }
      <br/>
    
      {controls:ordered-list-ui(
      	concat($instance-id, '-editor'),
      	concat($control-id,'-editor'), 
        'Editors',
        "tei:monogr/tei:editor",
        <xf:input ref="."  incremental="true">
          <xf:label>Editor: </xf:label>
          <xf:hint>Editor of the book, roles followed by first names then surname (eg, Rabbi Dr. Seligmann Baer).</xf:hint>
        </xf:input>,
        "self::tei:editor"
        )
      }
      <br/>
			<fieldset>
				<legend>Titles and subtitles</legend>
				<p>The title and subtitle should be the title as written on the book's title page in its original language.  
						Additional title/subtitle pairs may be added by pressing "Insert" to translate the title and subtitle.</p>
				{controls:ordered-list-ui(
					concat($instance-id,'-title'),
					concat($control-id,'-title'),
					'',
					"tei:monogr/xrx:titles",
					<fieldset>
						{
						controls:language-selector-ui(
							concat($control-id, "-title-lang"),
		      		"Language: ",
		      		"tei:title[@type='main']/@xml:lang")
			   		}
			   		<xf:input ref="tei:title[@type='main']"  incremental="true">
				   		<xf:label>Main title: </xf:label>
		      	</xf:input>
		      	{
		      	controls:language-selector-ui(
		      		concat($control-id,"-subtitle-lang"),
		      		"Language: ",
		      		"tei:title[@type='subtitle']/@xml:lang")
			   		}
			   		<xf:input ref="tei:title[@type='subtitle']"  incremental="true">
				   		<xf:label>Subtitle: </xf:label>
		      	</xf:input>
		      </fieldset>,
		      "self::xrx:titles")
				}
			  <xf:input ref="tei:monogr/tei:edition">
	      	  <xf:label>Edition: </xf:label>
	      </xf:input>
    	</fieldset>
		  
      <br/>
      <fieldset>
      	<legend>Publication information</legend>
	      <xf:input ref="tei:monogr/tei:imprint/tei:publisher">
	        <xf:label>Publisher: </xf:label>
	      </xf:input>
	    	<br/>
	    	
	      <xf:input ref="tei:monogr/tei:imprint/tei:pubPlace">
	        <xf:label>Publication place: </xf:label>
	      </xf:input>
	    	<br/>
	    	
	      <xf:input ref="tei:monogr/tei:imprint/tei:date" incremental="true">
	        <xf:label>Publication Year:</xf:label>
	      </xf:input>
	      <br/>
	    </fieldset>
      <xf:group id="{$control-id}-internet-source">
	    	<fieldset>
	    		<legend>Internet source information</legend>
		    	<xf:input ref="tei:monogr/tei:imprint/tei:distributor/tei:ref[@type='url']" incremental="true">
		        <xf:label>Distributor: </xf:label>
		      </xf:input>
		      <br/>
		    	<xf:input ref="tei:monogr/tei:imprint/tei:distributor/tei:ref[@type='url']/@target" incremental="true">
		        <xf:label>Distributor URL: </xf:label>
		      </xf:input>
		      <br/>
		  		<xf:input ref="tei:monogr/tei:imprint/tei:distributor/tei:date[@type='access']" incremental="true">
        		<xf:label>Download date: </xf:label>
      		</xf:input>
	      </fieldset>
      </xf:group>
      <br/>
      
      
      
    	<fieldset>
    		<legend>Transcription source information</legend>
      	<xf:textarea ref="tei:note[@type='copyright']">
        	<xf:label>Copyright and license notice: <br/> </xf:label>
      	</xf:textarea>
      </fieldset>
    	<br/>
    	
      <xf:textarea ref="tei:note[2]">
        <xf:label>Additional note: <br/></xf:label>
      </xf:textarea>      
    </xf:group> 

};

(:~ Bibliography list instance :)
declare function bibliography:list-instance(
	$instance-id as xs:string) 
	as element()+ {
	(
	<xf:instance id="{$instance-id}" 
		src="{$paths:prefix}{$paths:apps}/bibliography/load.xql" xmlns="">
		<tei:listBibl>
		</tei:listBibl>
	</xf:instance>,
	bibliography:individual-entry-instance(concat($instance-id,'-prototype')),
	bibliography:individual-entry-bindings($instance-id, '')
	)	
};

declare function bibliography:list-gui(
	$instance-id as xs:string,
	$control-id as xs:string)
	as element()+	{
	let $repeat-id := concat($control-id,'-repeat')
	return 
	<xf:group id="{$control-id}">
		<xf:group ref="instance('{$instance-id}')">
			<xf:repeat id="{$repeat-id}" 
				nodeset="tei:biblStruct">
				<hr/>
				{controls:collapsible(concat($control-id,'-bibliography-entry'),
					<xf:output ref="@xml:id"/>,
					(
					<xf:trigger ref="self::node()[count(../*) &gt; 1]">
						<xf:label>Delete record</xf:label>
						<xf:action ev:event="DOMActivate">
							<xf:delete nodeset="."/>
						</xf:action>
					</xf:trigger>,
						bibliography:individual-entry-gui(
							concat($instance-id, '-prototype'),
							concat($control-id,'-bibliography-individual'),
							()))
				)}
				</xf:repeat>
		</xf:group>
		<h2>Add new record</h2>
		<!-- TODO: NEED A DIFFERENT ADD RECORD FOR EMPTY LISTS -->
		<xf:trigger id="{$instance-id}-add-record">
			<xf:label>Add new bibliography record</xf:label>
			<xf:action ev:event="DOMActivate">
				<xf:insert origin="instance('{$instance-id}-prototype')/tei:biblStruct"
						nodeset="instance('{$instance-id}')/tei:biblStruct"
						at="last()"
						position="after"
						/>
				<xf:setvalue ref="instance('{$instance-id}')/tei:biblStruct[last()]/@xml:id">* NEW ITEM</xf:setvalue>
			</xf:action>
		</xf:trigger>
		<hr/>
	</xf:group>
};

(:~ User interface for selection of a single bibliographic entry from a list 
 : @param $list-instance-id String identifier of an initialized list instance
 : @param $control-id Identifier of this control
 : @param $ref XPath reference to the entry that is being selected 
 :)
declare function bibliography:select-entry-ui(
	$list-instance-id as xs:string,
	$control-id as xs:string,
	$ref as xs:string) {
	<xf:group id="{$control-id}" ref="instance('{$list-instance-id}')">
		<xf:select1 ref="{$ref}" incremental="true">
			<xf:itemset nodeset="instance('{$list-instance-id}')/tei:biblStruct">
				<xf:label ref="tei:monogr/xrx:titles/tei:title[@type='main']"/>
				<xf:value ref="@xml:id"/>
			</xf:itemset>
		</xf:select1>
	</xf:group>
};