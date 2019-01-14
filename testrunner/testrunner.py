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

# ANSI escape codes: COLOR -> [BEGIN, END]
ANSI_ESCAPES = {
    "FAIL": ["\033[91m", "\033[00m"],      # FAIL = red
    "PASS": ["\033[92m", "\033[00m"],      # PASS = green
    "IGNORE": ["\033[93m", "\033[00m"],    # IGNORE = yellow
    "ERROR": ["\033[95m", "\033[00m"]      # ERROR = purple
}


def escaped(escape, *args):
    return ANSI_ESCAPES[escape][0] + "".join(args) + ANSI_ESCAPES[escape][1]


def indented(level):
    return "".join(["  "] * level)


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


class SaxBase(ContentHandler):
    """ Base of SAX operations """
    def __init__(self, tree):
        self.tree = tree

        self.tests = 0
        self.errors = 0
        self.fails = 0
        self.ignores = 0

        self.in_element = []
        self.path_map = defaultdict(int)

    def _as_string(self):
        """ 
        :return: The serialization of the children of the node currently being processed
        """
        def serialize(e):
            try:
                return etree.tounicode(e)
            except TypeError:
                return str(e)

        localname = self.in_element[-1]
        etx = etree.ETXPath("//*[local-name() = '{ln}'][{num}]/node()".format(ln=localname, num=self.path_map[localname]))
        return "\n".join([serialize(elem) for elem in etx(self.tree)])

    def startElementNS(self, name, qname, attributes):
        _, localname = name
    
        self.in_element.append(localname)
        self.path_map[localname] += 1
    
    def endElementNS(self, name, qname):
        self.in_element.pop()


class LegacyApiSax(SaxBase):
    def __init__(self, tree):
        super().__init__(tree)

    @staticmethod
    def _evaluate_passed(passed):
        evaluation = {
            "true": "PASS",
            "false": "FAIL",
            "ignore": "IGNORE"
        }
        return evaluation[passed]

    def _update_counts(self, passed):
        self.tests += 1
        if passed == "FAIL":
            self.fails += 1
        elif passed == "IGNORE":
            self.ignores += 1
        return passed

    def _test(self, attributes: dict):
        passed = self._update_counts(self._evaluate_passed(attributes[(None, "pass")]))
        desc = attributes[(None, "desc")]
        print(escaped(passed, indented(3) + desc))

    def _test_condition(self, attributes: dict):
        if (None, "desc") in attributes and (None, "pass") in attributes: # otherwise, it's a result
            passed = self._update_counts(self._evaluate_passed(attributes[(None, "pass")]))
            desc = attributes[(None, "desc")]
            print(escaped(passed, "{indent}[{passed}]{desc}".format(indent=indented(4), passed=passed, desc=desc)))
            if passed != "PASS":
                print(escaped(passed, indented(4) + self._as_string()))

    def _result(self, attributes: dict):
        print(escaped("FAIL", indented(4) + "[RESULT-----]" + self._as_string() + "[/-----RESULT]"))

    def startElementNS(self, name, qname, attributes):
        _, localname = name

        super().startElementNS(name, qname, attributes)

        if localname == "test":
            self._test(attributes)
        elif localname in ["xpath", "expected", "error"]:
            self._test_condition(attributes)
        elif localname == "result":
            self._result(attributes)

    def characters(self, content):
        if len(self.in_element) > 0:
            localname = self.in_element[-1]
            indent_level = 0

            if localname == "suitename":
                indent_level = 1
            elif localname == "testName":
                indent_level = 2
            else:
                return

            print(indented(indent_level) + content)


