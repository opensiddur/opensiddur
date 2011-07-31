# Basic data API tests
# 
# all data tests operate with the user "mytestuser", which is created and destroyed on demand.
# not logged in means that the user exists and is not logged in
# the user "othertestuser" is also created or destroyed and represents a user other than the one who is logged in
# the user "nonexistent" is never created at all
#
# Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
# Licensed under the GNU Lesser General Public License, version 3 or later
#
import unittest
import getopt
import sys

import apidb


# setup for all tests:
class While_Logged_In(apidb.BaseAPITestWithSession):
  user = "mytestuser"
  password = "mytestpassword"

  def setUp(self):
    """ create the user, which will log you in """
    (self.code, self.reason, self.data) = self.database.put(
      '/code/api/user/' + self.user, self.password, contentType='text/plain')
    self.assertStatusError(self.code, 201)

  def tearDown(self):
    """ destroy the user we created and delete all remnants of it """
    self.database.postQuery("""
    xquery version "1.0";
    
    let $user-name := '%s'
    let $admin-password := '%s'    
    return
      system:as-user('admin', $admin-password, (
        xmldb:remove(xmldb:get-user-home($user-name)),
        xmldb:delete-user($user-name),
        sm:delete-group($user-name)
        )
      )
    """ % (self.user, apidb.adminPassword))

class While_Not_Logged_In(While_Logged_In):
  def setUp(self):
    # create the user, then log out
    super(While_Not_Logged_In, self).setup()
    (self.code, self.reason, self.data) = self.database.get(
      '/code/api/user/' + self.user + '/logout', contentType='text/plain')
    self.assertStatusError(self.code, 204)

class While_Logged_In_As_Someone_Else(While_Logged_In):
  someoneElseUser = "othertestuser"
  def setUp(self):
    # create the original user, then log out
    super(While_Logged_In_As_Someone_Else, self).setup()
    oldUser = self.user
    self.user = self.someoneElseUser
    super(While_Logged_In_As_Someone_Else, self).setup()
    self.user = oldUser
    # the tests are done as the old user, even though we're logged in as someone else

  def tearDown(self):
    # kill both users
    super(While_Logged_In_As_Someone_Else, self).tearDown()
    self.user = self.someoneElseUser
    super(While_Logged_In_As_Someone_Else, self).tearDown()

class With_Nonexistent_User:
  user = "nonexistent"

class Method_Not_Allowed:
  """ test that the given method returns that it is not allowed """
  def test_Returns_Method_Not_Allowed(self):
    self.runAPI()
    self.assertResponse(self.code, 405, self.reason, self.data)

##### /code/api/data #####
class Main_Menu_Get(apidb.BaseAPITest, unittest.TestCase):
  def runAPI(self):
    (self.code, self.reason, self.data) = self.database.get('/code/api/data')

  def test_Returns_HTTP_Status_Code_200(self):
    self.runAPI()
    self.assertResponse(self.code, 200, self.reason, self.data)

  def test_Returns_Common_Menu(self):
    self.runAPI()
    self.assertXPath(self.data, "count(//html:ul[@class='common']) = 1")

class Main_Menu_Put(apidb.BaseAPITest, Method_Not_Allowed, unittest.TestCase):
  def runAPI(self):
    (self.code, self.reason, self.data) = self.database.put('/code/api/data', 'nothing important', contentType="text/plain")

class Main_Menu_Post(apidb.BaseAPITest, Method_Not_Allowed, unittest.TestCase):
  def runAPI(self):
    (self.code, self.reason, self.data) = self.database.post('/code/api/data', 'nothing important', contentType="text/plain")

class Main_Menu_Delete(apidb.BaseAPITest, Method_Not_Allowed, unittest.TestCase):
  def runAPI(self):
    (self.code, self.reason, self.data) = self.database.delete('/code/api/data')

######## End tests ###########
if __name__ == '__main__':
  apidb.testMain()
