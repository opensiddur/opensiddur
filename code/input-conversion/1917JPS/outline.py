#!/usr/bin/env python
# Extract the outline (table of contents) from the PDF
# and generate an XSL template.
# For the 1917 JPS PDF extraction project for the Open Siddur Project.
# Copyright 2011-12 Marc Stober and licensed under the terms of the LGPL

import os.path
import pprint
import sys
from pdfminer.pdfparser import PDFParser, PDFDocument

def get_toc():
	fp = open('Tanakh-JPS1917.pdf', 'rb')
	parser = PDFParser(fp)
	doc = PDFDocument()
	parser.set_document(doc)
	doc.set_parser(parser)
	#doc.initialize(password)

	# Get the page numbers for the page object ID's.
	p = 0
	pageNumbers = {}
	for page in doc.get_pages():
		p += 1
		pageNumbers[page.pageid] = p

	# now what we really want is just the TOC for what was passed in


	# Get the outlines of the document.
	outlines = doc.get_outlines()
	toc = []
	location = [''] * 3
	for (level,title,dest,a,se) in outlines:
		title = title.replace(chr(10), '').replace(chr(13), '').strip()
		# skip the individual chapter number nodes
		if level < 4 and not title.isdigit():
			location[level - 1] = title
			# Get the destination page number from the action.
			# Thanks to https://groups.google.com/d/topic/pdfminer-users/KwMJHZTCKbE/discussion
			pageid = a.resolve()['D'][0].objid
			entry = location[:level]
			entry.append(pageNumbers[pageid])
			toc.append(entry)

	if len(sys.argv) == 1:
		return toc

	# If a specific list of pages from the original PDF were specified,
	# create a custom TOC where the page number is the 1-based index of this page
	# in the set of pages; 
	# i.e., the same as the page id in the XML produced
	# when that list of pages is passed in to pdf2txt.py.

	selectedPages = sys.argv[1]
	selectedPages = [int(pnum) for pnum in selectedPages.split(',')]
	customToc = []
	for pn, pnum in enumerate(selectedPages):
		# walk backward to see what section we're in
		for entry in reversed(toc):
			if pnum >= entry[-1]:
				#print pn + 1
				entry[-1] = pn + 1
				# is it same as previous? if not:
				if (pn == 0 and len(customToc) == 0) or entry[:-1] != customToc[-1][:-1]:
				#if entry[:-1] != customToc[-1][:-1]:
					#print 'appending ' + str(entry) + '...'
					customToc.append(entry[:])
				break

	return customToc

def generate_xsl(toc):

	# TODO: read template
	template_file = open(os.path.splitext(__file__)[0] + '.xsl2.template')
	template = template_file.readlines()
	template_file.close()

	for line in template:
		print line.strip()
		if 'GENERATE CODE HERE' in line:
			generate_xsl_sections(toc)
	
	return

def generate_xsl_sections(toc):

	previous_entry = []
	previous_level = -1
	for n, entry in enumerate(toc):
		for level, title in enumerate(entry[:-1]):
			if level >= len(previous_entry):
				same = False
			else:
				same = (title == previous_entry[level])
			if not same:
				close_previous_elements(level, previous_level)

				indent = level * '  '
				if level == 0:
					element_name = 'section'
				elif level == 1 and entry[1] == 'THE TWELVE':
					element_name = 'subsection'
				elif level == 1:
					element_name = 'book'
				elif level == 2 and entry [1] == 'PSALMS':
					element_name = 'subsection'
				elif level == 2:
					element_name = 'book'
				else:
					raise Exception() # not expecting this

				print '%s<xsl:element name="%s">' % (indent, element_name)
				print '%s  <xsl:attribute name="id">%s</xsl:attribute>' % (
					indent, title)

				if level == len(entry) - 2: # leaf node
					if n + 1 < len(toc):
						next_entry = toc[n + 1]
						xpath = 'page[@id >= %s and @id &lt; %s]' % (
							entry[-1], next_entry[-1])
					else: # last section
						xpath = 'page[@id >= %s]' % (entry[-1])
					print '%s  <xsl:apply-templates select="%s"/>' % (
						indent, xpath)

				previous_level = level

		previous_entry = entry

	close_previous_elements(0, previous_level)

	# TODO: finish the template

	return

def close_previous_elements(level, previous_level):
	levels_to_close = previous_level - level + 1
	if levels_to_close > 0:
		for i in reversed(range(level, previous_level + 1)):
			print (i * '  ') + '</xsl:element>'

	return

if __name__ == '__main__':
	toc = get_toc()
	#pprint.pprint(toc) # debugging
	generate_xsl(toc)
