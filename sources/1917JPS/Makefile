# 1917 JPS project Makefile
# for the OpenSiddur project
# Copyright 2011 Marc Stober and licensed under the LGPL

# Extracts text from public domain PDF format 1917 edition Tanakh
# supplied by JPS into XML suitable for reuse.

all: 1917JPS.xml \
		temp/sort-errors.txt # full build includes tests

# Extract from PDF to XML using PDFMiner.
# page 16=Genesis 1
# TODO: all the books/pages
# TODO: join Hebrew better (e.g., p. 16)
temp/1917JPS-pdf2txt.xml: Makefile
	mkdir -p temp
	pdf2txt.py -p 16,17,18 -o temp/1917JPS-pdf2txt.xml -t xml -W 1 Tanakh-JPS1917.pdf

# Clean of pdf2txt XML to make easier to work with.
temp/pdf2txt-clean.xml: ../../code/input-conversion/1917JPS/pdf2txt-clean.xslt \
		temp/1917JPS-pdf2txt.xml
	xsltproc ../../code/input-conversion/1917JPS/pdf2txt-clean.xslt \
	temp/1917JPS-pdf2txt.xml > temp/pdf2txt-clean.xml

# Sort text into header, footer, columns, and footnotes.
temp/columns.xml: ../../code/input-conversion/1917JPS/columns.xslt \
		temp/pdf2txt-clean.xml
	xsltproc ../../code/input-conversion/1917JPS/columns.xslt \
	temp/pdf2txt-clean.xml > temp/columns.xml

# Fix text that on the same line but out of order.
temp/fix-lines.xml: ../../code/input-conversion/1917JPS/fix-lines.xslt \
		temp/columns.xml
	xsltproc ../../code/input-conversion/1917JPS/fix-lines.xslt \
		temp/columns.xml > temp/fix-lines.xml

# Test for text on same line but out of order.
# TODO How to raise error in Makefile? How to make this raise error?
temp/sort-errors.txt: ../../code/input-conversion/1917JPS/test-sort.xslt \
		temp/fix-lines.xml
	xsltproc ../../code/input-conversion/1917JPS/test-sort.xslt \
	temp/fix-lines.xml > temp/sort-errors.txt

# TODO Step 4: Join paragraphs
# TODO "final"
1917JPS.xml: ../../code/input-conversion/1917JPS/1917JPS.xslt \
		temp/fix-lines.xml \
		temp/sort-errors.txt
	xsltproc ../../code/input-conversion/1917JPS/1917JPS.xslt \
	temp/fix-lines.xml > 1917JPS.xml

# TODO Isn't there a PDFMiner tool to get this from outline in PDF?
toc.txt: Tanakh-JPS1917.xml ../../code/input-conversion/1917JPS/toc.py
# extract just the lines that *could* be in Table of Contents
# to get it down to a manageable size
# this includes page numbers and 22-point headings
	grep "font=\"1\"\|<page number" Tanakh-JPS1917.xml > toc.tmp
# now run that through the python script to get the finished TOC
	../../code/input-conversion/1917JPS/toc.py toc.tmp
# clean up temporary file
	rm toc.tmp

.PHONY: clean
clean:
	mkdir -p temp
	rm -f temp/*
	rmdir temp

