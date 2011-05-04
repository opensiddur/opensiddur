''' Test cases for the document-uri trigger.

  Copyright 2010 Efraim Feinstein
  Open Siddur Project
  Licensed under the GNU Lesser General Public License, version 3 or later
  $Id: test_document_uri_trigger.py 775 2011-05-01 06:46:55Z efraim.feinstein $
'''
import unittest
import existdb
import StringIO
import existdb
import lxml.etree
import time

def toTree(data):
  return lxml.etree.parse(StringIO.StringIO(data))

class BaseTests(object):
  """ Base of all tests, but not in itself a unit test class.
  Maintains the database connection object.
  The setUp() function gets self.documentPath into an etree, self.docTree.  Previous setup for 
  self.documentPath is expected to be performed by superclasses.
  """
  server = 'localhost'
  port = 8080
  collectionName = '/db/group/testuser/'
  documentName = 'test.xml'
  restPrefix = ''   # set this to /exist/rest if using a standard eXist configuration
  documentPath = collectionName + documentName
  testUser = 'testuser'
  testPassword = 'testuser'
  httpDebugLevel = 0
  database = existdb.Existdb(server, port, restPrefix, user=testUser, password=testPassword, debuglevel=httpDebugLevel)
  XML = 'http://www.w3.org/XML/1998/namespace'
  JX = 'http://jewishliturgy.org/ns/jlp-processor'
  
  def setUp(self):
    # the particular test must perform the remainder of the setup (uploading the document)!
    (response, reason, data) = self.database.get(self.documentPath)
    self.assertStatus(response, 200, data)
    self.docTree = toTree(data).getroot()
  
  def tearDown(self):
    self.database.delete(self.documentPath)

  def assertStatus(self, actualStatus, expectedStatus, responseString = '', activity = 'Set up'):
    if (len(responseString) > 0):
      reasonString = 'Reason: %s' % responseString
    else: 
      reasonString = ''
    assert expectedStatus == actualStatus, '%s returning HTTP %d for %s.  This is bad. %s' % (activity, actualStatus, self.documentPath, reasonString) 

class BaseTestTEIDocument(BaseTests):
  ''' base class for TEI document tests '''
  xmlDocument = '''
  <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en">
    <tei:teiHeader/>
    <tei:text/>
  </tei:TEI>
  '''

  def testPresenceOfDocumentUriAttribute(self):
    docUriAttributeName = '{%s}document-uri' % (self.JX)
    self.assertTrue(docUriAttributeName in self.docTree.attrib, 'jx:document-uri is not present in the root.  Attributes are: %s' % (str(self.docTree.attrib)))
  
  def testPresenceOfXMLBaseAttribute(self):
    baseAttributeName = '{%s}base' % (self.XML)
    self.assertTrue(baseAttributeName in self.docTree.attrib, 'xml:base is not present in the root.  Attributes are: %s' % (str(self.docTree.attrib)))

  def testValueOfDocumentUriAttribute(self):
    docUriAttributeName = '{%s}document-uri' % (self.JX)
    #print 'attributes: ' + str(self.docTree.attrib)
    self.assertTrue (docUriAttributeName in self.docTree.attrib, 'jx:document-uri not present')
    content = self.docTree.attrib[docUriAttributeName]
    self.assertTrue(content == self.documentPath, 'jx:document-uri has the wrong value: %s != %s' % (content, self.documentPath))

  def testValueOfXmlBaseAttribute(self):
    baseAttributeName = '{%s}base' % (self.XML)
    self.assertTrue (baseAttributeName in self.docTree.attrib, 'xml:base not present')
    content = self.docTree.attrib[baseAttributeName]
    self.assertTrue(content == self.documentPath, 'xml:base has the wrong value: %s != %s' % (content, self.documentPath))

  def testOtherRootAttributeIsPresent(self):
    attributeName = '{%s}lang' % self.XML
    self.assertTrue(attributeName in self.docTree.attrib, 'xml:lang is not present in the root')

  def testChildElementsArePresent(self):
    self.assertTrue(len(self.docTree) == 2, 'document does not have 2 child elements')
 

class TestTEIDocumentFromPut(BaseTestTEIDocument, unittest.TestCase):
  def setUp(self):
    (status, reason, data) = self.database.put(self.documentPath, self.xmlDocument)
    self.assertStatus(status, 201, data)
    super(TestTEIDocumentFromPut, self).setUp()

class TestTEIDocumentWithXMLBasePresent(TestTEIDocumentFromPut):
  xmlDocument = '''
  <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xml:lang="en" xml:base="http://example.com/example">
    <tei:teiHeader/>
    <tei:text/>
  </tei:TEI>
  '''

class TestTEIDocumentFromXQuery(BaseTestTEIDocument, unittest.TestCase):
  def setUp(self):
    (status, reason, data) = self.database.postQuery('xquery version "1.0";' + 
      'xmldb:store("' + self.collectionName + '", "' + self.documentName + '", ' + self.xmlDocument + ')' )
    self.assertStatus(status, 200, data)
    super(TestTEIDocumentFromXQuery, self).setUp()

