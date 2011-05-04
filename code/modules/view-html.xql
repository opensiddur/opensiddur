(: view-html.xql
 : Accepts one required parameter ?doc=<document name> 
 : Attempt to read the html file it points to, run a small XSLT script to
 : set a base URI, and set its doctype.
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim.feinstein@gmail.com>
 : Licensed under the GNU Lesser General Public License version 3 or later
 : $Id: view-html.xql 706 2011-02-21 01:18:10Z efraim.feinstein $
 :)
xquery version "1.0";

import module namespace transform="http://exist-db.org/xquery/transform";
import module namespace xsl="http://www.w3.org/1999/XSL/Transform";

import module namespace app="http://jewishliturgy.org/modules/app" 
  at "/db/code/modules/app.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths" 
  at "/db/code/modules/paths.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare option exist:serialize "method=xhtml media-type=text/html omit-xml-declaration=no indent=no 
        doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
        doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd";

(: transform to convert link elements into inline style 
 : to avoid authentication issues :)
declare function local:identity(
	$data as node()
	) as node() {
	typeswitch ($data)
	case element() return (
		element { node-name($data) }{
			$data/@*, local:transform($data/node())
		}
	)
	default	return $data
};

declare function local:transform-link(
  $data as element(link)
  ) as element(style) {
  if ($data/@type='text/css' and $data/@rel='stylesheet')
  then (
    <style type="text/css">{
      comment {
        util:binary-to-string(
          util:binary-doc(resolve-uri($data/@href, base-uri($data)))
        )
      }
    }</style>
  )
  else local:identity($data)
};

declare function local:doc-node(
  $data as document-node()
  ) as document-node() {
  document {
    local:transform($data/node())
  }
};

declare function local:transform(
	$data as node()*
	) { 
	for $node in $data
	return (
		typeswitch ($node)
		case text() return $node
    case document-node() return local:doc-node($node)
		case element(link) return local:transform-link($node)
		default return local:identity($node)
	)
};
 

let $authentication := app:authenticate()
let $src := request:get-parameter('doc','')
let $doc := doc($src)
let $base := resolve-uri($src, $paths:external-rest-prefix)
return
  local:transform($doc)
