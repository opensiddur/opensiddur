/* Testing application
 * Copyright 2013 Efraim Feinstein, efraim@opensiddur.org
 * Licensed under the GNU Lesser General Public License, version 3 or later
 */
var httpPrefix = "/exist/restxq"; 

/* retrieve an API error return value and return the string */
var getApiError = function(data) {
  return $($.parseXML(data)).find("message").text();
};

var OpenSiddurTestingApp = 
    angular.module(
            'OpenSiddurTestingApp', []
    );

var passClass = function(passValue) {
    return (passValue == "true") ? "pass" :
        (passValue == "false") ? "fail" : 
        passValue;
};

var parseDetails = function(testSuite) {
    testSets = [];
    passed = 0;
    failed = 0;
    ignored = 0;
    
    $("testSet", testSuite).each(function() {
        var thisSet = $(this);
        var testSet = {};
        var tests = [];
        testSet.description = $("testName", thisSet).text();
        testSet.passed = 0;
        testSet.failed = 0;
        testSet.ignored = 0;

        $("test", thisSet).each(function() {
            var thisTest = {};
            var assertions = [];

            thisTest.description = $(this).attr("desc");
            thisTest.pass = passClass($(this).attr("pass"));
            thisTest.result = $("result", this).html();
            thisTest.passed = 0;
            thisTest.failed = 0;
            thisTest.ignored = 0;
            $(this).children(":not(result)").each(function() {
                thisAssert = $(this);
                pass = passClass(thisAssert.attr("pass"));
                if (pass == "pass") {
                    ++thisTest.passed;
                    ++testSet.passed;
                    ++passed;
                }
                else if (pass == "fail") {
                    ++thisTest.failed;
                    ++testSet.failed;
                    ++failed;
                }
                else { 
                    ++thisTest.ignored;
                    ++testSet.ignored;
                    ++ignored;
                }
 
                assertions.push({
                    "description" : thisAssert.attr("desc"),
                    "pass" : pass,
                    "error" : thisTest.result
                });
                console.log(thisTest);
            });
            thisTest.assertions = assertions;
            tests.push(thisTest);
        } );
        testSet.tests = tests;
        testSets.push(testSet);
    });
    return {
        "description" : $("p", testSuite).text(),
        "testSets" : testSets,
        "passed" : passed,
        "failed" : failed,
        "ignored" : ignored
    };
}; 

OpenSiddurTestingApp.controller(
        'MainCtrl',
        ['$scope', '$http',
        function ($scope, $http) {
            console.log("Testing controller.")
          
            $scope.errorMessage = "";
            $scope.suites = [];
            $scope.passed = 0;
            $scope.failed = 0;
            $scope.ignored = 0;
            $scope.runningAll = false;
            $scope.list = function () {
                $http.get(
                    httpPrefix + "/api/tests",
                    {
                    transformResponse: function(data, headers) {
                        console.log(data);
                        var testSuites = [];
                        var n = 0;
                        $("a.document", data).each(
                                function () {
                                    var element = $(this);
                                    testSuites.push({
                                        "name" : element.text(),
                                        "api" : element.attr("href"),
                                        "n" : n,            // counts the number of tests. Saves some computation.
                                        "running" : false,
                                        "complete" : false,
                                        "total" : undefined,
                                        "passed" : undefined,
                                        "failed" : undefined,
                                        "ignored" : undefined,
                                        "showDetails" : false,
                                        "details" : undefined,
                                        "toggleDetails" : function () {
                                            this.showDetails = !this.showDetails;
                                        }
                                    });
                                    ++n;
                                }
                        );
                        return testSuites;
                    }
                  })
                .success(
                    function(data, status, headers, config) {
                        $scope.errorMessage = "";
                        console.log(data);
                        $scope.suites = data;
                    }
                )
                .error(
                    function(data, status, headers, config) {
                      $scope.errorMessage = getApiError(data)
                    }
                );
              
          };
          $scope.runAll = function() {
                console.log("Run all tests");
                this.runningAll = true;
                this.passed = 0;
                this.failed = 0;
                this.ignored = 0;
                callback = function(testSuiteNumber, data) {
                    console.log("callback for " + testSuiteNumber + " # of suites: " + $scope.suites.length);
                    next = testSuiteNumber + 1;
                    if (next < $scope.suites.length)
                        $scope.runSuite(next, callback, callback);
                    else
                        $scope.runningAll = false;
                };
                this.runSuite(0, callback, callback)
          };
          $scope.runSuite = function(testSuiteNumber, successCallback, failureCallback) {
                console.log("Run " + testSuiteNumber)
                testSuiteObject = this.suites[testSuiteNumber]
                testSuiteObject.running = true;
                $http.get(testSuiteObject.api) 
                .success(function(data) {
                        console.log("Success");
                        // extract total, pass, fail, ignore numbers
                        testSuiteObject.details = parseDetails(data);
                        testSuiteObject.complete = true;
                        testSuiteObject.running = false;
                        testSuiteObject.passed = testSuiteObject.details.passed;
                        testSuiteObject.failed = testSuiteObject.details.failed;
                        testSuiteObject.ignored = testSuiteObject.details.ignored;
                        testSuiteObject.total = testSuiteObject.passed + testSuiteObject.failed + testSuiteObject.ignored;
                        $scope.passed += testSuiteObject.passed;
                        $scope.failed += testSuiteObject.failed;
                        $scope.ignored += testSuiteObject.ignored;
                        if (successCallback)
                            successCallback(testSuiteNumber, data);
                    }
                )
                .error(function(data) {
                        console.log("Error");
                        testSuiteObject.running = false;
                        if (failureCallback)
                            failureCallback(testSuiteNumber, data);
                    }
                );
          };
          $scope.runningButtonText = function() {
                return (this.runningAll) ? "Running..." : "Run";
          };
          
          $scope.list();
        }
        ]
      );
