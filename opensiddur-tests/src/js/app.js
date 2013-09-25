/* Testing application
 * Copyright 2013 Efraim Feinstein, efraim@opensiddur.org
 * Licensed under the GNU Lesser General Public License, version 3 or later
 */
var httpPrefix = "/exist/restxq"; 

/* retrieve an API error return value and return the string */
var getApiError = function(data) {
  return $($.parseXML(data)).find("message").text();
}

var OpenSiddurTestingApp = 
    angular.module(
            'OpenSiddurTestingApp', []
    );

var parseDetails = function(testSuite) {
    testSets = [];
    $("testSet", testSuite).each(function() {
        var thisSet = $(this);
        var testSet = {};
        var tests = [];
        testSet.description = $("testName", thisSet).text();
        $("test", thisSet).each(function() {
            var thisTest = {};
            var assertions = [];

            thisTest.description = $(this).attr("desc");
            thisTest.pass = $(this).attr("pass");

            $(this).children().each(function() {
                thisAssert = $(this)
                assertions.push({
                    "description" : thisAssert.attr("desc"),
                    "pass" : thisAssert.attr("pass"),
                    "error" : thisAssert.text()
                });
            });
            thisTest.assertions = assertions;
            tests.push(thisTest);
        } );
        testSet.tests = tests;
        testSets.push(testSet);
    });
    return {
        "description" : $("p", testSuite).text(),
        "testSets" : testSets
    };
}; 

OpenSiddurTestingApp.controller(
        'MainCtrl',
        ['$scope', '$http',
        function ($scope, $http) {
            console.log("Testing controller.")
          
            $scope.errorMessage = "";
            $scope.suites = [];
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
                                        "n" : n,
                                        "running" : false,
                                        "complete" : false,
                                        "total" : undefined,
                                        "pass" : undefined,
                                        "fail" : undefined,
                                        "ignore" : undefined,
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
                        testSuiteObject.pass = $("test *[pass=true]", data).length;
                        testSuiteObject.fail = $("test *[pass=false]", data).length;
                        testSuiteObject.ignore = $("test *[pass=ignore]", data).length;
                        testSuiteObject.total = testSuiteObject.pass + testSuiteObject.fail + testSuiteObject.ignore;
                        testSuiteObject.details = parseDetails(data);
                        testSuiteObject.complete = true;
                        testSuiteObject.running = false;
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
