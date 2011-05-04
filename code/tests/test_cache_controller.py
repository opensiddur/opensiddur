#!/usr/bin/env python
# 
# Test functionality of caching controller 
# 
# Copyright 2010-2011 Efraim Feinstein <efraim.feinstein@gmail.com>
# Open Siddur Project
# Licensed under the GNU Lesser General Public License version 3 or later
#
# $Id: test_cache_controller.py 726 2011-04-04 19:33:16Z efraim.feinstein $
import sys
import unittest
import lxml.etree
import copy

import existdb
import basedbtest


class BaseTestCache(basedbtest.BaseDBTest):
  ''' Sets up and destroys a database object and a cache to be used
  for testing '''
  userName = 'testuser'
  baseCollectionName = '/db/group/' + userName + '/'
  collectionName = 'data/'
  resourceName = 'test.xml'

  queryForClearCollection = '?clear=yes'
  queryForClearSubcollection = '?clear=all'
  queryForOriginal = '?format=original'
  queryForCached = '?format=fragmentation'

  def setUp(self):
    (status, reason, data) = self.database.createCollection(self.collectionName, self.baseCollectionName)
    self.assertStatus(status, 200, data)

  def tearDown(self):
    (status, reason, data) = self.database.removeCollection(self.baseCollectionName + self.collectionName)
    self.assertStatus(status, 200, data)

class Test_Non_Existent_Resources(BaseTestCache, unittest.TestCase):
  notCollectionName = 'datanoexist/'
  notResourceName = 'testnoexist.xml'

  def test_Returns_Error_404_Without_Format_String(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.resourceName)
    self.assertResponse(status, 404, reason, data)

  def test_Returns_Error_404_With_Original_Format_String(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.resourceName + self.queryForOriginal)
    self.assertResponse(status, 404, reason, data)
  
  def test_Returns_Error_404_With_Fragmentation_Format_String(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.resourceName + self.queryForCached)
    self.assertResponse(status, 404, reason, data)

  def test_Returns_Error_404_With_Nonexistent_Clear_Resource(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.notResourceName + self.queryForClearCollection)
    self.assertResponse(status, 404, reason, data)
  
  def test_Returns_Error_404_With_Nonexistent_Clear_Resource_All(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.notResourceName + self.queryForClearSubcollection)
    self.assertResponse(status, 404, reason, data)
    
  def test_Returns_Error_404_With_Nonexistent_Clear_Collection(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.notCollectionName + self.queryForClearCollection)
    self.assertResponse(status, 404, reason, data)

  def test_Returns_Error_404_With_Nonexistent_Clear_CollectionAll(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.notCollectionName + self.queryForClearSubcollection)
    self.assertResponse(status, 404, reason, data)

class BaseTestCacheWithUncachedResource(BaseTestCache):
  xmlDocument = '''<?xml version="1.0"?>
  <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0">
    <tei:teiHeader/>
    <tei:text>
      <tei:body>
        <j:concurrent>
          <j:selection>
            <tei:ptr xml:id="s1" target="#A"/>
            <tei:ptr xml:id="s2" target="#B"/>
          </j:selection>
          <j:view type="p">
            <tei:p xml:id="p1">
              <tei:ptr xml:id="p1s1" target="#s1"/>
              <tei:ptr xml:id="p1s2" target="#s2"/>
            </tei:p>
          </j:view>
        </j:concurrent>
        <j:repository>
          <tei:seg xml:id="A">A</tei:seg>
          <tei:seg xml:id="B">B</tei:seg>
        </j:repository>
      </tei:body>
    </tei:text>
  </tei:TEI>
  '''
  originalTree = basedbtest.BaseDBTest.toTree(xmlDocument)
 
  def setUp(self):
    super(BaseTestCacheWithUncachedResource, self).setUp()
    (status, reason, data) = self.database.put(self.baseCollectionName + self.collectionName + self.resourceName, self.xmlDocument)
    self.assertStatus(status, 201, reason)

class Test_Previously_Uncached_Resource(BaseTestCacheWithUncachedResource, unittest.TestCase):
  def getAndTestForEquality(self, getUrl):
    (status, reason, data) = self.database.get(getUrl)
    self.assertResponse(status, 200, reason, data)
    returnTree = self.toTree(data)
    getUrlWithoutQuery = getUrl.split('?')[0]
    returnTree = self.removeDocumentUriAndXmlBaseFromTreeRoot(returnTree)
    self.assertTrue(self.treesEqual(returnTree, self.originalTree))

  def test_Get_With_No_Format_String_Returns_Document(self):
    self.getAndTestForEquality(self.baseCollectionName + self.collectionName + self.resourceName)

  def test_Get_With_Original_Format_String_Returns_Document(self):
    self.getAndTestForEquality(self.baseCollectionName + self.collectionName + self.resourceName + self.queryForOriginal)

