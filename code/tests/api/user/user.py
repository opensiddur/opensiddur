''' 
  Unit testing and documentation for the /code/api/user API

  Copyright 2011 Efraim Feinstein
  Open Siddur Project
  Licensed under the GNU Lesser General Public License, version 3 or later
  
'''
import unittest 
import lxml.etree as etree

import apidb

#### LOGIN ####

class Test_Login(apidb.BaseAPITestWithSession, apidb.DefaultUser):
  """ All login attempts that use text/plain content type use this API call: """
  def login(self):
    (self.code, self.reason, self.data) = self.database.put('/code/api/user/login/' + self.user, self.password, contentType='text/plain')

class Test_Login_With_XML_Content_Type(apidb.BaseAPITestWithSession, apidb.DefaultUser):
  """ All login attempts that use application/xml content type use this API call: """
  def login(self):
    (self.code, self.reason, self.data) = self.database.put('/code/api/user/login/' + self.user, 
        '<password>' + self.password + '</password>', 
        contentType='application/xml')


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

  def test_Session_cookie_is_set(self):
    self.login()
    # A cookie named JSESSIONID should be set
    # in order to find out, we check for it in the apidb object's cookie jar
    self.assertTrue('JSESSIONID' in [cookie.name for cookie in self.database.cookieJar])

class Test_Login_Of_Existing_User_With_Wrong_Password(Test_Login, unittest.TestCase):
  password = 'wrongpassword'

  def test_Returns_HTTP_status_400(self):
    self.login()
    self.assertResponse(self.code, 400, self.reason, self.data)

class Test_Login_Of_Nonexisting_User(Test_Login, unittest.TestCase):
  user = 'doesnotexist'
  password = 'doesnotexist'

  def test_Returns_HTTP_status_400(self):
    self.login()
    self.assertResponse(self.code, 400, self.reason, self.data)

class Test_Login_Of_Existing_User_Using_XML_Content_Type(
  Test_Login_Of_Existing_User, Test_Login_With_XML_Content_Type, unittest.TestCase):
  # this performs the same tests as Test_Login_Of_Existing_User, but transmits the
  # password in an XML container
  pass

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
