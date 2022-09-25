#!/usr/bin/env python3
import argparse
import http.client
import sys
import time

DEFAULT_HOST = "localhost"
DEFAULT_PORT = 5000
DEFAULT_PREFIX = "/exist/restxq"


def http_request(host, port, request_uri):
    conn = http.client.HTTPConnection(host, port)
    conn.request("GET", request_uri)

    response = conn.getresponse()
    data = response.read()
    code = response.status
    conn.close()

    return data, code


def wait_for_uptime(host=DEFAULT_HOST, port=DEFAULT_PORT, max_timeout_s=240):
    up = False
    start_time = time.time()
    elapsed_time = 0

    while not up and elapsed_time < max_timeout_s:
        try:
            _, code = http_request(host, port, "/")  # check if eXist is serving any web page
        except (ConnectionResetError, ConnectionRefusedError, http.client.BadStatusLine):
            code = 0
        elapsed_time = time.time() - start_time
        up = code == 200
        if not up:
            time.sleep(1)

    return up


ap = argparse.ArgumentParser()
ap.add_argument("--host", default="localhost", dest="host", type=str)
ap.add_argument("--port", default=5000, dest="port", type=int)
ap.add_argument("--timeout", default=86400, dest="timeout", type=int)
args = ap.parse_args()

print("Waiting {}s for server {}:{} to be up...".format(args.timeout, args.host, args.port))
if not wait_for_uptime(host=args.host, port=args.port, max_timeout_s=args.timeout):
    print("Server is down.")
    sys.exit(2)
