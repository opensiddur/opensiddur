xquery version "1.0";
(: controller for the builder application 
 : check for login.
 : if logged in, forward, else return to the user application 
 : TODO: forward instead to a welcome page!
 :
 : Copyright 2011 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Open Siddur Project
 : Licensed under the GNU Lesser General Public License version 3 or later
 :)
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
	at "/code/api/modules/data.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/code/modules/paths.xqm";
	
declare namespace ex="http://exist.sourceforge.net/NS/exist";

declare function local:redirect-nonexistent(
	$redirect-if-not-missing as element()
	) {
	(: nonexistent resources :)
	let $normalized-resource := replace($exist:resource, '/', '')
	let $missing-resources := ('edit-style.xql')
	return 
		if ($normalized-resource = $missing-resources)
		then
			<ex:dispatch>
				{
				if ($paths:debug)
				then
					util:log-system-out(('redirect ', $exist:resource, ' to na' ))
				else ()
				}
				<ex:forward url="/code/apps/builder/na.xql"/>
			</ex:dispatch>
		else (
			$redirect-if-not-missing,
			if ($paths:debug)
			then
				util:log-system-out(('redirect ', $exist:resource, ' to ', $redirect-if-not-missing ))
			else ()
		)
};

if (app:auth-user())
then
	if (empty($exist:resource) or $exist:resource = ('', '/'))
	then
		<ex:dispatch>
			<ex:redirect url="/code/apps/builder/my-siddurim.xql"/>
		</ex:dispatch>
	else
		let $item := request:get-parameter('item', ())
		let $doc-exists-ok :=
			if ($item = '')
			then false()
			else if ($item)
			then 
				let $doc := data:api-path-to-db($item)
				return
					not(util:is-binary-doc($doc)) and doc-available($doc)
			else 
				let $no-item-ok := ('my-siddurim.xql', 'edit-metadata.xql', 'notfound.xql', 'welcome.xql', 'search.xql')
				return 
					not(ends-with($exist:resource, '.xql')) or $exist:resource = $no-item-ok
		return
			if ($doc-exists-ok)
			then
				local:redirect-nonexistent(
					<ex:ignore/>
				)
			else
				local:redirect-nonexistent(
					<ex:dispatch>
						<ex:redirect url="/code/apps/builder/notfound.xql"/>
					</ex:dispatch>
				)
else
	local:redirect-nonexistent(
		<ex:dispatch>
			<ex:forward url="/code/apps/builder/welcome.xql"/>
		</ex:dispatch>
	)
	
