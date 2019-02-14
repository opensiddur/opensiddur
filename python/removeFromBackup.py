#!/usr/bin/env python3
#
# given a path to a backup, remove a selected set of files/directories by regexp
# 
# Open Siddur Project
# Copyright 2010-2014,2019 Efraim Feinstein
# Licensed under the GNU Lesser General Public License, version 3 or later
#
import sys
import re
import os
import shutil
import argparse
from lxml import etree

exNS = 'http://exist.sourceforge.net/NS/exist'

verbose = False

def load_regexps(f):
    return re.compile("|".join([line.strip() for line in f if line.strip()]))


def should_remove(pth, remove_regexps, elem, remove_system_files):
    # return true if the file or collection referenced should be removed
    return (
        (  # this is a clue that the file was autoinstalled
            (pth.startswith("/db/data/") and "owner" in elem.attrib and elem.attrib["owner"] == "SYSTEM")
            if remove_system_files
            else False
        )
        or remove_regexps.match(pth) is not None
    )


def remove_from_filesystem(directory, filename):
    full_path = os.path.join(directory, filename)
    try:
        if verbose:
            print("Removing ", full_path)
        os.remove(full_path)
    except OSError:  # it's a directory
        shutil.rmtree(full_path)


def remove_from_backup(path_to_content_xml, remove_regexps, remove_system_files):
    content_path = os.path.join(path_to_content_xml, "__contents__.xml")
    content_xml = etree.parse(content_path)
    # find all subcollection and resource elements
    for candidate in content_xml.findall('.//{' + exNS + '}resource') + content_xml.findall('.//{' + exNS + '}subcollection'):
        db_path = re.sub("^.*/db", "/db", path_to_content_xml)
        if should_remove(os.path.join(db_path, candidate.attrib["name"]), remove_regexps, candidate, remove_system_files):
            # if shouldRemove, remove it
            candidate.getparent().remove(candidate)
            remove_from_filesystem(path_to_content_xml, candidate.attrib["filename"])
        elif candidate.tag == "{"+exNS+"}subcollection":
            # if not and subcollection, recurse to that directory
            remove_from_backup(os.path.join(path_to_content_xml, candidate.attrib["filename"]),
                               remove_regexps, remove_system_files)
    # rewrite out content_xml as it now stands:
    content_xml.write(content_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--include_system_files', action="store_false", dest="remove_system_files", default=True)
    parser.add_argument('-v', '--verbose', action="store_true", dest="verbose", default=False)
    parser.add_argument("path", action="store")
    args = parser.parse_args()

    verbose = args.verbose
    toRemove = load_regexps(sys.stdin)
    remove_from_backup(args.path, toRemove, args.remove_system_files)
