# 1917 JPS project Makefile
# for the OpenSiddur project
# Copyright 2011 Marc Stober and licensed under the LGPL

# Extracts text from public domain PDF format 1917 edition Tanakh
# supplied by JPS into XML suitable for reuse.

all: Tanakh-JPS1917-canonical.xml

# TODO: algorithm for -n mode:
# insert <paragraph-break> when
# - before chapter number
# - if x < previous-x and (x = 46.824 or x = 232.479)
# problem with -n mode: chapter numbers in wrong place

# Step 0: Converting PDF to XML...
# page 16=Genesis 1
# TODO: all the books/pages
temp/pdf2txt.xml: Makefile
	mkdir -p temp
	pdf2txt.py -n -m 21 -p 16,17,18,19,20,21 -o temp/pdf2txt.xml Tanakh-JPS1917.pdf

# Step 1: Extracting layout coordinates...
temp/bbox2xywh.xml: ../../code/input-conversion/1917JPS/bbox2xywh.xsl2 \
		temp/pdf2txt.xml
	../../lib/saxon -s temp/pdf2txt.xml -o temp/bbox2xywh.xml \
		../../code/input-conversion/1917JPS/bbox2xywh.xsl2

# Step 2: Grouping text into blocks...
# TODO: see TODO's in xslt
# TODO: front matter tables
temp/get-blocks.xml: ../../code/input-conversion/1917JPS/get-blocks.xsl2 \
		temp/bbox2xywh.xml
	../../lib/saxon -s temp/bbox2xywh.xml -o temp/get-blocks.xml \
		../../code/input-conversion/1917JPS/get-blocks.xsl2

# Step 3: Fixing chapter numbers and marking paragraphs...
# TODO: paragraphs in footnotes and elsewhere?
temp/fix-chapter-numbers.xml: ../../code/input-conversion/1917JPS/fix-chapter-numbers.xsl2 \
		temp/get-blocks.xml
	../../lib/saxon -s temp/get-blocks.xml -o temp/fix-chapter-numbers.xml \
		../../code/input-conversion/1917JPS/fix-chapter-numbers.xsl2

# Step 4: Merge adjacent text elements
# TODO: merge space-only text element with preceding
temp/join-text.xml: ../../code/input-conversion/1917JPS/join-text.xsl2 \
		temp/fix-chapter-numbers.xml
	../../lib/saxon -s temp/fix-chapter-numbers.xml -o temp/join-text.xml \
		../../code/input-conversion/1917JPS/join-text.xsl2

# TODO: semi-final form (structured format organized by pages of PDF file):
#Tanakh-JPS1917-pdf-pages.xml:

# TODO: final form (organized by section, book, chapter, verse):
#Tanakh-JPS1917-canonical.xml:

# # old approach
# # Clean of pdf2txt XML to make easier to work with.
# temp/pdf2txt-clean.xml: ../../code/input-conversion/1917JPS/pdf2txt-clean.xslt 
# 		temp/1917JPS-pdf2txt.xml
# 	xsltproc ../../code/input-conversion/1917JPS/pdf2txt-clean.xslt \
# 	temp/1917JPS-pdf2txt.xml > temp/pdf2txt-clean.xml

# # Fix text that on the same line but out of order.
# # TODO: fix characters ("text" elements, e.g. heb. beresit above Gen. 1)
# temp/fix-lines.xml: ../../code/input-conversion/1917JPS/fix-lines.xslt \
# 		temp/columns.xml
# 	xsltproc ../../code/input-conversion/1917JPS/fix-lines.xslt \
# 		temp/columns.xml > temp/fix-lines.xml

# # Test for text on same line but out of order.
# # TODO How to raise error in Makefile? How to make this raise error?
# temp/sort-errors.txt: ../../code/input-conversion/1917JPS/test-sort.xslt \
# 		temp/fix-lines.xml
# 	xsltproc ../../code/input-conversion/1917JPS/test-sort.xslt \
# 	temp/fix-lines.xml > temp/sort-errors.txt

# # TODO Step 4: Join paragraphs
# # for each textline: if new paragraph
# # p should NOT be a container like HTML since heirarchy is book, chapter, verse
# # TODO "final"
# 1917JPS.xml: ../../code/input-conversion/1917JPS/1917JPS.xslt \
# 		temp/fix-lines.xml \
# 		temp/sort-errors.txt
# 	xsltproc ../../code/input-conversion/1917JPS/1917JPS.xslt \
# 	temp/fix-lines.xml > 1917JPS.xml

# # TODO Isn't there a PDFMiner tool to get this from outline in PDF?
# toc.txt: Tanakh-JPS1917.xml ../../code/input-conversion/1917JPS/toc.py
# # extract just the lines that *could* be in Table of Contents
# # to get it down to a manageable size
# # this includes page numbers and 22-point headings
# 	grep "font=\"1\"\|<page number" Tanakh-JPS1917.xml > toc.tmp
# # now run that through the python script to get the finished TOC
# 	../../code/input-conversion/1917JPS/toc.py toc.tmp
# # clean up temporary file
# 	rm toc.tmp

.PHONY: clean
clean:
	rm Tanakh-JPS1917-pdf-pages.xml	
	rm Tanakh-JPS1917-canonical.xml
	mkdir -p temp
	rm -f temp/*
	rmdir temp

