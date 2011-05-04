#!/bin/sh
# Run the transforms on a given file
# Usage: ./transform.sh in-file out-file [transform-options]
#  $Id: transform.sh 435 2010-02-01 04:52:05Z efraim.feinstein $
SCRIPTPATH=$(dirname $(absolutize $0))
ST1PATH=$SCRIPTPATH/../code/transforms/stage1/stage1.xsl2
ST2PATH=$SCRIPTPATH/../code/transforms/stage2/stage2.xsl2
ST3PATH=$SCRIPTPATH/../code/transforms/xhtml/xhtml.xsl2
INFILE="$1"
OUTFILE="$2"
shift 2 
$SCRIPTPATH/saxon -ext:on -s "$INFILE" -o "$OUTFILE.stage1.xml" $ST1PATH $@ && $SCRIPTPATH/saxon -ext:on -s "$OUTFILE.stage1.xml" -o "$OUTFILE.stage2.xml" $ST2PATH $@ && $SCRIPTPATH/saxon -ext:on -s "$OUTFILE.stage2.xml" -o "$OUTFILE" $ST3PATH $@
#rm -f "$OUTFILE.stage1.xml" "$OUTFILE.stage2.xml"

