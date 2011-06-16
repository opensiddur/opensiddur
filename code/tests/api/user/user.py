''' 
  Unit testing and documentation for the /code/api/user API

  Copyright 2011 Efraim Feinstein
  Open Siddur Project
  Licensed under the GNU Lesser General Public License, version 3 or later
  
'''
import sys
import getopt
import unittest 
import lxml.etree as etree

import apidb
  
adminPassword = None

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

#### USER CREATION #####

class Test_Create_User(apidb.BaseAPITestWithSession):
  newUserName = 'mynewtestuser'
  newPassword = 'imnottellingyou'

  def create_user(self, name, password):
    """ This API is how you create a new user! """
    (self.code, self.reason, self.data) = self.database.put(
      '/code/api/user/' + name, password, contentType='text/plain')

  def tearDown(self):
    # destroy the user we created and delete all remnants of it
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
    """ % (self.newUserName, adminPassword))

class Test_Create_User_With_Non_Existing_User(Test_Create_User, unittest.TestCase):
  def test_Returns_HTTP_status_201(self):
    self.create_user(self.newUserName, self.newPassword)
    self.assertResponse(self.code, 201, self.reason, self.data)

  def test_New_user_exists(self):
    self.create_user(self.newUserName, self.newPassword)
    (code, rsp, data) = self.database.postQuery("""
      xquery version "1.0"; 
      xmldb:exists-user('%s')
      """ % self.newUserName)
    self.assertTrue(self.toTree(data).xpath(
      "//exist:value=true()", namespaces=self.prefixes))
    

class Test_Create_User_That_Already_Exists(Test_Create_User, unittest.TestCase):
  def setUp(self):
    super(Test_Create_User_That_Already_Exists, self).setUp()
    self.create_user(self.newUserName, self.newPassword)
    self.assertStatusError(self.code, 201)
    # if we try to create the user again, it will change the password; we need to log out
    self.database.cookieJar.clear()

  def test_Creating_the_same_user_twice_returns_HTTP_status_401(self):
    self.create_user(self.newUserName, self.newPassword)
    self.assertResponse(self.code, 401, self.reason, self.data)

######## CHANGE PASSWORD ############

# change password API is the same as create user, but used on an existing user
class Test_Change_Password_For_User_That_Is_Logged_In(Test_Create_User, unittest.TestCase):
  secondPassword = 'thisisnottheoldpassword'

  def setUp(self):
    super(Test_Change_Password_For_User_That_Is_Logged_In, self).setUp()
    self.create_user(self.newUserName, self.newPassword)

  def test_Returns_HTTP_status_code_200(self):
    self.create_user(self.newUserName, self.secondPassword)
    self.assertResponse(self.code, 200, self.reason, self.data)

  def test_Correct_password_is_the_new_password(self):
    self.create_user(self.newUserName, self.secondPassword)
    (code, rsp, data) = self.database.postQuery("""
      xquery version "1.0"; 
      xmldb:authenticate('/db','%s','%s')
      """ % (self.newUserName, self.secondPassword))
    self.assertTrue(self.toTree(data).xpath(
      "//exist:result=true()", namespaces=self.prefixes))

######## User profile editing ##########

class User_Profile_Operations(apidb.BaseAPITest):
  # each user's profile is represented by a number of individual API calls
  def get_user_profile_menu(self, name):
    self.database.get('/code/api/user/' + name)

  def get_user_profile_content(self, name, profile, format):
    self.database.get('/code/api/user/' + name + '/' + profile + '.' + format) 

  def edit_user_profile_content(self, name, profile, format):
    self.database.put('/code/api/user/' + name + '/' + profile + '.' + format) 
  
  def clear_user_profile_content(self, name, profile, format):
    self.database.delete('/code/api/user/' + name + '/' + profile + '.' + format) 

######## End tests ###########
def usage():
  print "Unit testing framework. %s [-p admin-password] [-v]" % sys.argv[0]

if __name__ == '__main__':
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