class BaseTestWithCachedResource(BaseTestCacheWithUncachedResource):
  cacheCollectionName = 'cache/'

  xmlDocumentFragmentation = '''<?xml version="1.0"?>
  <tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:j="http://jewishliturgy.org/ns/jlptei/1.0"
    xmlns:jx="http://jewishliturgy.org/ns/jlp-processor">
    <j:links>
        <tei:ptr jx:id="p1s1" target="#s1"/>
        <tei:ptr jx:id="p1s2" target="#s2"/>
    </j:links>
    <tei:teiHeader/>
    <tei:text>
      <tei:body>
        <jx:joined-concurrent>
          <tei:p jx:id="p1">
            <tei:ptr jx:id="s1" target="#A"/>
            <tei:ptr jx:id="s2" target="#B"/>
          </tei:p>
        </jx:joined-concurrent>
        <j:repository>
          <tei:seg jx:id="A">A</tei:seg>
          <tei:seg jx:id="B">B</tei:seg>
        </j:repository>
      </tei:body>
    </tei:text>
  </tei:TEI>
  '''
  xmlDocumentFragmentationTree = basedbtest.BaseDBTest.toTree(xmlDocumentFragmentation)

# common tests for resource that should have come from cache 
class CachedResourceTests(BaseTestWithCachedResource):
  returnDocumentString = ''   # these have to be filled in by superclasses!
  returnDocumentTree = ''   

  def test_Fragmentation_Document_Has_Original_Document_Uri(self):
    root = self.returnDocumentTree.getroot()
    docuri = root.attrib['{%s}document-uri' % self.NS_JX]
    expectedUri = 'http://%s:%s%s' % (self.server, self.port, self.baseCollectionName + self.collectionName + self.resourceName)
    self.assertTrue(docuri == expectedUri, 'document uri is ' + docuri + ' instead of ' + expectedUri)

  def test_Get_With_Fragmentation_Format_String_Returns_Fragmentation_Document(self):
    #print '---expected document---'
    #print lxml.etree.dump(self.xmlDocumentFragmentationTree.getroot())
    #print '---got document---'
    #print lxml.etree.dump((self.removeDocumentUriAndXmlBaseFromTreeRoot(self.returnDocumentTree).getroot()))
    self.assertTrue(self.treesEqual(self.removeDocumentUriAndXmlBaseFromTreeRoot(self.returnDocumentTree), self.xmlDocumentFragmentationTree))

  def test_Get_With_Fragmentation_Format_String_Creates_Cache_Collection(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.cacheCollectionName)
    self.assertResponse(status, 200, reason, data)
    collectionTree = self.toTree(data)
    # return value is exist:result, first child is exist:collection
    self.assertTrue(collectionTree.getroot()[0].tag == '{%s}collection' % self.NS_EXIST, 'Collection URL exists but it is not a collection')

class Test_Cached_Resource(CachedResourceTests, unittest.TestCase):
  def setUp(self):
    super(Test_Cached_Resource, self).setUp()
    (status, reason, self.returnDocumentString) = self.database.get(
      self.baseCollectionName + self.collectionName + self.resourceName + self.queryForCached)
    self.assertStatus(status, 200, reason, self.returnDocumentString)
    self.returnDocumentTree = self.toTree(self.returnDocumentString)

  def test_In_Progress_Flag_Is_Removed(self):
    inProgressName = self.resourceName.replace('.xml','.in-progress.xml')
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.cacheCollectionName + inProgressName)
    self.assertResponse(status, 404, reason, data)

  def test_Get_With_Fragmentation_Format_String_Creates_Cached_Document(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.cacheCollectionName + self.resourceName)
    self.assertResponse(status, 200, reason, data)

  def test_Cached_Resource_Has_Appropriate_Permissions(self):
    location = self.baseCollectionName + self.collectionName + self.cacheCollectionName + self.resourceName
    (status, reason, user, group, mode) = self.database.getPermissions(location)
    self.assertResponse(status, 200, reason, '')
    self.assertTrue(user == self.userName, 'cached user name is ' + user + ' instead of ' + self.userName)
    self.assertTrue(group == 'everyone', 'cached group name is ' + group + ' instead of everyone')
    self.assertTrue(mode == '774', 'cached mode is ' + mode + ' instead of 774')
  

