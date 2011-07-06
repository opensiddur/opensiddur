''' 
  Library for testing API functions

  Copyright 2011 Efraim Feinstein
  Open Siddur Project
  Licensed under the GNU Lesser General Public License, version 3 or later
  
'''
import StringIO
import lxml.etree as etree
import unittest
import getopt
import sys

import existdb

# store the admin password for when run as a test suite
adminPassword = None 

class ApiDB(existdb.Existdb):
  ''' abstraction of the database for API testing '''
  def __init__(self, **kwargs):
    ''' initialize: be sure to set either forceHTTPBasic or useSession '''
    existdb.Existdb.__init__(self ,**kwargs)

  def __addMethod(self, location, method):
    if '?' in location:
      divider = '&'
    else:
      divider = '?'
    return location + divider + '_method=' + method

  def put(self, location, document, contentType='text/xml'):
    return existdb.Existdb.post(self, self.__addMethod(location, 'PUT'), document, contentType)

  def delete(self, location):
    return existdb.Existdb.post(self, self.__addMethod(location, 'DELETE'),'')

class BaseAPITest(object):
  ''' All API tests derive from here. based on BaseDBTest, which is being deprecated '''
  NS_HTML = 'http://www.w3.org/1999/xhtml'
  NS_TEI = 'http://www.tei-c.org/ns/1.0'
  NS_EXIST = 'http://exist.sourceforge.net/NS/exist'
  NS_XML = 'http://www.w3.org/XML/1998/namespace'
  NS_J = 'http://jewishliturgy.org/ns/jlptei/1.0'
  NS_JX = 'http://jewishliturgy.org/ns/jlp-processor'

  # default prefixes
  prefixes = {'tei':NS_TEI, 'exist':NS_EXIST, 'j':NS_J, 'jx':NS_JX, 'html':NS_HTML}

  def setUp(self, **kwargs):
    ''' set up. keyword args are passed on to ApiDB '''
    settings = {
      'server':'localhost',
      'port':8080,
      'user':'',
      'password':'',
      'restPrefix':'',
      'debuglevel':0,
      'useHTTPBasic':False,
      'forceHTTPBasic':False,
      'useSession':False}

    for k, v in settings.iteritems():
      kwargs.setdefault(k, v)
  
    self.database = ApiDB(**kwargs)


  def assertStatusError(self, actualStatus, expectedStatus, responseString = '', activity = 'Set up', documentPath = ''):
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
  def qname(cls, ns, local):
    ''' make a qualified name out of a local name and namespace '''
    return '{%s}%s' % (ns, local)

  @classmethod
  def toTree(cls, data):
    """ Return an etree, given some data """
    return etree.parse(StringIO.StringIO(data))

  def addDocumentUriToTree(self, tree, documentPath):
    """ add the @jx:document-uri/@xml:base to a tree. documentPath is relative to / (do include /db).
    Return the modified tree. """
    root = tree.getroot()
    root.set('{%s}document-uri' % (self.NS_JX), documentPath )
    root.set('{%s}base' % (self.NS_XML), documentPath) 
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

class DefaultUser:
  user = 'testuser'
  password = 'testuser'

class BaseAPITestWithHTTPBasic(BaseAPITest):
  def setUp(self, user=DefaultUser.user, password=DefaultUser.password, **kwargs):
    kwargs.setdefault('user', user)
    kwargs.setdefault('password', password)
    kwargs.setdefault('useSession', True)
    kwargs['forceHTTPBasic'] = True
    super(BaseAPITestWithHTTPBasic, self).setUp(**kwargs)

class BaseAPITestWithSession(BaseAPITest):
  def setUp(self, **kwargs):
    super(BaseAPITestWithSession, self).setUp(useSession=True, **kwargs)

def usage():
  print "Unit testing framework. %s [-p admin-password] [-v]" % sys.argv[0]

def testMain():
  global adminPassword

  try:
    opts, args = getopt.getopt(sys.argv[1:], "hp:v", ["help", "password=","verbose"])
  except getopt.GetoptError, err:
    # print help information and exit:
    print str(err) # will print something like "option -a not recognized"
    usage()
    sys.exit(2)
  
  for o, a in opts:
    if o in ("-h", "--help"):
      usage()
      sys.exit()
    elif o in ("-p", "--password"):
      adminPassword = a
    elif o in ("-v", "--verbose"):
      pass
    else:
      usage()
      sys.exit()        
  if adminPassword is None:
    adminPassword = raw_input('Enter the database admin password (for user tests): ')
 
  unittest.main()

