#!/usr/bin/env python3
import argparse
import testrunner
import sys

ap = argparse.ArgumentParser()
ap.add_argument("--host", default="localhost", dest="host", type=str)
ap.add_argument("--port", default=5000, dest="port", type=int)
ap.add_argument("--timeout", default=86400, dest="timeout", type=int)
args = ap.parse_args()

print("Waiting {}s for server {}:{} to be up...".format(args.timeout, args.host, args.port))
if not testrunner.wait_for_uptime(host=args.host, port=args.port, max_timeout_s=args.timeout):
    print("Server is down.")
    sys.exit(2)
