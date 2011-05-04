#!/bin/bash
# revision.xml.sh
# output the revision.xml file, which contains the revision that this working copy is using
# under the @xml:id="CurrentRevision"
# Takes two parameters - the name of the file and the top level directory 
# $Id: revision.xml.sh 99 2008-12-26 05:33:44Z efraim.feinstein $
cat > "$1" << EOF
<?xml version="1.0" encoding="utf8"?>
<div xmlns="http://www.tei-c.org/ns/1.0">
	<seg xml:id="CurrentRevision">$(svnversion -n "$2")</seg>
</div>
EOF