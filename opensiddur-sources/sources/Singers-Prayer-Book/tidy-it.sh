#!/bin/sh
# EDIT A LOCAL COPY OF THIS SCRIPT IF YOUR PATHS ARE DIFFERENT
# a simple command line to clean up the HTML
tidy --as-xml -n --wrap 0 --doctype omit spb2k.htm > spb2k.xhtml
../../branches/efraim/lib/saxon spb2k.xhtml spb2stml.xsl2  > spb.stml
