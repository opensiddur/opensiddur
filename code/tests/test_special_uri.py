#!/usr/bin/env python
# 
# Test special URIs listed in the main controller 
# 
# Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
# Open Siddur Project
# Licensed under the GNU Lesser General Public License version 3 or later
#
# $Id: test_special_uri.py 687 2011-01-23 23:36:48Z efraim.feinstein $
import sys
import unittest
import lxml.etree
import copy

import existdb
import basedbtest


class Base_Test_Special_Uri_Via_REST(basedbtest.BaseDBTest):
  specialUri = 'YO, superclass, set me!'
  expectedResponse = 'YO, superclass, set me too!'

  def setUp(self):
    (status, reason, self.response) = self.database.get(self.specialUri)
    self.assertStatus(status, 200, self.response)
    self.responseElement = self.toTree(self.response).getroot()

  def test_Response_Is_Expected_Symbol(self):
    self.assertTrue(self.responseElement.attrib['value'] == self.expectedResponse)

class Base_Test_Special_Uri_Via_XQuery(basedbtest.BaseDBTest):
  specialUri = 'YO, superclass, set me!'
  expectedResponse = 'YO, superclass, set me too!'

  def setUp(self):
    (status, reason, self.response) = self.database.postQuery('''xquery version "1.0";
    doc("'''+self.specialUri+'''")''')
    self.assertStatus(status, 200, self.response)
    print self.response
    self.responseElement = self.toTree(self.response).getroot()[0]  # reply will be under exist:result

  def test_Response_Is_Expected_Symbol(self):
    self.assertTrue(self.responseElement.attrib['value'] == self.expectedResponse)

class Test_Special_URI_YES_Via_REST(Base_Test_Special_Uri_Via_REST, unittest.TestCase):
  specialUri = '/YES'
  expectedResponse = 'YES'
  
class Test_Special_URI_NO_Via_REST(Base_Test_Special_Uri_Via_REST, unittest.TestCase):
  specialUri = '/NO'
  expectedResponse = 'NO'

class Test_Special_URI_MAYBE_Via_REST(Base_Test_Special_Uri_Via_REST, unittest.TestCase):
  specialUri = '/MAYBE'
  expectedResponse = 'MAYBE'

class Test_Special_URI_ON_Via_REST(Base_Test_Special_Uri_Via_REST, unittest.TestCase):
  specialUri = '/ON'
  expectedResponse = 'ON'

class Test_Special_URI_OFF_Via_REST(Base_Test_Special_Uri_Via_REST, unittest.TestCase):
  specialUri = '/OFF'
  expectedResponse = 'OFF'

if __name__ == '__main__':
  unittest.main()
