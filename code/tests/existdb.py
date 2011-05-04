''' 
  Library to run basic operations on eXist database through its REST interface

  Copyright 2009-2010 Efraim Feinstein
  Open Siddur Project
  Licensed under the GNU Lesser General Public License, version 3 or later

  $Id: existdb.py 687 2011-01-23 23:36:48Z efraim.feinstein $
'''
import sys
import lxml.etree
import httplib
import base64

class Existdb:
    def __init__(self, server='localhost', port=8080, restPrefix = '', user = '', password = '', debuglevel = 0, useHTTPBasic = True):
        ''' Initialize an eXist REST client.  restPrefix is what comes after the port in the URL, eg, /exist/rest ...
        '''
        self.server = '%s:%d' % (server, port)
        self.restPrefix = restPrefix
        self.user = user
        self.password = password
        self.debuglevel = debuglevel
        self.useHTTPBasic = useHTTPBasic
    
    def authenticationHeader(self):
      ''' Internal function: used to return an HTTP Basic header to authenticate by the given user and password 
      Alternately, use Username and Password headers. '''
      if len(self.user) > 0:
        if self.useHTTPBasic:
          return {'Authorization':'Basic %s' % (base64.b64encode('%s:%s' % (self.user, self.password)) )}
        else:
          return {'Username':self.user, 'Password':self.password}
      else:
        return {}

    def get(self, location):
        ''' send a get request for a location 
        Return (status, reason, data).
        '''
        conn = httplib.HTTPConnection(self.server)
        conn.set_debuglevel(self.debuglevel)
        conn.request("GET", self.restPrefix + location, headers = self.authenticationHeader())
        response = conn.getresponse()
        data = response.read()
        conn.close()
        return (response.status, response.reason, data)

    def put(self, location, document, contentType='text/xml'):
        ''' put a document to a given database location. 
        Return status, reason, headers
        '''
        conn = httplib.HTTPConnection(self.server)
        conn.set_debuglevel(self.debuglevel)
        headers = {'Content-Type':contentType}
        headers.update(self.authenticationHeader())
        conn.request('PUT', self.restPrefix + location, document, headers)
        #print 'PUT: ' + location + ' ' + self.user + ':'+ self.password + ' ' + document
        response = conn.getresponse()
        data = response.read()
        conn.close()
        return (response.status, response.reason, data)

    def delete(self, location):
        ''' delete a location
        Return (status, reason, data)
        '''
        conn = httplib.HTTPConnection(self.server)
        conn.set_debuglevel(self.debuglevel)
        conn.request("DELETE", self.restPrefix + location, headers = self.authenticationHeader())
        response = conn.getresponse()
        data=response.read()
        conn.close()
        return (response.status, response.reason, data)
    
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
      headers = {"Content-type": contentType}
      headers.update(self.authenticationHeader())
      conn = httplib.HTTPConnection(self.server)
      conn.set_debuglevel(self.debuglevel)
      conn.request("POST", self.restPrefix + location, document, headers)
      response = conn.getresponse()
      
      data = response.read()
      conn.close()
      return (response.status, response.reason, data)
 
    def postQuery(self, queryString, postLocation='/db', 
        contentType='text/xml'):
        ''' Post a query to the database.
        postLocation holds the database location (eg, starting with /db)
        queryString holds the full query
        Return (status, reason, data)
        '''
        headers = {"Content-type": contentType}
        headers.update(self.authenticationHeader())
        body = ('<?xml version="1.0" encoding="UTF-8"?>\n' +
            '<query xmlns="http://exist.sourceforge.net/NS/exist">\n'
            '<text>\n' + 
            '<![CDATA[\n' + 
            queryString +
            '\n]]>\n' + 
            '</text>\n' + 
            '</query>'
            )
        conn = httplib.HTTPConnection(self.server)
        conn.set_debuglevel(self.debuglevel)
        conn.request("POST", self.restPrefix + postLocation, body, headers)
        response = conn.getresponse()
        
        data = response.read()
        conn.close()
        return (response.status, response.reason, data)
    
    def postQueryFile(self, queryFile, postLocation='/db', 
        contentType='text/xml'):
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
    