class TestTEIDocumentFromXQueryUpdateOfChildElement(TestTEIDocumentFromPut, unittest.TestCase):
  def setUp(self):
    super(TestTEIDocumentFromXQueryUpdateOfChildElement,self).setUp()
    (status, reason, data) = self.database.postQuery('xquery version "1.0";\n' +
      'declare namespace tei="http://www.tei-c.org/ns/1.0";\n' +
      'let $TEI := doc("' +self.documentPath +'")/tei:TEI/tei:text\n' + 
      'return update insert <tei:body/> into $TEI\n')
    self.assertStatus(status, 200, data)
    BaseTests.setUp(self) 

  def testInsertOccurred(self):
    self.assertTrue(self.docTree.find('.//{http://www.tei-c.org/ns/1.0}body') is not None, 'Inserted element cannot be found. This test is invalid.')

class BaseTestTEIDocumentFromSecondCollection(BaseTestTEIDocument):
  """ Test a TEI document copied from one location to another.
  Generates and cleans up a second collection as a subcollection of the usual test location,
  performs an operation (collectionQueryOperation) on the resource within that collection.
  The new location is the same as the other tests.
  """
  originalDocumentName = BaseTestTEIDocument.documentName
  originalCollection = 'test2'
  originalCollectionPath = BaseTestTEIDocument.collectionName + originalCollection + '/'
  
  def collectionQueryOperation(self):
    """ return the query string that this class should do """
    pass

  def setUp(self):
    (status, reason, data) = self.database.createCollection(self.originalCollection, self.collectionName)
    self.assertStatus(status, 200, data)
    (status, reason, data) = self.database.put(self.originalCollectionPath + self.originalDocumentName, self.xmlDocument)
    self.assertStatus(status, 201, data)
    (status, reason, data) = self.database.postQuery(self.collectionQueryOperation())
    self.assertStatus(status, 200, data)
    super(BaseTestTEIDocument, self).setUp()

  def tearDown(self):
    super(BaseTestTEIDocument, self).tearDown()
    (status, reason, data) = self.database.removeCollection(self.originalCollectionPath)
    self.assertStatus(status, 200, data, 'Tear down')

class TestTEIDocumentFromCopy(BaseTestTEIDocumentFromSecondCollection, unittest.TestCase):
  def collectionQueryOperation(self):
    return  ('xquery version "1.0";\n'+
      'xmldb:copy("'+ self.originalCollectionPath +'", "'+ self.collectionName +'", "'+ self.documentName +'")')

class TestTEIDocumentFromMove(BaseTestTEIDocumentFromSecondCollection, unittest.TestCase):
  def collectionQueryOperation(self):
    return ('xquery version "1.0";\n'+
      'xmldb:move("'+ self.originalCollectionPath +'", "'+ self.collectionName +'", "'+ self.documentName +'")')

class TestTEIDocumentFromRename(BaseTestTEIDocument, unittest.TestCase):
  originalDocumentName = 'test2.xml'

  def setUp(self):
    (status, reason, data) = self.database.put(self.collectionName + self.originalDocumentName, self.xmlDocument)
    self.assertStatus(status, 201, data)
    (status, reason, data) = self.database.postQuery('xquery version "1.0";\n' + 
      'xmldb:rename("'+ self.collectionName +'", "'+ self.originalDocumentName +'", "'+ self.documentName +'")')
    self.assertStatus(status, 200, data)
    super(BaseTestTEIDocument, self).setUp()


class BaseTestNonTEIDocument(BaseTests):
  xmlDocument = '''
  <jx:test xmlns:jx="http://jewishliturgy.org/ns/jlp-processor">
    <jx:child1/>
    <jx:child2/>
  </jx:test>
  '''
  
  def testNoDocumentUri(self):
    docUriAttributeName = '{%s}document-uri' % (self.JX)
    self.assertFalse(docUriAttributeName in self.docTree.attrib, 'root has jx:document-uri when it should not')

  def testChildElementsPresent(self):
    self.assertTrue(len(self.docTree) == 2, 'document does not have 2 child elements')
  
class TestNonTEIDocumentFromPut(BaseTestNonTEIDocument, unittest.TestCase):
  def setUp(self):
    (status, reason, data) = self.database.put(self.documentPath, self.xmlDocument)
    self.assertStatus(status, 201, data)
    super(TestNonTEIDocumentFromPut, self).setUp()

class TestNonTEIDocumentFromXQuery(BaseTestNonTEIDocument, unittest.TestCase):
  def setUp(self):
    (status, reason, data) = self.database.postQuery('xquery version "1.0";' + 
      'xmldb:store("' + self.collectionName + '", "' + self.documentName + '", ' + self.xmlDocument + ')' )
    self.assertStatus(status, 200, data)
    super(TestNonTEIDocumentFromXQuery, self).setUp()


if __name__ == '__main__':
  unittest.main()
