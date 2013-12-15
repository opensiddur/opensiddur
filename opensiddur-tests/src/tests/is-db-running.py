#!/usr/bin/env python 
#  Usage: is-db-running [options]
#   options:
#     -s server
#     -p port
#
#   Return 0 if yes, nonzero if no.
#
#  Copyright 2010 Efraim Feinstein
#  Open Siddur Project
#  Licensed under the GNU Lesser General Public License version 3 or later
#
# $Id: is-db-running.py 687 2011-01-23 23:36:48Z efraim.feinstein $
import sys
import getopt
import existdb

def usage():
  message = """usage: %s [options] 
  options:
    -s server   server address (default: localhost)
    -p port     port (default: 8080)
    -q          quiet (supporess error message)
    -h          this help message
  returns status code 0 if database is running, status code 1 and an error message if not
  """ % sys.argv[0]

def main():
    try:
        opts, args = getopt.getopt(sys.argv[1:], "hs:p:q", ["help", "server=", "port=", "quiet"])
    except getopt.GetoptError, err:
        # print help information and exit:
        print str(err) # will print something like "option -a not recognized"
        usage()
        return 2
    server = 'localhost'
    port = 8080
    quiet = False
    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            return 0
        elif o in ("-s", "--server"):
            server = a
        elif o in ("-p", "--port"):
            port = int(a)   # make sure it's an integer
        elif o in ("-q", "--quiet"):
            quiet = True
        else:
            assert False, "Unknown option"

    db = existdb.Existdb(server=server, port=port)
    try:
      (status, reason, data) = db.get("/db")
    except Exception, e:
      status = 0
      reason = str(e)

    if status == 200:
      return 0
    else:
      if not quiet:
        print >> sys.stderr, "Database access returned: %s (code %d).  It is probably not running or there is something wrong." % (reason, status)
      return 1

if __name__ == '__main__':
  sys.exit(main())
