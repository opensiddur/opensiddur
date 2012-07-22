# 1917 JPS project Makefile
# for the Open Siddur project
# Copyright 2011-2012 Marc Stober and licensed under the LGPL

# Extracts text from public domain PDF format 1917 edition Tanakh
# supplied by JPS into XML suitable for reuse.

# Note: If Makefile changes, the whole thing will re-run.
 
# TODO: "Spell check" against a dictionary?
# TODO: Tidy?
# TODO: Extract Toc outline?
# TODO: other xmllint error about DTD?

# for now we are just building the test HTML
all: 1917JPS.html

scriptsdir = ../../code/input-conversion/1917JPS

# TODO this is a just a selection for this round of dev/test
genesis = 16,17,18,19,20,21,22,23,24,25
isaiah = 578,579,580,581,582
psalm150 = 1064

# Step 0: Converting PDF to XML...
# page 16=Genesis 1
# TODO: all the books/pages - at least some more samples to start
# TODO: separate files?
temp/pdf2txt.xml: Makefile
	mkdir -p temp
	pdf2txt.py -n -m 1049 -p $(genesis),$(isaiah),$(psalm150) -o temp/pdf2txt.xml Tanakh-JPS1917.pdf

# Step 1: Extract layout coordinates
temp/bbox2xywh.xml: $(scriptsdir)/bbox2xywh.xsl2 \
		temp/pdf2txt.xml
	../../lib/saxon -s temp/pdf2txt.xml -o temp/bbox2xywh.xml \
		$(scriptsdir)/bbox2xywh.xsl2

# Step 2: Group text into blocks
# TODO: see TODO's in xslt
# TODO: front matter tables, and other front matter
temp/get-blocks.xml: $(scriptsdir)/get-blocks.xsl2 \
		temp/bbox2xywh.xml
	../../lib/saxon -s temp/bbox2xywh.xml -o temp/get-blocks.xml \
		$(scriptsdir)/get-blocks.xsl2

# Step 3: Fixing chapter numbers and marking paragraphs...
temp/fix-chapter-numbers.xml: $(scriptsdir)/fix-chapter-numbers.xsl2 \
		temp/get-blocks.xml
	../../lib/saxon -s temp/get-blocks.xml -o temp/fix-chapter-numbers.xml \
		$(scriptsdir)/fix-chapter-numbers.xsl2

# Step 4: Merge adjacent text elements
temp/join-text.xml: $(scriptsdir)/join-text.xsl2 \
		temp/fix-chapter-numbers.xml
	../../lib/saxon -s temp/fix-chapter-numbers.xml -o temp/join-text.xml \
		$(scriptsdir)/join-text.xsl2

# Step 5: Flatten pages
temp/join-pages.xml: $(scriptsdir)/join-pages.xsl2 \
		temp/join-text.xml
	../../lib/saxon -s temp/join-text.xml -o temp/join-pages.xml \
		$(scriptsdir)/join-pages.xsl2

# Step 6: Small caps
temp/small-caps.xml: $(scriptsdir)/small-caps.xsl2 \
		temp/join-pages.xml
	../../lib/saxon -s temp/join-pages.xml -o temp/small-caps.xml \
		$(scriptsdir)/small-caps.xsl2

# Step 7: Final XML that should validate against custom XSD
1917JPS.xml: $(scriptsdir)/final.xsl2 \
		temp/small-caps.xml 1917JPS.xsd
	../../lib/saxon -s temp/small-caps.xml -o 1917JPS.xml \
		$(scriptsdir)/final.xsl2
	xmllint --noout 1917JPS.xml --schema 1917JPS.xsd

# HTML we can proofread, not neccessarily final/supported/canonical structure
# validate against schema
# TODO make validation its own step (but what's the target?)
# TODO see TODO's in XSD
1917JPS.html: $(scriptsdir)/test-html.xsl2 \
		1917JPS.xml	
	../../lib/saxon -s 1917JPS.xml -o 1917JPS.html \
		$(scriptsdir)/test-html.xsl2


# TODO: semi-final form (structured format organized by pages of PDF file):
# TODO: strip remaining whitespace-only nodes. also, normalize-space within text elements?
# TODO: "Lord" small caps.
#Tanakh-JPS1917-pdf-pages.xml:

# TODO: final form (organized by section, book, chapter, verse):
#Tanakh-JPS1917-canonical.xml:

# TODO: testing (see txt file), diff against other version from Efraim

# # p should NOT be a container like HTML since heirarchy is book, chapter, verse
# # TODO Isn't there a PDFMiner tool to get this from outline in PDF?
# toc.txt: Tanakh-JPS1917.xml $(scriptsdir)/toc.py
# # extract just the lines that *could* be in Table of Contents
# # to get it down to a manageable size
# # this includes page numbers and 22-point headings
# 	grep "font=\"1\"\|<page number" Tanakh-JPS1917.xml > toc.tmp
# # now run that through the python script to get the finished TOC
# 	$(scriptsdir)/toc.py toc.tmp
# # clean up temporary file
# 	rm toc.tmp

.PHONY: clean
clean:
	rm 1917JPS.xml
	rm 1917JPS.html
	mkdir -p temp
	rm -f temp/*
	rmdir temp

