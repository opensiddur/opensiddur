#!/usr/bin/env python
#
# given a path to a backup, remove a selected set of files/directories by regexp
# 
# Open Siddur Project
# Copyright 2010-2013 Efraim Feinstein
# Licensed under the GNU Lesser General Public License, version 3 or later
#
import sys
import copy
import re
import os
import getopt
import time
from lxml import etree

exNS = 'http://exist.sourceforge.net/NS/exist'

def loadRegexps(f):
    return re.compile("|".join([line.strip() for line in f if line.strip()]))

def shouldRemove(pth, removeRegexps, elem):
    # return true if the file or collection referenced should be removed
    return (
        (pth.startswith("/db/data/") is not None and "owner" in elem.attrib and elem.attrib["owner"]=="SYSTEM")    # this is a clue that the file was autoinstalled
        or removeRegexps.match(pth) is not None
    )

def removeFromBackup(pathToContentXml, removeRegexps):
    contentPath = os.path.join(pathToContentXml, "__contents__.xml") 
    contentXml = etree.parse(contentPath)
    # find all subcollection and resource elements
    for candidate in contentXml.findall('.//{'+exNS+'}resource')+contentXml.findall('.//{'+exNS+'}subcollection'):
        if shouldRemove(os.path.join(re.sub("^.*/db", "/db", pathToContentXml), candidate.attrib["name"]), removeRegexps, candidate):
            # if shouldRemove, remove it
            candidate.getparent().remove(candidate)
        elif candidate.tag == "{"+exNS+"}subcollection":
            # if not and subcollection, recurse to that directory
            removeFromBackup(os.path.join(pathToContentXml, candidate.attrib["filename"]), removeRegexps)
    # rewrite out contentXml as it now stands:
    contentXml.write(contentPath)

if __name__ == "__main__":
    toRemove = loadRegexps(sys.stdin)
    removeFromBackup(sys.argv[1], toRemove)