class BaseTestClearCache(BaseTestCache):
  # these are placeholders for original and cached documents
  originalDocument = '''<?xml version="1.0"?><original/>'''
  originalDocumentName = 'test.xml'
  cachedDocument = '''<?xml version="1.0"?><cached/>'''
  cacheCollectionName = 'cache/'
  subCollectionName = 'data2/'
  cacheSubCollectionName = 'cache/'

  def setUp(self):
    super(BaseTestClearCache, self).setUp()
    # create data/cache, data/data2 and data/data2/cache
    (status, reason, data) = self.database.createCollection(self.cacheCollectionName, self.baseCollectionName + self.collectionName)
    self.assertStatus(status, 200, data)
    (status, reason, data) = self.database.createCollection(self.subCollectionName, self.baseCollectionName + self.collectionName)
    self.assertStatus(status, 200, data)
    (status, reason, data) = self.database.createCollection(self.cacheSubCollectionName, self.baseCollectionName + self.collectionName + self.subCollectionName)
    self.assertStatus(status, 200, data)
    # place files in the directories
    (status, reason, data) = self.database.put(self.baseCollectionName + self.collectionName + self.originalDocumentName, self.originalDocument)
    self.assertStatus(status, 201, data)
    (status, reason, data) = self.database.put(self.baseCollectionName + self.collectionName + self.subCollectionName + self.originalDocumentName, self.originalDocument)
    self.assertStatus(status, 201, data)
    (status, reason, data) = self.database.put(self.baseCollectionName + self.collectionName + self.cacheCollectionName + self.originalDocumentName, self.cachedDocument)
    self.assertStatus(status, 201, data)
    (status, reason, data) = self.database.put(self.baseCollectionName + self.collectionName + self.subCollectionName + self.cacheSubCollectionName + self.originalDocumentName, self.cachedDocument)
    self.assertStatus(status, 201, data)

class Test_Clear_Cache_Yes_On_Resource(BaseTestClearCache, unittest.TestCase):
  def setUp(self):
    super(Test_Clear_Cache_Yes_On_Resource, self).setUp()
    docpath = self.baseCollectionName + self.collectionName + self.originalDocumentName + self.queryForClearCollection
    (status, reason, data) = self.database.get(docpath)
    self.assertStatus(status, 200, data, documentPath = docpath)

  def test_Clear_Cache_Yes_Removes_Cached_File_From_Collection(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.cacheCollectionName + self.originalDocumentName)
    self.assertResponse(status, 404, reason, data)
  
  def test_Clear_Cache_Yes_Saves_Cached_File_In_Subcollection(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.subCollectionName + self.cacheSubCollectionName + self.originalDocumentName)
    self.assertResponse(status, 200, reason, data)

class Test_Clear_Cache_Yes_On_Collection(BaseTestClearCache, unittest.TestCase):
  def setUp(self):
    super(Test_Clear_Cache_Yes_On_Collection, self).setUp()
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.queryForClearCollection)
    self.assertStatus(status, 200, data)

  def test_Clear_Cache_Yes_On_Collection_Removes_Cached_File_From_Collection(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.cacheCollectionName + self.originalDocumentName)
    self.assertResponse(status, 404, reason, data)
  
  def test_Clear_Cache_Yes_On_Collection_Saves_Cached_File_In_Subcollection(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.subCollectionName + self.cacheSubCollectionName + self.originalDocumentName)
    self.assertResponse(status, 200, reason, data)

class Test_Clear_Cache_All_On_Resource(BaseTestClearCache, unittest.TestCase):
  def setUp(self):
    super(Test_Clear_Cache_All_On_Resource, self).setUp()
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.originalDocumentName + self.queryForClearSubcollection)
    self.assertStatus(status, 200, data)

  def test_Clear_Cache_All_On_Resource_Removes_Cached_File_From_Collection(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.cacheCollectionName + self.originalDocumentName)
    self.assertResponse(status, 404, reason, data)
  
  def test_Clear_Cache_All_On_Resource_Saves_Cached_File_In_Subcollection(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.subCollectionName + self.cacheSubCollectionName + self.originalDocumentName)
    self.assertResponse(status, 200, reason, data)
  
