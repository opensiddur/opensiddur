#!/bin/sh
# Run the transliterator on a text file in standalone mode
# Usage: ./translit.sh in-file out-file
#  $Id: translit.sh 490 2010-03-22 20:09:44Z efraim.feinstein $
SCRIPTPATH=$(dirname $(absolutize $0))
RELPATH=$SCRIPTPATH/../code/transforms/stage1
INPUT="$1"
OUTPUT="$2"
shift 2
$SCRIPTPATH/saxon -ext:on  -it:main  $RELPATH/translit.xsl2 input-filename="$INPUT" output-filename="$OUTPUT" $@
