#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Unit tests for the jupdate module
# Copyright 2009 Efraim Feinstein
# Licensed under the GNU Lesser General Public License, version 3 or later
# $Id: test_jupdate.py 411 2010-01-03 06:58:09Z efraim.feinstein $
import StringIO
import time

import unittest
import existdb
import lxml.etree


# namespaces:
TEI = 'http://www.tei-c.org/ns/1.0'
J = 'http://jewishliturgy.org/ns/jlptei/1.0'
EXIST = 'http://exist.sourceforge.net/NS/exist'
namespaces = {'tei':TEI,
    'exist':EXIST,
    'j':J}

# database instance
database=existdb.Existdb()

def toTree(data):
    return lxml.etree.parse(StringIO.StringIO(data))

class TestUpdate(unittest.TestCase):
    def setUp(self):
        self.documentLocation = '/db/tests/contributors.xml'
        testDocument = file('contributors.xml', 'r')
        (status, reason, data) = database.put(
            self.documentLocation, testDocument.read())
        testDocument.close()
        assert status==201, self.serverErrorMsg(
            'cannot load test document to database', status, reason, data)
    
    def testInsert(self):
        ''' Insertion of an item '''
        insertQuery = 'test_jupdate_insert.xql'
        (status, reason, data) = database.postQueryFile(insertQuery)
        self.assertEqual(status, 200, data)
        xmlData = toTree(data)
        
        self.assert_(xmlData.xpath(
            'not(exception)', namespaces=namespaces
            ))
            
        (status2, reason2, data2) = database.get(self.documentLocation)
        self.assertEqual(status2, 200, data)
        xmlData2 = toTree(data2)
        self.assert_(xmlData2.xpath(
            '/tei:TEI/tei:text/tei:body/tei:div/tei:list/tei:item[@xml:id="test.steven.case"]',
            namespaces=namespaces
        ))
    
    def testReplace(self):
        ''' Replacing an item '''
        replacementQuery = 'test_jupdate_replace.xql'
        (status, reason, data) = database.postQueryFile(replacementQuery, 
            postLocation=self.documentLocation)
        self.assertEqual(status, 200)
        xmlResponse = toTree(data)
        self.assert_(xmlResponse.xpath(
            'not(exception)', namespaces=namespaces
            ))
        
        (status, reason, data) = database.get(self.documentLocation)
        self.assertEqual(status, 200, data)
        
        xmlData = toTree(data)
        # test that the original item is gone:
        self.assert_(len(xmlData.xpath(
            '//*[@xml:id="toby.replaced"]', 
            namespaces=namespaces))==0)
        # test that the new item is present
        self.assert_(xmlData.xpath(
            '/tei:TEI/tei:text/tei:body/tei:div/tei:list/tei:item[@xml:id="ian.replaced"]/tei:forename', 
            namespaces=namespaces))
    
    def testValueReplace(self):
        ''' Setting the value of an item '''
        valueQuery = 'test_jupdate_value.xql'
        (status, reason, data) = database.postQueryFile(valueQuery, 
            postLocation=self.documentLocation)
        self.assertEqual(status, 200)
        xmlResponse = toTree(data)
        self.assert_(xmlResponse.xpath(
            'not(exception)', namespaces=namespaces
            ))
        
        (status, reason, data) = database.get(self.documentLocation)
        self.assertEqual(status, 200, data)
        
        xmlData = toTree(data)
        # test that the original item is gone:
        self.assert_(len(xmlData.xpath(
            '//*[@xml:id="toby.replaced"]/tei:email[.="toby@replac.edu"]', 
            namespaces=namespaces))==0)
        # test that the new item is present
        self.assert_(len(xmlData.xpath(
            '//*[@xml:id="toby.replaced"]/tei:email[.="ianalso@replac.edu"]', 
            namespaces=namespaces))==1)
    
    def testDelete(self):
        """ Deleting an item from the database """
        deleteQuery = 'test_jupdate_delete.xql'
        (status, reason, data) = database.postQueryFile(deleteQuery, 
            postLocation=self.documentLocation)
        self.assertEqual(status, 200, data)
        xmlResponse = toTree(data)
        self.assert_(xmlResponse.xpath(
            'not(exception)', namespaces=namespaces
            ))
        
        (status, reason, data) = database.get(self.documentLocation)
        self.assertEqual(status, 200, data)
        
        xmlData = toTree(data)
        # test that the item is gone:
        self.assert_(len(xmlData.xpath(
            '//*[@xml:id="toby.deleted"]', 
            namespaces=namespaces))==0)
    
    def testNumericalPath(self):
        """ Numerical path solver. All paths should return true. """
        npQuery = 'test_jupdate_numerical-path.xql'
        (status, reason, data) = database.postQueryFile(npQuery, 
            postLocation=self.documentLocation)
        
        self.assertEqual(status, 200, data)
        xmlResponse = toTree(data)
        self.assert_(xmlResponse.xpath(
            'not(exception)', namespaces=namespaces
            ))
        
        self.assert_(xmlResponse.xpath('not(//*[.="false"])'), data)
    
    def keywordQuery(self, queryFile, keywords):
        """ replace the keywords (%keyword%) in queryFile with the keywords'
        values.  Return the query as a string """
        f = file(queryFile, 'r')
        query = f.read()
        for (keyword, value) in keywords.items():
            query = query.replace('%'+keyword+'%', value)
        f.close()
        return query
    
    def prepareUpdate(self):
        """ Prepare an update for other tests.
        Return the xmlResponse, the collection and document names, 
        and the path of the update item
        """
        prepareQuery = 'test_jupdate_prepare.xql'
        (status, reason, data) = database.postQueryFile(prepareQuery, 
            postLocation=self.documentLocation)
        
        self.assertEqual(status, 200, data)
        xmlResponse = toTree(data)
        self.assert_(xmlResponse.xpath(
            'not(exception)', namespaces=namespaces
            ))
        uri = xmlResponse.xpath(    
            '/exist:result/tests/uri/text()',namespaces=namespaces)[0]
        collection = xmlResponse.xpath(    
            '/exist:result/tests/collection/text()',namespaces=namespaces)[0]
        name = xmlResponse.xpath(
            '/exist:result/tests/name/text()',namespaces=namespaces)[0]
        
        (status, reason, data)=database.get(
            '?_query=doc-available(concat(\"' + collection + 
            '/\", encode-for-uri(\"'+ name +'\")))')
        self.assertEqual(status, 200, data)
        tempDocExists = toTree(data)
        
        x = tempDocExists.xpath('/exist:result/exist:value[.="true"]',
            namespaces=namespaces)
        
        self.assert_(x)
        return (xmlResponse, collection, name, uri)
        
    def testPrepareCancel(self):
        """ A canceled update """
        (xmlResponse, collection, name, uri) = self.prepareUpdate()
        cancelQuery = self.keywordQuery('test_jupdate_cancel.xql',
            {'XPATH':uri})
        (status, reason, data) = database.postQuery(cancelQuery)
        self.assertEqual(status, 200, data)
        (status, reason, data)=database.get(
            '?_query=doc-available(concat(\"' + collection + 
            '/\", encode-for-uri(\"'+ name +'\")))')
        self.assertEqual(status, 200, data)
        tempDocExists = toTree(data)
        self.assert_(tempDocExists.xpath('/exist:result/exist:value[.="false"]',
            namespaces=namespaces), data)
        
    
    def testPrepareComplete(self):
        """ A completed update """
        (xmlResponse, collection, name, uri) = self.prepareUpdate()
        completeQuery = self.keywordQuery('test_jupdate_complete.xql',
            {'XPATH':uri})
        (status, reason, data) = database.postQuery(completeQuery)
        self.assertEqual(status, 200, data)
        
        
        
        # make sure the change was made in the original document
        (status, reason, data)=database.get(self.documentLocation)
        self.assertEqual(status, 200, data)
        documentXml = toTree(data)
        self.assert_(
            documentXml.xpath('/tei:TEI/tei:text/tei:body/tei:div/tei:list/' +
            'tei:item[@xml:id=\"toby.prepared\"]/tei:surname[.=\"Prepared\"]', 
            namespaces=namespaces), 'Document was not changed.')
        
        # make sure the temp document was removed
        (status, reason, data)=database.get(
            '?_query=doc-available(concat(\"' + collection + 
            '/\", encode-for-uri(\"'+ name +'\")))')
        self.assertEqual(status, 200, data)
        tempDocExists = toTree(data)
        self.assert_(tempDocExists.xpath('/exist:result/exist:value[.="false"]',
            namespaces=namespaces), data)
        
    def tearDown(self):
        (status, reason, data) = database.delete(self.documentLocation)
        assert status==200, self.serverErrorMsg(
            'cannot delete document from database', status, reason, data)
    
    def serverErrorMsg(self, msg, status, reason, data):
        return ('%s\n' % (msg) + 
            'status: %s %s\n' % (status, reason) +
            '%s' % (data))
            
if __name__ == "__main__":
    unittest.main()