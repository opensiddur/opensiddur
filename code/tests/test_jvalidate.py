#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Unit tests for the jvalidate module
#
# Copyright 2009 Efraim Feinstein
# Licensed under the GNU Lesser General Public License, version 3 or later
# $Id: test_jvalidate.py 411 2010-01-03 06:58:09Z efraim.feinstein $
import unittest

import jtestcase

class TestValidate(jtestcase.JTestCase):
    def setUp(self):
        self.validFile = 'minimal-valid.xml'
        self.validDocumentLocation = '/db/tests/%s' % self.validFile
        self.invalidFile = 'minimal-invalid.xml'
        self.invalidDocumentLocation = '/db/tests/%s' % self.invalidFile
        
        self.upload(self.validFile, self.validDocumentLocation)
        self.upload(self.invalidFile, self.invalidDocumentLocation)
    
    def testValidateValid(self):
        """ Test on valid XML data """
        validateQuery = 'test_jvalidate_rngxsd.xql'
        (status, response, data) = self.database.postQueryFile(validateQuery, 
            postLocation=self.validDocumentLocation)
        self.assertEqual(status, 200, data)
        docXml = self.toTree(data)
        # assert that both relaxng and xsd say the file is valid
        self.assert_(docXml.xpath(
            '/exist:result/tests/relaxng/report/status/text()[.="valid"]'+
            ' and '+
            '/exist:result/tests/xsd/report/status/text()[.="valid"]', 
            namespaces=self.namespaces), data)
        # assert that both the relaxng and xsd results converted to boolean
        # are true
        self.assert_(docXml.xpath(
            '/exist:result/tests/relaxng-bool/text()[.="true"] and '+
            '/exist:result/tests/xsd-bool/text()[.="true"]', 
            namespaces=self.namespaces), data)
    
    def testSchematronValid(self):
        """ Schematron that should succeed """
        validateQuery = 'test_jvalidate_sch.xql'
        (status, response, data) = self.database.postQueryFile(validateQuery, 
            postLocation=self.validDocumentLocation)
        self.assertEqual(status, 200, data)
        docXml = self.toTree(data)
        
        self.assert_(docXml.xpath(
            '/exist:result/tests/sch/report/status/text()[.="valid"]',
            namespaces=self.namespaces), data)
        self.assert_(docXml.xpath(
            '/exist:result/tests/sch-bool/text()[.="true"]',
            namespaces=self.namespaces), data)
        
    def testSchematronInvalid(self):
        """ Schematron that should fail """
        validateQuery = 'test_jvalidate_sch.xql'
        (status, response, data) = self.database.postQueryFile(validateQuery, 
            postLocation=self.invalidDocumentLocation)
        self.assertEqual(status, 200, data)
        docXml = self.toTree(data)
        
        self.assert_(docXml.xpath(
            '/exist:result/tests/sch/report/status/text()[.="invalid"]',
            namespaces=self.namespaces), data)
        self.assert_(docXml.xpath(
            '/exist:result/tests/sch-bool/text()[.="false"]',
            namespaces=self.namespaces), data)
        
    
    def testValidateInvalid(self):
        """ Test on invalid XML data """
        validateQuery = 'test_jvalidate_rngxsd.xql'
        (status, response, data) = self.database.postQueryFile(validateQuery, 
            postLocation=self.invalidDocumentLocation)
        self.assertEqual(status, 200, data)
        docXml = self.toTree(data)
        # assert that both relaxng and xsd say the file is invalid
        self.assert_(docXml.xpath(
            '/exist:result/tests/relaxng/report/status/text()'+
            '[.="invalid"] and'
            '/exist:result/tests/xsd/report/status/text()'+
            '[.="invalid"]', 
            namespaces=self.namespaces), data)
        # assert that both the relaxng and xsd results converted to boolean
        # are false
        self.assert_(docXml.xpath(
            '/exist:result/tests/relaxng-bool/text()[.="false"] and'+
            '/exist:result/tests/xsd-bool/text()[.="false"]', 
            namespaces=self.namespaces), data)
    
    def tearDown(self):
        (status, reason, data) = self.database.delete(
            self.validDocumentLocation)
        self.assertEqual(status, 200, self.serverErrorMsg(
            'cannot delete %s from database' % self.validDocumentLocation, 
            status, reason, data))
        (status, reason, data) = self.database.delete(
            self.invalidDocumentLocation)
        self.assertEqual(status, 200, self.serverErrorMsg(
            'cannot delete %s from database' % self.invalidDocumentLocation, 
            status, reason, data))
    
            
if __name__ == "__main__":
    unittest.main()