class Test_Clear_Cache_All_On_Collection(BaseTestClearCache, unittest.TestCase):
  def setUp(self):
    super(Test_Clear_Cache_All_On_Collection, self).setUp()
    cpath = self.baseCollectionName + self.collectionName + self.queryForClearSubcollection
    (status, reason, data) = self.database.get(cpath)
    self.assertStatus(status, 200, data, documentPath = cpath)

  def test_Clear_Cache_All_On_Collection_Removes_Cached_File_From_Collection(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.cacheCollectionName + self.originalDocumentName)
    self.assertResponse(status, 404, reason, data)
  
  def test_Clear_Cache_All_On_Collection_Removes_Cached_File_In_Subcollection(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.subCollectionName + self.cacheSubCollectionName + self.originalDocumentName)
    self.assertResponse(status, 404, reason, data)

class Base_Test_Cache_With_Dependencies(BaseTestCache):
  # the order of these operations will differ in all these tests
  # file under test
  cacheCollectionName = 'cache/'
  
  def queryForUpToDate(self, resourceName):
    ''' check if a cached document is up to date, result is in queryResult '''
    (status, reason, data) = self.database.postQuery('''xquery version "1.0";
      import module namespace jcache="http://jewishliturgy.org/modules/cache" 
        at "xmldb:exist:///db/code/modules/cache-controller.xqm";
      jcache:_is-up-to-date("%s", "%s")
      ''' % (self.baseCollectionName + self.collectionName + resourceName, self.cacheCollectionName)
      )
    self.assertStatus(status, 200, data)
    dataTree = self.toTree(data)
    return dataTree.getroot()[0].text.lower() == 'true'
  
  def makeDependencies(self, dependencyList = []):
    dependencyString = ''
    for dependency in dependencyList:
      dependencyString = (dependencyString + 
        '<jx:cache-depend path="%s"/>' % (self.baseCollectionName + self.collectionName + dependency))
    return dependencyString
  
  def makeXMLDocument(self, type='Uncached', identifier='test.xml', dependencyList = ()):
    return '''<?xml version="1.0"?>
      <root
      xmlns:jx="http://jewishliturgy.org/ns/jlp-processor">
        %s
        <type>%s</type>
        <identifier>%s</identifier>
      </root>''' % (self.makeDependencies(dependencyList), type, identifier)
  
  def setUpUncachedResource(self, resourceName):
    '''set up the uncached resource and return a lxml.etree representation '''
    document = self.makeXMLDocument('Uncached', resourceName)
    (status, data, reason) = self.database.put(
      self.baseCollectionName + self.collectionName + resourceName, 
      document)
    self.assertStatus(status, 201, data)
    return self.toTree(document)
  
  def setUpCachedResource(self, resourceName, dependencies = []):
    '''set up the cached resource and return a lxml.etree representation '''
    document = self.makeXMLDocument('Cached', resourceName, dependencies)
    (status, data, reason) = self.database.put(
      self.baseCollectionName + self.collectionName + self.cacheCollectionName + resourceName, 
      document)
    self.assertStatus(status, 201, data)
    return self.toTree(document)
  
  def setUp(self):
    ''' set up cache collection ''' 
    super(BaseTestCache, self).setUp()
    (status, reason, data) = self.database.createCollection(self.cacheCollectionName, self.baseCollectionName + self.collectionName)
    self.assertStatus(status, 200, data)

class Test_All_Up_To_Date_Dependencies(Base_Test_Cache_With_Dependencies, unittest.TestCase):
  
  def setUp(self):
    super(Base_Test_Cache_With_Dependencies, self).setUp()
    self.setUpUncachedResource('test.xml')
    self.setUpUncachedResource('depend1.xml')
    self.setUpUncachedResource('depend2.xml')
    self.setUpCachedResource('test.xml', ['depend1.xml', 'depend2.xml'])
    self.setUpCachedResource('depend1.xml')
    self.setUpCachedResource('depend2.xml')
    
  def test_Cache_Is_Up_To_Date(self):
    self.assertTrue(self.queryForUpToDate('test.xml'))
    
class Test_Dependency_When_Original_Is_Out_of_Date(Base_Test_Cache_With_Dependencies, unittest.TestCase):
  
  def setUp(self):
    super(Base_Test_Cache_With_Dependencies, self).setUp()
    self.setUpUncachedResource('depend1.xml')
    self.setUpUncachedResource('depend2.xml')
    self.setUpCachedResource('test.xml', ['depend1.xml', 'depend2.xml'])
    self.setUpCachedResource('depend1.xml')
    self.setUpCachedResource('depend2.xml')
    self.setUpUncachedResource('test.xml')
    
  def test_Cache_Is_Up_To_Date(self):
    self.assertFalse(self.queryForUpToDate('test.xml'))

