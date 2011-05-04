xquery version "1.0";
(: controller.xql
 : controller for global db operations
 : requires the controller-config.xml to have root /* passed to xmldb:exist:///db
 : Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 : $Id: controller.xql 687 2011-01-23 23:36:48Z efraim.feinstein $
 :)
 
declare namespace ex="http://exist.sourceforge.net/NS/exist";

(: map simple URL shortcuts, including the ones used for conditionals :)
let $map :=
	<map-root>
		<map src="/bibliography" dest="/data/global/bibliography/bibliography.xml"/>
		<map src="/contributors" dest="/data/global/contributors/contributors.xml"/>
		<map start="/scans/" redirect="http://jewishliturgy.org/base/sources/"/>
		<map src="/operators" dest="/data/global/conditionals/operators.xml"/>
    <map src="/YES" dest="/data/global/conditionals/symbol_yes.xml"/>
    <map src="/NO" dest="/data/global/conditionals/symbol_no.xml"/>
    <map src="/MAYBE" dest="/data/global/conditionals/symbol_maybe.xml"/>
    <map src="/ON" dest="/data/global/conditionals/symbol_on.xml"/>
    <map src="/OFF" dest="/data/global/conditionals/symbol_off.xml"/>
    <map src="/YN" dest="/data/global/conditionals/symbol_yn.xml"/>
    <map src="/YM" dest="/data/global/conditionals/symbol_ym.xml"/>
    <map src="/NM" dest="/data/global/conditionals/symbol_nm.xml"/>
    <map src="/ONOFF" dest="/data/global/conditionals/symbol_onoff.xml"/>
    <map src="/TWOWAY" dest="/data/global/conditionals/range_yn.xml"/>
    <map src="/THREEWAY" dest="/data/global/conditionals/range_ynm.xml"/>
    <map src="/TWOWAYS" dest="/data/global/conditionals/range_onoff.xml"/>
	</map-root>
let $mapped-resource :=
	$map/map[@src=$exist:path]
let $redirected-resource :=
	$map/map[@start and starts-with($exist:path,@start)]
return
(
util:log-system-out(
	<vars from="main controller.xql">
		<path>{$exist:path}</path>
		<resource>{$exist:resource}</resource>
		<controller>{$exist:controller}</controller>
		<prefix>{$exist:prefix}</prefix>
		<root>{$exist:root}</root>
		<mapped-resource>{$mapped-resource}</mapped-resource>
		<redirected-resource>{$redirected-resource}</redirected-resource>
	</vars>
	),
	(: default action:)
	if ($mapped-resource)
	then
		<ex:dispatch>
			<ex:forward url="{string($mapped-resource/@dest)}">
			</ex:forward>
		</ex:dispatch>
	else if ($redirected-resource)
	then
		<ex:dispatch>
			<ex:redirect url="{concat(string($redirected-resource/@redirect), 
				substring-after($exist:path, $redirected-resource/@start) )}"/>
		</ex:dispatch>
	else
		<ex:ignore>
  	  <ex:cache-control cache="yes"/>
		</ex:ignore>
)
