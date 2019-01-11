#!/usr/bin/env python3
# This is the test runner for Open Siddur.
# What it does: call local host:port/exist/restxq/api/test to get a list of tests to run
# runs all of the tests
# print results to the console
# if any test returns FAIL or ERROR status, return with a nonzero exit code
#
# Copyright 2019 Efraim Feinstein <efraim@opensiddur.org>
# Licensed under the GNU Lesser General Public License, version 3 or later
import sys
import http.client
import time
from io import BytesIO
from lxml import etree, sax
from xml.sax.handler import ContentHandler
from collections import defaultdict

XML_NAMESPACES = {"html":"http://www.w3.org/1999/xhtml"}

DEFAULT_HOST = "localhost"
DEFAULT_PORT = 5000
DEFAULT_PREFIX = "/exist/restxq"

TEST_API = "/api/test"

# ANSI escape codes: COLOR -> [BEGIN, END]
ANSI_ESCAPES = {
    "FAIL": ["\033[91m", "\033[00m"],      # FAIL = red
    "PASS": ["\033[92m", "\033[00m"],      # PASS = green
    "IGNORE": ["\033[93m", "\033[00m"],    # IGNORE = yellow
    "ERROR": ["\033[95m", "\033[00m"]      # ERROR = purple
}


def wait_for_uptime(host=DEFAULT_HOST, port=DEFAULT_PORT, max_timeout_s=120):
    up = False
    start_time = time.time()
    elapsed_time = 0

    while not up and elapsed_time < max_timeout_s:
        try:
            _, code = http_request(host, port, "/")  # check if eXist is serving any web page
        except (ConnectionResetError, ConnectionRefusedError):
            code = 0
        elapsed_time = time.time() - start_time
        up = code == 200
        if not up:
            time.sleep(1)

    return up

class TestsuiteSAX(ContentHandler):
    def __init__(self, tree):
        self.tree = tree

        self.tests = 0
        self.errors = 0
        self.fails = 0
        self.ignores = 0

        self.in_element = []
        self.path_map = defaultdict(int)

    @staticmethod
    def _escaped(escape, *args):
        return ANSI_ESCAPES[escape][0] + "".join(args) + ANSI_ESCAPES[escape][1]

    @staticmethod
    def _indent(level):
        return "".join(["  "] * level)

    def _testsuite(self, attributes: dict):
        tests = attributes.get((None, "tests"), "0")
        failures = attributes.get((None, "failures"), "0")
        errors = attributes.get((None, "errors"), "0")
        pending = attributes.get((None, "pending"), "0")

        output = {
            "package": attributes[(None, "package")],
            "tests": tests,
            "pass": self._escaped("PASS",
                                  str(int(tests) - int(failures) -
                                    int(errors) - int(pending))),
            "fail": self._escaped("FAIL", failures),
            "error": self._escaped("ERROR", errors),
            "ignore": self._escaped("IGNORE", pending)
        }
        print("Suite: {package}: tests: {tests} pass: {pass} fail: {fail} error: {error} ignore: {ignore}".format(**output))

    def _testcase(self, attributes: dict):
        output = {
            "indent": self._indent(1),
            "class": attributes[(None, "class")],
            "name": attributes[(None, "name")]
        }
        self.tests += 1
        print("{indent}[{class}]:{name}".format(**output))

    def _error(self, attributes: dict):
        output = {
            "indent": self._indent(2),
            "type": self._escaped("ERROR", "[ERROR] " + attributes[(None, "type")]),
            "message": self._escaped("ERROR", attributes[(None, "message")])
        }
        self.errors += 1
        print("{indent}{type}: {message}".format(**output))

    def _failure(self, attributes: dict):
        output = {
            "indent": self._indent(2),
            "type": self._escaped("FAIL", "[FAIL] " + attributes[(None, "type")]),
            "message": self._escaped("FAIL", attributes[(None, "message")])
        }
        self.fails += 1
        print("{indent}{type}: {message}\nExpected:".format(**output))
        print(self._escaped("FAIL", self._as_string()))

    def _as_string(self):
        def serialize(e):
            try:
                return etree.tounicode(e)
            except TypeError:
                return str(e)

        localname = self.in_element[-1]
        etx = etree.ETXPath("//*[local-name() = '{ln}'][{num}]/node()".format(ln=localname, num=self.path_map[localname]))
        return "\n".join([serialize(elem) for elem in etx(self.tree)])

    def _output(self, attributes: dict):
        print(self._escaped("FAIL", "Actual:\n" + self._as_string()))

    def startElementNS(self, name, qname, attributes):
        _, localname = name

        self.in_element.append(localname)
        self.path_map[localname] += 1

        if localname == "testsuite":
            self._testsuite(attributes)
        elif localname == "testcase":
            self._testcase(attributes)
        elif localname == "error":
            self._error(attributes)
        elif localname == "failure":
            self._failure(attributes)
        elif localname == "output":
            self._output(attributes)

    def endElementNS(self, name, qname):
        self.in_element.pop()

    def characters(self, data):
        if len(self.in_element) > 0:
            this_element = self.in_element[-1]
            indent = self._indent(2)

            if this_element == "testsuite":
                print("{indent}{data}".format(indent=indent, data=self._escaped("ERROR", data)))


def http_request(host, port, request_uri):
    conn = http.client.HTTPConnection(host, port)
    conn.request("GET", request_uri)

    response = conn.getresponse()
    data = response.read()
    code = response.status
    conn.close()

    return data, code


def rest_api_get(
        api,
        host=DEFAULT_HOST, port=DEFAULT_PORT, prefix=DEFAULT_PREFIX):
    """ Make a REST API call to URL, return the result """
    data, code = http_request(host, port, prefix + api)

    xtree = etree.parse(BytesIO(data))
    return code, xtree


def get_list_of_test_modules(
        host=DEFAULT_HOST, port=DEFAULT_PORT, prefix=DEFAULT_PREFIX):
    api_code, api_result = rest_api_get(TEST_API, host, port, prefix)
    return api_result.xpath("//html:ul/html:li/html:a/@href[contains(., '?suite')]", namespaces=XML_NAMESPACES)


def run_suite(
        suite_api,
        host=DEFAULT_HOST, port=DEFAULT_PORT):
    api_code, api_result = rest_api_get(suite_api, host, port, prefix="")
    sax_handler = TestsuiteSAX(api_result)
    sax.saxify(api_result, sax_handler)
    return sax_handler

def main():
    print("Waiting for server to be up...")
    if not wait_for_uptime():
        print("Server is down.")
        return 2

    suites, tests, errors, fails, ignores = 0, 0, 0, 0, 0

    print("Getting test suites...")
    list_of_modules = get_list_of_test_modules()
    print("  Found {} suites".format(len(list_of_modules)))
    for module in list_of_modules:
        print("Running {}...".format(module))
        sax_result = run_suite(module)
        tests += sax_result.tests
        errors += sax_result.errors
        fails += sax_result.fails
        ignores += sax_result.ignores
        suites += 1

    print("Tests completed: suites: {suites} pass: {passes} fail: {fail} error: {error} ignored: {ignored}".format(
        suites=suites,
        passes=TestsuiteSAX._escaped("PASS",str(tests-errors-fails-ignores)),
        fail=TestsuiteSAX._escaped("FAIL", str(fails)),
        error=TestsuiteSAX._escaped("ERROR", str(errors)),
        ignored=TestsuiteSAX._escaped("IGNORE", str(ignores))
    ))

    if (tests > 0 and (errors + fails) > 0):
        return 1
    else:
        return 0


if __name__ == "__main__":
    sys.exit(main())
