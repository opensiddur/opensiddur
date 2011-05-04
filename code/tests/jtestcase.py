#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Base class for test cases
#
# Copyright 2009 Efraim Feinstein
# Licensed under the GNU Lesser General Public License, version 3 or later
# $Id: jtestcase.py 687 2011-01-23 23:36:48Z efraim.feinstein $
import StringIO
import lxml.etree

import unittest
import existdb

class JTestCase(unittest.TestCase):
    # namespaces:
    XML = 'http://www.w3.org/1998/namespace'
    TEI = 'http://www.tei-c.org/ns/1.0'
    J = 'http://jewishliturgy.org/ns/jlptei/1.0'
    JX = 'http://jewishliturgy.org/ns/jlp-processor'
    EXIST = 'http://exist.sourceforge.net/NS/exist'
    namespaces = {'tei':TEI,
        'exist':EXIST,
        'j':J,
        'jx':JX}
        
    def __init__(self, server='localhost', port=8080, user='tests', password='tests'):
        self.database=existdb.Existdb(server, port, user, password)
        unittest.TestCase.__init__(self)

    def toTree(self, data):
        """ Convenience function.  Return an lxml.etree from XML data """
        return lxml.etree.parse(StringIO.StringIO(data))


    def upload(self, documentFile, documentLocation):
        """ Upload a document to the db """
        document = file(documentFile, 'r')
        (status, reason, data) = self.database.put(
            documentLocation, document.read())
        document.close()
        self.assertEqual(status, 201, self.serverErrorMsg(
            'cannot load %s to database' % (documentFile),
            status, reason, data))
        
    def serverErrorMsg(self, msg, status, reason, data):
        return ('%s\n' % (msg) + 
            'status: %s %s\n' % (status, reason) +
            '%s' % (data))
        
