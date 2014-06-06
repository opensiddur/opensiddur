# 1917 JPS project Makefile
# for the Open Siddur project
# Copyright 2011-2013 Marc Stober and licensed under the LGPL

# Extracts text from public domain PDF format 1917 edition Tanakh
# supplied by JPS into XML suitable for reuse.

# TODO: Makefile and Makefile.book were split apart, needs cleanup

# TODO: "Spell check" against a dictionary?
# TODO: Tidy?

saxon = ../../lib/saxon
code = ../../code/input-conversion/1917JPS
# TODO do I need this?
book = 1917JPS
book_temp = temp/book

# This rule will run by default and do everything.
books: temp/Makefile.books.generated books/index.html 
	# call makefile that knows about all the books
	# TODO: variable for 1st dependency?
	make -f temp/Makefile.books.generated
	# Change underscores to spaces.
	# Why spaces? Consistency with 
	#	https://github.com/blockspeiser/Sefaria-Data/tree/master/sources/JPS1917/usfm-raw
	# Then why underscores? Because make doesn't play nice with spaces.
	rename 's/_/ /g' books/*_*

temp: 
	@# TODO cleanup temp directory
	mkdir -p $@

temp/Makefile.books.generated: temp $(code)/outline.py Makefile
	# generate the makefile that knows about all the books
	$(code)/outline.py -m > $@

# Make the big XML file.
# N.B. the pipe for an "order-only" dependency; makes sure temp folder created
#	but prevents running this every time contents of temp folder are touched!
#	See: https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html
temp/Tanakh-JPS1917.pdf2txt.xml: | temp
	# Takes a few minutes and generates a 300MB file.
	pdf2txt.py -n -o $@ Tanakh-JPS1917.pdf
	# Optimize file by removing repeated font name.
	sed -i 's/font="Times New Roman" //' temp/Tanakh-JPS1917.pdf2txt.xml

books/index.html: $(code)/outline.py Makefile blank.xml \
		$(code)/join-pages.xsl2 $(code)/final.xsl2 $(code)/index.xsl2 \
		$(code)/index.template.html
	# TODO put template in dependencies?
	mkdir -p temp/index
	mkdir -p books
	# TODO cf. use of outline.py below? Still need both?
	$(code)/outline.py > temp/index/index.xsl2
	# TODO blank.xml stub hopefully just a temporary thing
	$(saxon) -s blank.xml -o temp/index/index.xml \
		temp/index/index.xsl2
	$(saxon) -s temp/index/index.xml -o temp/index/index2.xml \
		$(code)/join-pages.xsl2
	$(saxon) -s temp/index/index2.xml -o temp/index/index3.xml \
		$(code)/final.xsl2
	# TODO xml version to keep?
	$(saxon) -s temp/index/index3.xml -o temp/index/index.html \
		$(code)/index.xsl2
	$(code)/include.py temp/index/index.html \
		$(code)/index.template.html > $@

# TODO this is a just a selection for this round of dev/test
genesis = 16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90
isaiah = 578,579,580,581,582
# TODO Jonah doesn't include Jonah because it starts mid-page
jonah = 886
psalm150 = 1064
lamentations = 1180,1181,1182,1183,1184,1185,1186,1187,1188,1189
pages = $(genesis),$(isaiah),$(psalm150),$(lamentations)
#pages = 42,$(lamentations) # debugging

# ** These get called per-book 
# ** from generated Makefile (Makefile.books.generated).

book: clean_book_temp books/$(book).html

# When making a book, start clean so we don't get mixed up with another book.
clean_book_temp:
	rm -rf $(book_temp)
	@# Save a backup of last book for debugging.
	@#rm -rf $(book_temp).bak
	@#if [ -d "$(book_temp)" ]; then mv $(book_temp) $(book_temp).bak; fi

$(book_temp): 
	@tput bold	
	@echo "> Making $(book)..."
	@tput sgr0
	# TODO cleanup?
	mkdir -p $(book_temp)

$(book_temp)/get-pages.xml: $(book-temp) temp/Tanakh-JPS1917.pdf2txt.xml
	# Get pages from the big XML file
	$(code)/get-pages.py $(pages) temp/Tanakh-JPS1917.pdf2txt.xml > $@

books/$(book).xml: $(book_temp) $(book_temp)/get-pages.xml Makefile
	# Step 1: Extract layout coordinates
	$(saxon) -s $(book_temp)/get-pages.xml -o $(book_temp)/bbox2xywh.xml \
		$(code)/bbox2xywh.xsl2

	# Step 2: Group text into blocks
	# TODO: see TODO's in xslt
	# TODO: front matter tables, and other front matter
	$(saxon) -s $(book_temp)/bbox2xywh.xml -o $(book_temp)/get-blocks.xml \
		$(code)/get-blocks.xsl2

	# Step 2.5: Fix Hebrew characters in wrong order
	$(saxon) -s $(book_temp)/get-blocks.xml -o $(book_temp)/fix-hebrew.xml \
		$(code)/fix-hebrew.xsl2

	# Step 3: Fix chapter numbers and mark paragraphs
	$(saxon) -s $(book_temp)/fix-hebrew.xml -o $(book_temp)/fix-chapter-numbers.xml \
		$(code)/fix-chapter-numbers.xsl2

	# Step 3.5: Fix apostrophe-s and smart quote issues
	$(saxon) -s $(book_temp)/fix-chapter-numbers.xml -o $(book_temp)/fix-apostrophe-s.xml \
		$(code)/fix-apostrophe-s.xsl2

	# Step 4: Merge adjacent text elements
	$(saxon) -s $(book_temp)/fix-apostrophe-s.xml -o $(book_temp)/join-text.xml \
		$(code)/join-text.xsl2

	# Step 4.4: Generate outline, custom based on selected pages
	# needs dependency on Makefile since that's how we select pages
	$(code)/outline.py $(pages) > $(book_temp)/outline.xsl2

	# Step 4.5: Group pages using generated outline.
	# (Different than other steps, because the XSLT is generated.)
	$(saxon) -s $(book_temp)/join-text.xml -o $(book_temp)/outline.xml \
		$(book_temp)/outline.xsl2

	# Step 5: Flatten pages (within sections)
	$(saxon) -s $(book_temp)/outline.xml -o $(book_temp)/join-pages.xml \
		$(code)/join-pages.xsl2

	# Step 6: Small caps
	$(saxon) -s $(book_temp)/join-pages.xml -o $(book_temp)/small-caps.xml \
		$(code)/small-caps.xsl2

	# Step 7: Final XML that should validate against custom XSD
	$(saxon) -s $(book_temp)/small-caps.xml -o 'books/$(book).xml' \
		$(code)/final.xsl2
	# validate against schema
	# TODO make validation its own step (but what's the target?)
	# TODO see TODO's in XSD
	# TODO also use xmllint to format XML?
	xmllint --noout "books/$(book).xml" --schema 1917JPS.xsd
	echo $?

books/$(book).html: books/$(book).xml
	# HTML we can proofread, not neccessarily final/supported/canonical structure
	$(saxon) -s $< -o $@ \
		$(code)/test-html.xsl2

# TODO: semi-final form (structured format organized by pages of PDF file):
# TODO: strip remaining whitespace-only nodes. also, normalize-space within text elements?
#Tanakh-JPS1917-pdf-pages.xml:

# TODO: final form (organized by section, book, chapter, verse):
#Tanakh-JPS1917-canonical.xml:

# TODO: testing (see txt file), diff against other version from Efraim

# # p should NOT be a container like HTML since heirarchy is book, chapter, verse
# # TODO Isn't there a PDFMiner tool to get this from outline in PDF?
# toc.txt: Tanakh-JPS1917.xml $(code)/toc.py
# # extract just the lines that *could* be in Table of Contents
# # to get it down to a manageable size
# # this includes page numbers and 22-point headings
# 	grep "font=\"1\"\|<page number" Tanakh-JPS1917.xml > toc.tmp
# # now run that through the python script to get the finished TOC
# 	$(code)/toc.py toc.tmp
# # clean up temporary file
# 	rm toc.tmp

.PHONY: clean clean_quick clean_temp clean_book_temp

# Clean everything that gets built.
clean: clean_temp
	rm books/*

# Clean temp files, leave build outputs.
clean_temp:
	rm -rf temp

# Clean except the big XML file that rarely changes
# and takes a long time to generate.
clean_quick:
	@#find temp/* -type d -exec rm -rf {} \;
	@# Supposedly this is faster:
	find temp/* -type d -print0 | xargs -0 rm -rf
	rm -rf books/*

