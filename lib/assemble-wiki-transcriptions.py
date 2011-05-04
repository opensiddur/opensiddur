#!/usr/bin/env python
# 
# Script to assemble transcriptions from the wiki into a text file and optionally add contributor tag identifiers by 
# page
#
# Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
#
# This script is released under the GNU Lesser General Public License, version 3, 
# or at your option, any later version.
import sys
import getopt
import codecs
import httplib
import re
from StringIO import StringIO

# --- EDIT HERE ---
addContributorTags = False		# set to False to remove contributor tags
outputFileName='Psalms.raw.txt'
#outputFileName='Nehemiah.raw.txt'
contributorsFileName='Contributors.txt'

# bookbases = (name, digits, start, end, suffix)
#bookbases=[("38neh_", 4, 1, 19, "-English")]
bookbases=[("27psa-a_", 4, 1, 53, "-English"), ("28psa-b_", 4, 1, 53, "-English")]
#bookbases=[("39ch1_", 4, 1, 36, "-English")]

try:
	opts, args = getopt.getopt(sys.argv[1:], "o:c:s:b:d:f:l:e:t", ["output=", "contributors=","server=", "base=", "digits=","first=","last=","extension=","contribtags"])
except getopt.GetoptError, err:
	print str(err)
	usage()
	sys.exit(2)

server="wiki.jewishliturgy.org"

for o, a in opts:
	if o in ("-o","--output"):
		outputFileName = a
	elif o in ("-c","--contributors"):
		contributorsFileName = a
	elif o in ("-s","--server"):
		server = a
	elif o in ("-b", "--base"):
		bookbase = a.split(',')
	elif o in ("-d","--digits"):
		bookdigits = a.split(',')
		assert len(bookdigits) == len(bookbase), "Digits must have the same number of comma-separated elements as base."
	elif o in ("-f","--first"):
		bookfirst = a.split(',')
		assert len(bookfirst) == len(bookbase), "First must have the same number of comma-separated elements as base."
	elif o in ("-l","--last"):
		booklast = a.split(',')
		assert len(booklast) == len(bookbase), "Last must have the same number of comma-separated elements as base."
	elif o in ("-e", "--extension"):
		bookextension = a.split(',')
		assert len(bookextension) == len(bookbase), "Extension must have the same number of comma-separated elements as base."
	elif o in ("-t","--contribtags"):
		addContributorTags = True
	else:
		assert False, "unhandled option"
	
bookbases = [(bookbase[j], int(bookdigits[j]), int(bookfirst[j]), int(booklast[j]), bookextension[j]) for j in xrange(0,len(bookbase))]

# --- NO NEED TO EDIT BEYOND HERE ----
pagebase="/w/index.php?title=Page:%s%s%s.jpg&action="

#combinedString = u''
contributors = {}

#replaceCode=u'(</?(noinclude|div|references).*>)|({{.*}})'
replaceCode=u'<noinclude>.*?</noinclude>'
reReplace = re.compile(replaceCode, re.UNICODE|re.MULTILINE|re.DOTALL)

findContributors=u'title="User:([^"]+)"'
reContributors = re.compile(findContributors)

outputFile=codecs.open(outputFileName,'w','utf8')
contributorsFile=codecs.open(contributorsFileName,'w','utf8')

for bkbase in bookbases:
	digitsStr = "%%0%dd" % bkbase[1]
	for page in xrange(bkbase[2], bkbase[3]+1):
		pageurl = pagebase % (bkbase[0], digitsStr % page, bkbase[4])
		conn = httplib.HTTPConnection(server)
		conn.request("GET", pageurl+"raw")
		r1 = conn.getresponse()
		print >>sys.stderr, pageurl+"raw", ':', r1.status, r1.reason
		if (r1.status == 200):
			data = unicode(r1.read(),'utf8')
		else: 
			data = u''

		pageContributors = {}
		r2 = conn.request("GET", pageurl+"history")
		r2 = conn.getresponse()
		hdata = unicode(r2.read(),'utf8')
		print >>sys.stderr, pageurl+"history", ':', r2.status, r2.reason
		#print hdata.encode('utf8')
		if (r2.status == 200):
			for match in reContributors.findall(hdata):
				xmatch = match.replace(' (not yet written)','')
				try:
					pageContributors[xmatch] += 1
				except KeyError:
					pageContributors[xmatch] = 1

		contributors.update(pageContributors)
		conn.close()
		rdata=u''
		if (addContributorTags and pageContributors):
			rdata = rdata + '{contrib '
			for pageContributor in pageContributors:
				rdata = rdata + '"' + pageContributor + '" '
			rdata = rdata[:-1] + '}\n'
		rdata=rdata + reReplace.sub(u'',data)
		if (rdata[-1] != u'\n'):
			# add the last \n if it's not there
			rdata = rdata + u'\n'
		#combinedString += rdata
		outputFile.write(rdata)

for k in contributors.keys():
	print >>contributorsFile,k
outputFile.close()
contributorsFile.close()