class XQSuiteApiSax(SaxBase):
    def __init__(self, tree):
        super().__init__(tree)
        
    def _testsuite(self, attributes: dict):
        tests = attributes.get((None, "tests"), "0")
        failures = attributes.get((None, "failures"), "0")
        errors = attributes.get((None, "errors"), "0")
        pending = attributes.get((None, "pending"), "0")

        output = {
            "package": attributes[(None, "package")],
            "tests": tests,
            "pass": escaped("PASS",
                                  str(int(tests) - int(failures) -
                                    int(errors) - int(pending))),
            "fail": escaped("FAIL", failures),
            "error": escaped("ERROR", errors),
            "ignore": escaped("IGNORE", pending)
        }
        print("Suite: {package}: tests: {tests} pass: {pass} fail: {fail} error: {error} ignore: {ignore}".format(**output))

    def _testcase(self, attributes: dict):
        output = {
            "indent": indented(1),
            "class": attributes[(None, "class")],
            "name": attributes[(None, "name")]
        }
        self.tests += 1
        print("{indent}[{class}]:{name}".format(**output))

    def _error(self, attributes: dict):
        output = {
            "indent": indented(2),
            "type": escaped("ERROR", "[ERROR] " + attributes[(None, "type")]),
            "message": escaped("ERROR", attributes[(None, "message")])
        }
        self.errors += 1
        print("{indent}{type}: {message}".format(**output))

    def _failure(self, attributes: dict):
        output = {
            "indent": indented(2),
            "type": escaped("FAIL", "[FAIL] " + attributes[(None, "type")]),
            "message": escaped("FAIL", attributes[(None, "message")])
        }
        self.fails += 1
        print("{indent}{type}: {message}\nExpected:".format(**output))
        print(escaped("FAIL", self._as_string()))

    def _output(self, attributes: dict):
        print(escaped("FAIL", "Actual:\n" + self._as_string()))

    def startElementNS(self, name, qname, attributes):
        _, localname = name

        super().startElementNS(name, qname, attributes)
        
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

    def characters(self, data):
        if len(self.in_element) > 0:
            this_element = self.in_element[-1]
            indent = indented(2)

            if this_element == "testsuite":
                print("{indent}{data}".format(indent=indent, data=escaped("ERROR", data)))


def http_request(host, port, request_uri):
    conn = http.client.HTTPConnection(host, port)
    conn.request("GET", request_uri)

    response = conn.getresponse()
    data = response.read()
    code = response.status
    conn.close()

    return data, code


class TestingApi:
    def __init__(self, test_api, host, port, prefix):
        self.host = host
        self.port = port
        self.prefix = prefix
        self.test_api = test_api

    def get_list_of_test_modules(self):
        api_code, api_result = self.rest_api_get(self.test_api)
        return api_result.xpath("//html:ul/html:li/html:a/@href[contains(., '?suite')]", namespaces=XML_NAMESPACES)

    def rest_api_get(self, api, prefix=None):
        """ Make a REST API call to URL, return the result """
        data, code = http_request(self.host, self.port, (self.prefix if prefix is None else prefix) + api)

        xtree = etree.parse(BytesIO(data))
        return code, xtree


class XQSuiteApi(TestingApi):
    def __init__(self, host=DEFAULT_HOST, port=DEFAULT_PORT, prefix=DEFAULT_PREFIX):
        super().__init__("/api/test", host, port, prefix)

    def run_suite(self, suite_api):
        api_code, api_result = self.rest_api_get(suite_api, prefix="")
        sax_handler = XQSuiteApiSax(api_result)
        sax.saxify(api_result, sax_handler)
        return sax_handler


class LegacyTestApi(TestingApi):
    def __init__(self, host=DEFAULT_HOST, port=DEFAULT_PORT, prefix=DEFAULT_PREFIX):
        super().__init__("/api/tests", host, port, prefix)

    def run_suite(self, suite_api):
        api_code, api_result = self.rest_api_get(suite_api, prefix="")
        if api_result.xpath("count(//TestSet)=0"):
            sax_handler = SaxBase(api_result)
            print(escaped("ERROR", "[ERROR] Legacy suite '{}' failed to execute".format(suite_api)))
            sax_handler.tests = 1
            sax_handler.errors = 1
        else:
            sax_handler = LegacyApiSax(api_result)
            sax.saxify(api_result, sax_handler)
        return sax_handler


def main():
    print("Waiting for server to be up...")
    if not wait_for_uptime():
        print("Server is down.")
        return 2

    suites, tests, errors, fails, ignores = 0, 0, 0, 0, 0

    suite_apis = {
        "XQSuite": XQSuiteApi(),
        "Legacy": LegacyTestApi()
    }

    for api_name, api_class in suite_apis.items():
        print("Getting {api} test suites...".format(api=api_name))

        list_of_modules = api_class.get_list_of_test_modules()
        print("  Found {} suites".format(len(list_of_modules)))
        for module in list_of_modules:
            print("Running {}...".format(module))
            sax_result = api_class.run_suite(module)
            tests += sax_result.tests
            errors += sax_result.errors
            fails += sax_result.fails
            ignores += sax_result.ignores
            suites += 1

    print("Tests completed: suites: {suites} pass: {passes} fail: {fail} error: {error} ignored: {ignored}".format(
        suites=suites,
        passes=escaped("PASS", str(tests - errors - fails - ignores)),
        fail=escaped("FAIL", str(fails)),
        error=escaped("ERROR", str(errors)),
        ignored=escaped("IGNORE", str(ignores))
    ))

    if (tests > 0 and (errors + fails) > 0):
        return 1
    else:
        return 0


if __name__ == "__main__":
    sys.exit(main())
