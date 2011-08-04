# 1917 JPS project Makefile
# Copyright 2011 Marc Stober and licensed under the LGPL

# given the PDF from JPS

all: 18.xml

# todo put PDFMiner out put in a folder or something?
18.pdf2txt.xml: Makefile
	pdf2txt.py -p 18 -o 18.pdf2txt.xml -t xml -W 1 Tanakh-JPS1917.pdf

18.xml: ../../code/input-conversion/1917JPS/Tanakh-JPS1917.pdf2txt.xslt 18.pdf2txt.xml
	xsltproc ../../code/input-conversion/1917JPS/Tanakh-JPS1917.pdf2txt.xslt \
	18.pdf2txt.xml > 18.xml

# page 16=genesis 1
16.html: ../../code/input-conversion/1917JPS/jps2.xslt
	xsltproc ../../code/input-conversion/1917JPS/jps2.xslt Tanakh-JPS1917.xml > 16.html

17.html: ../../code/input-conversion/1917JPS/jps2.xslt
	xsltproc --stringparam 'page' "17" \
	../../code/input-conversion/1917JPS/jps2.xslt Tanakh-JPS1917.xml > 17.html

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
# TODO: all the books/page
	rm -f genesis.xml 
	rm -f 16.html
