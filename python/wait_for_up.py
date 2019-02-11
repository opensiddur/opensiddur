#!/usr/bin/env python3
import sys
import argparse
import time
import http.client


def http_request(host, port, request_uri):
    conn = http.client.HTTPConnection(host, port)
    conn.request("GET", request_uri)

    response = conn.getresponse()
    data = response.read()
    code = response.status
    conn.close()

    return data, code


def wait_for_uptime(host, port, api, max_timeout_s):
    up = False
    start_time = time.time()
    elapsed_time = 0

    while not up and elapsed_time < max_timeout_s:
        try:
            _, code = http_request(host, port, api)  # check if eXist is serving any web page
        except (ConnectionResetError, ConnectionRefusedError, http.client.BadStatusLine):
            code = 0
        elapsed_time = time.time() - start_time
        up = code == 200
        if not up:
            time.sleep(1)

    return up


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', action="store", dest="host", default="localhost")
    parser.add_argument('--port', action="store", dest="port", type=int, default=8080)
    parser.add_argument('--max-timeout', action="store", dest="timeout", type=int, default=1200)
    parser.add_argument('--api', action="store", dest="api", default="/exist/restxq/api")
    args = parser.parse_args()

    if wait_for_uptime(args.host, args.port, args.api, args.timeout):
        sys.exit(0)
    else:
        print("host", args.host, ":", args.port, "/", args.api, "was not active in", args.timeout, "seconds")
        sys.exit(1)
