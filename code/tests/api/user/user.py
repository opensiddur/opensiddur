''' 
  Library to run basic operations on eXist database through its REST interface

  Copyright 2011 Efraim Feinstein
  Open Siddur Project
  Licensed under the GNU Lesser General Public License, version 3 or later
  
'''
import unittest 
import lxml.etree as etree

import apidb

#### LOGIN ####

class Test_Login(apidb.BaseAPITestWithSession, apidb.DefaultUser):
  """ All login attempts use this API call: """
  def login(self):
    (self.code, self.reason, self.data) = self.database.put('/code/api/user/login/' + self.user, self.password)

class Test_Login_Of_Existing_User(Test_Login, unittest.TestCase):
  def test_Returns_HTTP_status_204(self):
    self.login()
    self.assertResponse(self.code, 204, self.reason, self.data)

  def test_User_is_logged_in(self):
    self.login()
    (status, reason, data) = self.database.get('/code/api/user')
    asString = self.toTree(data).xpath(
      "//html:ul[@class='results']/html:li/html:a/text()", namespaces=self.prefixes)[0]
    self.assertEqual(asString, self.user)

class Test_Login_Of_Existing_User_With_Wrong_Password(Test_Login, unittest.TestCase):
  password = 'wrongpassword'

  def test_Returns_HTTP_status_400(self):
    self.login()
    self.assertResponse(self.code, 400, self.reason, self.data)

class Test_Login_Of_Nonexisting_User(Test_Login, unittest.TestCase):
  user = 'doesnotexist'
  password = 'doesnotexist'

  def test_Returns_HTTP_Status_400(self):
    self.login()
    self.assertResponse(self.code, 400, self.reason, self.data)

#### LOGOUT ####

class Test_Logout_Of_Existing_User(Test_Login, unittest.TestCase):
  def setUp(self):
    # set up the database and log in
    super(Test_Logout_Of_Existing_User, self).setUp()
    self.login()
    self.assertStatusError(self.code, 204, self.reason, self.data)

  def logout(self):
    """ All logout attempts use this API call """
    (self.code, self.reason, self.data) = self.database.get('/code/api/user/logout')

  def test_Returns_HTTP_status_204(self):
    self.logout()
    self.assertResponse(self.code, 204, self.reason, self.data)

  def test_User_is_logged_out(self):
    self.logout()
    (status, reason, data) = self.database.get('/code/api/user')
    userElement = self.toTree(data).xpath(
      "//html:ul[@class='results']/html:li/html:a", namespaces=self.prefixes)
    self.assertTrue(len(userElement) == 0)

if __name__ == '__main__':
  unittest.main()