class Test_Dependency_When_One_Dependency_Is_Out_of_Date(Base_Test_Cache_With_Dependencies, unittest.TestCase):
  
  def setUp(self):
    super(Base_Test_Cache_With_Dependencies, self).setUp()
    self.setUpUncachedResource('test.xml')
    self.setUpCachedResource('depend2.xml')
    self.setUpUncachedResource('depend1.xml')
    self.setUpUncachedResource('depend2.xml')
    self.setUpCachedResource('test.xml', ['depend1.xml', 'depend2.xml'])
    self.setUpCachedResource('depend1.xml')
    
  def test_Cache_Is_Up_To_Date(self):
    self.assertFalse(self.queryForUpToDate('test.xml'))

class Test_Dependency_When_One_Dependency_Is_Not_Cached(Base_Test_Cache_With_Dependencies):
  
  def setUp(self):
    super(Base_Test_Cache_With_Dependencies, self).setUp()
    self.setUpUncachedResource('test.xml')
    self.setUpUncachedResource('depend1.xml')
    self.setUpUncachedResource('depend2.xml')
    self.setUpCachedResource('test.xml', ['depend1.xml', 'depend2.xml'])
    self.setUpCachedResource('depend1.xml')
    
  def test_Cache_Is_Up_To_Date(self):
    self.assertFalse(self.queryForUpToDate('test.xml'))

class Test_Dependency_When_Dependency_of_Dependency_Is_Up_To_Date(Base_Test_Cache_With_Dependencies, unittest.TestCase):
  
  def setUp(self):
    super(Base_Test_Cache_With_Dependencies, self).setUp()
    self.setUpUncachedResource('test.xml')
    self.setUpUncachedResource('depend1.xml')
    self.setUpUncachedResource('depend2.xml')
    self.setUpCachedResource('test.xml', ['depend1.xml'])
    self.setUpCachedResource('depend1.xml', ['depend2.xml'])
    self.setUpCachedResource('depend2.xml')
    
  def test_Cache_Is_Up_To_Date(self):
    self.assertTrue(self.queryForUpToDate('test.xml'))

class Test_Dependency_When_Dependency_of_Dependency_Is_Out_Of_Date(Base_Test_Cache_With_Dependencies, unittest.TestCase):
  
  def setUp(self):
    super(Base_Test_Cache_With_Dependencies, self).setUp()
    self.setUpCachedResource('depend2.xml')
    self.setUpUncachedResource('test.xml')
    self.setUpUncachedResource('depend1.xml')
    self.setUpUncachedResource('depend2.xml')
    self.setUpCachedResource('test.xml', ['depend1.xml'])
    self.setUpCachedResource('depend1.xml', ['depend2.xml'])
    
  def test_Cache_Is_Up_To_Date(self):
    self.assertFalse(self.queryForUpToDate('test.xml'))


class BaseTestInProgress(BaseTestWithCachedResource):
  inProgressResourceName = BaseTestCacheWithUncachedResource.resourceName.replace('.xml', '.in-progress.xml')

  def setUp(self):
    super(BaseTestInProgress, self).setUp()
    (status, reason, data) = self.database.put(self.baseCollectionName + self.collectionName + self.resourceName, self.xmlDocument)
    self.assertStatus(status, 201, data)
    (status, reason, data) = self.database.createCollection(self.cacheCollectionName, self.baseCollectionName + self.collectionName)
    self.assertStatus(status, 200, data)
    (status, reason, data) = self.database.put(self.baseCollectionName + self.collectionName + self.cacheCollectionName + self.inProgressResourceName, '<in-progress/>')
    self.assertStatus(status, 201, data)

class Test_In_Progress_With_Fragmentation_Format_String(BaseTestInProgress, CachedResourceTests, unittest.TestCase):
  def setUp(self):
    super(Test_In_Progress_With_Fragmentation_Format_String, self).setUp()
    (status, reason, self.returnDocumentString) = self.database.get(self.baseCollectionName + self.collectionName + self.resourceName + self.queryForCached)
    self.assertStatus(status, 200, self.returnDocumentString)
    self.returnDocumentTree = self.toTree(self.returnDocumentString)

  def test_In_Progress_Indicator_Not_Removed(self):
    (status, reason, data) = self.database.get(self.baseCollectionName + self.collectionName + self.cacheCollectionName + self.inProgressResourceName)
    self.assertResponse(status, 200, reason, data)

if __name__ == '__main__':
  unittest.main()
