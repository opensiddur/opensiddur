#!/usr/bin/env python3
import testrunner
import sys

print("Waiting for server to be up...")
if not testrunner.wait_for_uptime():
    print("Server is down.")
    sys.exit(2)
