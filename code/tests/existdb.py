''' 
  Library to run basic operations on eXist database through its REST interface

  Copyright 2009-2011 Efraim Feinstein
  Open Siddur Project
  Licensed under the GNU Lesser General Public License, version 3 or later
  
'''
import sys
import lxml.etree
import urllib2
import cookielib
import base64
import BaseHTTPServer

# This short bit of code from Benjamin Smedberg <http://benjamin.smedbergs.us/blog/2008-10-21/putting-and-deleteing-in-python-urllib2/>:
class RequestWithMethod(urllib2.Request):
  def __init__(self, method, *args, **kwargs):
    self._method = method
    urllib2.Request.__init__(self, *args, **kwargs)

  def get_method(self):
    return self._method

class Existdb:
    def __init__(self, server='localhost', port=8080, restPrefix = '', user = '', password = '', debuglevel = 0, useHTTPBasic = True, forceHTTPBasic = True, useSession = False):
        ''' Initialize an eXist REST client.  restPrefix is what comes after the port in the URL, eg, /exist/rest ...
        Use forceHTTPBasic to force send the HTTP Basic header even if the server didn't request it.
        '''
        if user == '' and password == '':
          # change the default for HTTP Basic if no passwords are given
          useHTTPBasic = False
          forceHTTPBasic = False

        self.server = 'http://%s:%d' % (server, port)
        self.restPrefix = restPrefix
        self.user = user
        self.password = password
        self.debuglevel = debuglevel
        self.useHTTPBasic = useHTTPBasic
        self.forceHTTPBasic = forceHTTPBasic
        self.useSession = useSession
        
        handlers = tuple() 
        if useHTTPBasic and not forceHTTPBasic:
          passwd = urllib2.HTTPPasswordMgrWithDefaultRealm()
          passwd.add_password(None, self.server, self.user, self.password)
          handlers = handlers + (urllib2.HTTPBasicAuthHandler(passwd),)

        if useSession:
          self.cookieJar = cookielib.LWPCookieJar()
          handlers = handlers + (urllib2.HTTPCookieProcessor(self.cookieJar),)
        else:
          self.cookieJar = None            
        
        handlers = handlers + (urllib2.HTTPHandler(debuglevel=debuglevel),)
        
        self.urlOpener = urllib2.build_opener(*handlers)

    # return (code, reason, data as string)    
    def openUrl(self, request):
      if self.forceHTTPBasic:
        enc = base64.encodestring('%s:%s' % (self.user, self.password))
        request.add_header("Authorization", "Basic %s" % enc) 
      try:
        response = self.urlOpener.open(request)
      except urllib2.HTTPError, err:
        response = err
      except urllib2.URLError, err:
        response = err
        response.getcode = lambda : 0
        response.close = lambda : ()
        response.read = lambda : str(err)
      finally:
        code = response.getcode()
        data = response.read()
        response.close()
        reason = BaseHTTPServer.BaseHTTPRequestHandler.responses[code][0]
      return (code, reason, data)

    def get(self, location):
        ''' send a get request for a location 
        Return (status, reason, data).
        '''
        url = self.server + self.restPrefix + location
        req = RequestWithMethod('GET', url)
        return self.openUrl(req)

    def put(self, location, document, contentType='text/xml'):
        ''' put a document to a given database location. 
        Return status, reason, headers
        '''
        url = self.server + self.restPrefix + location
        req = RequestWithMethod('PUT', url, data=document, 
          headers={'Content-Type':contentType})
        return self.openUrl(req)

    def delete(self, location):
        ''' delete a location
        Return (status, reason, data)
        '''
        url = self.server + self.restPrefix + location
        req = RequestWithMethod('DELETE', url)
        return self.openUrl(req)
    
    def createCollection(self, collection, base = '/db'):
      ''' make a collection (requires appropriate priveleges) '''
      return self.postQuery('xquery version "1.0";' + 
      'xmldb:create-collection("' + base + '", "' + collection + '")')
    
    def removeCollection(self, collection):
      ''' remove a collection (requires appropriate priveleges) '''
      return self.postQuery('xquery version "1.0";' + 
      'xmldb:remove("' + collection + '")')
 
    def post(self, location, document, contentType='text/xml'):
      ''' Post data to the database.
      location holds the database location (eg, starting with /db)
      Return (status, reason, data)
      '''
      url = self.server + self.restPrefix + location
      req = RequestWithMethod('POST', url, data=document, headers={'Content-type':contentType})
      return self.openUrl(req)
 
    def postQuery(self, queryString, postLocation='/db', 
        contentType='application/xml'):
        ''' Post a query to the database.
        postLocation holds the database location (eg, starting with /db)
        queryString holds the full query
        Return (status, reason, data)
        '''
        body = ('<?xml version="1.0" encoding="UTF-8"?>\n' +
            '<query xmlns="http://exist.sourceforge.net/NS/exist">\n'
            '<text>\n' + 
            '<![CDATA[\n' + 
            queryString +
            '\n]]>\n' + 
            '</text>\n' + 
            '</query>'
            )
        return self.post(postLocation, body, contentType)
    
    def postQueryFile(self, queryFile, postLocation='/db', 
        contentType='application/xml'):
        ''' Post a query from a file instead of a string '''
        f=file(queryFile, 'r')
        queryString=f.read()
        f.close()
        return self.postQuery(queryString, postLocation, contentType)

    def getPermissions(self, location):
      ''' get permissions (status, reason, user, group, mode) for a given location 
      user, group, and mode are all strings.  mode returns an octal number (as a string) 
      '''
      (status, reason, data) = self.postQuery(
        '''xquery version "1.0";
        import module namespace xmldb="http://exist-db.org/xquery/xmldb";
        import module namespace util="http://exist-db.org/xquery/util";
        
        let $location := "'''+location+'''"
        return
        if (xmldb:collection-available($location))
        then 
          <permissions>
            <user>{xmldb:get-owner($location)}</user>
            <group>{xmldb:get-group($location)}</group>
            <mode>{xmldb:get-permissions($location)}</mode>
          </permissions>
        else if (doc-available($location) or util:binary-doc-available($location))
        then 
          let $collection := util:collection-name($location)
          let $resource := util:document-name($location)
          return
            <permissions>
              <user>{xmldb:get-owner($collection, $resource)}</user>
              <group>{xmldb:get-group($collection, $resource)}</group>
              <mode>{xmldb:get-permissions($collection, $resource)}</mode>
            </permissions>
        else 
          <permissions>
            <user/>
            <group/>
            <mode/>
          </permissions>
        ''')
      if (status == 200):
        parsedData = lxml.etree.fromstring(data)
        user = parsedData[0][0].text
        group = parsedData[0][1].text
        mode = parsedData[0][2].text
        return (status, reason, user, group, '%o' % int(mode))
      else:
        return (status, reason, '','','')
      
if __name__ == "__main__":
    ''' The default thing to do is to pass a query '''
    server = 'localhost'
    port = 8080
    if len(sys.argv) >= 2:
      print len(sys.argv), sys.argv
      queryFile = sys.argv[1]
      if len(sys.argv) >= 3:
        server = sys.argv[2]
        if len(sys.argv) >= 4:
          port = int(sys.argv[3])
    else:
      print 'Usage: %s query-file [server [port]]' % sys.argv[0]
      exit(0)
    e = Existdb(server, port)
    (status, response, data) = e.postQueryFile(queryFile)
    print status, ' ', response, '\n'
    print data
    
