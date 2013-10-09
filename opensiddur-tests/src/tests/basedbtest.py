#!/usr/bin/env python
# 
# Object-derived base class for tests, which includes a database object and common functions
# 
# Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
# Open Siddur Project
# Licensed under the GNU Lesser General Public License version 3 or later
#
# $Id: basedbtest.py 687 2011-01-23 23:36:48Z efraim.feinstein $
import StringIO 
import lxml.etree

import existdb

class BaseDBTest(object):
  """ This class serves as a base class for all kinds of database-requiring tests
  and provides them with a database object with overridable, but sane, default values and
  some miscellaneous common, reused functions
  """
  server = 'localhost'
  port = 8080
  user = 'testuser'
  password = 'testuser'
  restPrefix = ''
  debugLevel = 0
  useHTTPBasic = True
  
  database = existdb.Existdb(server, port, restPrefix, user, password, debugLevel, useHTTPBasic)

  NS_TEI = 'http://www.tei-c.org/ns/1.0'
  NS_EXIST = 'http://exist.sourceforge.net/NS/exist'
  NS_XML = 'http://www.w3.org/XML/1998/namespace'
  NS_J = 'http://jewishliturgy.org/ns/jlptei/1.0'
  NS_JX = 'http://jewishliturgy.org/ns/jlp-processor'

  def assertStatus(self, actualStatus, expectedStatus, responseString = '', activity = 'Set up', documentPath = ''):
    """ assert that a returned status is the same as an expected status.  If it isn't display a configurable error and fail.
    This function is intended to be used in setUp() and tearDown() to cause a testing error, as opposed to a test failure.
    expectedStatus may include a list of possible statuses.
    """
    if (len(responseString) > 0):
      reasonString = 'Reason: %s' % responseString
    else: 
      reasonString = ''

    if documentPath:
      documentPath = 'for ' + documentPath

    assert actualStatus in (expectedStatus,), '%s returning HTTP %d%s.  This is bad. %s' % (activity, actualStatus, documentPath, reasonString) 

  @classmethod
  def toTree(cls, data):
    """ Return an lxml.etree, given some data """
    return lxml.etree.parse(StringIO.StringIO(data))

  def addDocumentUriToTree(self, tree, documentPath):
    """ add the @jx:document-uri/@xml:base to a tree. documentPath is relative to / (do include /db).
    Return the modified tree. """
    root = tree.getroot()
    root.set('{%s}document-uri' % (self.NS_JX), 'http://%s:%s%s' % (self.server, self.port, documentPath) )
    root.set('{%s}base' % (self.NS_XML), 'http://%s:%s%s' % (self.server, self.port, documentPath) )
    return tree
  
  def removeDocumentUriAndXmlBaseFromTreeRoot(self, tree):
    """ Remove the @jx:document-uri/@xml:base from the tree root. Return the modified tree. """
    root = tree.getroot()
    try:
      del root.attrib['{%s}document-uri' % (self.NS_JX)]
    except KeyError:
      pass
    try:
      del root.attrib['{%s}base' % (self.NS_XML)]
    except KeyError:
      pass
    return tree

  @classmethod
  def elementsEqual(cls, e1, e2, stripped = True):
    """ determine if e1 and e2 (ElementTree elements) are equal in value (including subelements) """
    children1 = e1.getchildren()
    children2 = e2.getchildren()

    if stripped:
      text1 = None
      text2 = None
      tail1 = None
      tail2 = None
      if e1.text:
        text1 = e1.text.strip()
      if e2.text:
        text2 = e2.text.strip()
      if e1.tail:
        tail1 = e1.tail.strip()
      if e2.tail:
        tail2 = e2.tail.strip()
    else:
      text1 = e1.text
      text2 = e2.text
      tail1 = e1.tail
      tail2 = e2.tail  

    result = (
      e1.tag == e2.tag and
      len(children1) == len(children2) and
      text1 == text2 and 
      e1.attrib == e2.attrib and 
      tail1 == tail2 and
      all([cls.elementsEqual(children1[n], children2[n]) for n in xrange(len(children1))])
      )
    #if not result:
    #  print "elementEquals FAILS AT: ", lxml.etree.toString(e1)
    return result

  @classmethod
  def treesEqual(cls, tree1, tree2, stripped = True):
    """ compare trees for equality. Return True or False """
    return cls.elementsEqual(tree1.getroot(), tree2.getroot(), stripped)

  def assertResponse(self, status, expectedStatus, reason, data, message = ''):
    """ Assert a given network response for inside tests """
    self.assertTrue(status == expectedStatus, '%s Reason = %s data = %s' % (message, reason, data))
