# 1917 JPS project Makefile
# Copyright 2011 Marc Stober and licensed under the LGPL

toc.txt: Tanakh-JPS1917.xml ../../code/input-conversion/1917JPS/toc.py
# extract just the lines that *could* be in Table of Contents
# to get it down to a manageable size
# this includes page numbers and 22-point headings
	grep "font=\"1\"\|<page number" Tanakh-JPS1917.xml > toc.tmp
# now run that through the python script to get the finished TOC
	../../code/input-conversion/1917JPS/toc.py toc.tmp
# clean up temporary file
	rm toc.tmp

# TODO: instead of this, loop through generated TOC above to generate books
# (make we actually generate another makefile with a bunch of lines like this?)
genesis.xml: toc.txt
	xsltproc --novalid --stringparam 'startpage' "16" --stringparam 'endpage' "90" \
		../../code/input-conversion/1917JPS/jps.xslt Tanakh-JPS1917.xml > genesis.xml

.PHONY: clean
clean:
	rm -f toc.txt
# TODO: all the books
	rm -f genesis.xml 
