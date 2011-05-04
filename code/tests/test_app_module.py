#!/usr/bin/env python
# 
# Test functionality of app XQuery module 
# 
# Copyright 2010 Efraim Feinstein <efraim.feinstein@gmail.com>
# Open Siddur Project
# Licensed under the GNU Lesser General Public License version 3 or later
#
# $Id: test_app_module.py 687 2011-01-23 23:36:48Z efraim.feinstein $
import sys
import unittest
import lxml.etree

import existdb
import basedbtest

class Test_Private_Get_Auth_String_When_Authenticated(basedbtest.BaseDBTest, unittest.TestCase):
  def setUp(self):
    (status, reason, self.returnData) = self.database.postQuery("""
    import module namespace app="http://jewishliturgy.org/modules/app" at "xmldb:exist:///db/code/modules/app.xqm";
    let $ret := app:_get_auth_string()
    return
      <root>
        <user>{$ret[1]}</user>
        <pass>{$ret[2]}</pass>
      </root>
    """)
    self.assertStatus(status, 200, self.returnData)
    tree = self.toTree(self.returnData)
    self.userReturn = str(tree.getroot()[0][0].text)
    self.passwordReturn = str(tree.getroot()[0][1].text)

  def test_Returns_Authenticated_User_Name(self):
    self.assertTrue(self.userReturn == self.user, 'Authentication did not work.  Username returned ' + self.userReturn)
  
  def test_Returns_Authenticated_Password(self):
    self.assertTrue(self.passwordReturn == self.password, 'Authentication did not work.  Password returned ' + self.passwordReturn)

class Test_Auth_User_When_Authenticated(basedbtest.BaseDBTest, unittest.TestCase):
  def setUp(self):
    (status, reason, self.returnData) = self.database.postQuery("""
    import module namespace app="http://jewishliturgy.org/modules/app" at "xmldb:exist:///db/code/modules/app.xqm";
    app:auth-user()
    """)
    self.assertStatus(status, 200, self.returnData)
    self.returnString = self.toTree(self.returnData).getroot()[0].text

  def test_Returns_Authenticated_User_Name(self):
    self.assertTrue(self.returnString == self.user, 'Authentication did not work.  It returned ' + self.returnString)

if __name__ == '__main__':
  unittest.main()
