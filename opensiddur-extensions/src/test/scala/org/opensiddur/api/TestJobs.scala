package org.opensiddur.api

import org.opensiddur.DbTest

class BaseTestJobs extends DbTest {
  /** imports, namespaces and variables */
  override val prolog: String =
    """xquery version '3.1';

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";
import module namespace job="http://jewishliturgy.org/api/jobs"
  at "xmldb:exist:///db/apps/opensiddur-server/api/jobs.xqm";

declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";
declare namespace status="http://jewishliturgy.org/modules/status";
declare namespace http="http://expath.org/ns/http-client";
    """

  override def beforeAll: Unit = {
    super.beforeAll

    setupUsers(2)
  }

  override def afterAll(): Unit = {
    teardownUsers(2)

    super.afterAll()
  }

}

class TestJobGet extends  BaseTestJobs {
  override def beforeAll: Unit = {
    super.beforeAll

    store("""<status:job xmlns:status="http://jewishliturgy.org/modules/status" user="xqtest2" state="complete"
            |                    resource="/api/data/original/Test"
            |                    started="1900-01-01T01:00:00.0-08:00" 
            |                    complete="1900-01-01T01:01:01.2-08:00">
            |                    <status:complete timestamp="1900-01-01T01:01:01.2-08:00"
            |                        resource="/api/data/original/Test" />
            |                </status:job>""".stripMargin, "/db/cache/status", "1000-2000.status.xml",
      firstParamIsContent = true)
  }

  override def afterAll(): Unit = {
    remove("/db/cache/status", "1000-2000.status.xml")
    
    super.afterAll()
  }
  
  describe("job:get-job()") {
    it("gets an existing job") {
      xq("""job:get-job("1000-2000")""")
        .user("xqtest1")
        .assertXPath("""$output//status:job[@user="xqtest2"][@resource="/api/data/original/Test"]""", "returns a status document")
        .go
    }
    
    it("gets an nonexistent job") {
      xq("""job:get-job("1000-3000")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
  }
}

class TestJobList extends BaseTestJobs {
  override def beforeAll: Unit = {
    super.beforeAll

    store("""<status:job xmlns:status="http://jewishliturgy.org/modules/status"
            |                user="xqtest2"
            |                resource="/api/data/original/One"
            |                started="1900-01-01T00:00:01.1-08:00"
            |                completed="1900-01-01T00:01:01.1-08:00"
            |                state="complete"
            |                />""".stripMargin, "/db/cache/status", "1000-1000.status.xml",
      firstParamIsContent = true)
    store("""<status:job xmlns:status="http://jewishliturgy.org/modules/status"
            |                user="xqtest2"
            |                resource="/api/data/original/Two"
            |                started="1900-01-02T00:00:01.1-08:00"
            |                completed="1900-01-02T00:01:01.1-08:00"
            |                state="complete"
            |                />""".stripMargin, "/db/cache/status", "1000-2000.status.xml",
      firstParamIsContent = true)
    store("""<status:job xmlns:status="http://jewishliturgy.org/modules/status"
            |                user="xqtest2"
            |                resource="/api/data/original/Three"
            |                started="1900-01-03T00:00:01.1-08:00"
            |                state="working"
            |                />""".stripMargin, "/db/cache/status", "1000-3000.status.xml",
      firstParamIsContent = true)
    store("""<status:job xmlns:status="http://jewishliturgy.org/modules/status"
            |                user="xqtest2"
            |                resource="/api/data/original/Four"
            |                started="1900-01-04T00:00:01.1-08:00"
            |                failed="1900-01-04T00:01:01.1-08:00"
            |                state="failed"
            |                />""".stripMargin, "/db/cache/status", "1000-4000.status.xml",
      firstParamIsContent = true)
    store("""<status:job xmlns:status="http://jewishliturgy.org/modules/status"
            |                user="xqtest2"
            |                resource="/api/data/original/Five"
            |                started="1900-01-05T00:00:01.1-08:00"
            |                completed="1900-01-05T00:01:01.1-08:00"
            |                state="complete"
            |                />""".stripMargin, "/db/cache/status", "1000-5000.status.xml",
      firstParamIsContent = true)
  }
  
  override def afterAll(): Unit = {
    remove("/db/cache/status", "1000-1000.status.xml")
    remove("/db/cache/status", "1000-2000.status.xml")
    remove("/db/cache/status", "1000-3000.status.xml")
    remove("/db/cache/status", "1000-4000.status.xml")
    remove("/db/cache/status", "1000-5000.status.xml")
    
    super.afterAll()
  }

  describe("job:list") {
    it("returns all jobs") {
      xq("""job:list((), (), (), (), 1, 100)[2]""")
        .user("xqtest1")
        .assertXPath("""exists($output/self::html:html[descendant::html:ul[@class="results"]])""", "an HTML API results document is returned")
        .assertXPath("""count($output//html:li[@class="result"]) >= 5""", "at least 5 results are returned")
        .assertXPath("""count($output//html:li[@class="result"]) <= 100""", "at most max-results are returned")
        .assertXPath("""$output//html:li[@class="result"][1]/html:span[@class="started"]/string() > $output//html:li[@class="result"][2]/html:span[@class="started"]/string()""", "results are returned in descending order of start time")
        .go
    }

    it("returns an error for a nonexistent type") {
      xq("""job:list("typo", "xqtest1", (), (), 1, 100)[2]""")
        .user("xqtest1")
        .assertXPath("""exists($output/self::error)""")
        .go
    }

    it("returns all jobs belonging to a given user") {
      xq("""job:list("xqtest2", (), (), (), 1, 100)""")
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"])=5""", "5 results are returned")
        .assertXPath("""every $result in $output//html:li[@class="result"] satisfies matches($result/html:a/@href, "^/api/jobs/\d+-\d+$")""", "every result returns a pointer to an API")
        .assertXPath("""every $result in $output//html:li[@class="result"] satisfies $result/html:span[@class="user"]="xqtest2" """, "every result returns a user name")
        .assertXPath("""every $result in $output//html:li[@class="result"] satisfies $result/html:span[@class="state"]=("complete", "failed", "working")""", "every result returns a state")
        .assertXPath("""every $result in $output//html:li[@class="result"] satisfies matches($result/html:span[@class="started"], '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?[+-]\d{2}:\d{2}')""", "every result returns a start time")
        .assertXPath("""every $result in $output//html:li[@class="result"][html:span[@class="state"][not(.="working")]] satisfies matches($result/html:span[@class=("complete", "failed")], '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?[+-]\d{2}:\d{2}')""", "every completed of failed result returns a complete/failed time")
        .go
    }

    it("""returns all jobs belonging to a user in working state""") {
      xq("""job:list("xqtest2", "working", (), (), 1, 100)""")
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"])=1""", "1 result is returned")
        .assertXPath("""$output//html:li[@class="result"]/html:span[@class="state"]= "working" """, "the result's state is 'working'")
        .go
    }

    it("returns all jobs belonging to a user after a given date") {
      xq("""job:list("xqtest2", (), "1900-01-02", (), 1, 100)""")
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"])=4""", "4 results are returned")
        .assertXPath("""every $result in $output//html:li[@class="result"]/html:span[@class="started"] satisfies $result >= "1900-01-02" """, "every result's start date is after $from")
        .go
    }

    it("returns all jobs belonging to a user before a given date") {
      xq("""job:list("xqtest2", (), (), "1900-01-04", 1, 100)""")
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"])=3""", "3 results are returned")
        .assertXPath("""every $result in $output//html:li[@class="result"]/html:span[@class="started"] satisfies $result <= "1900-01-04" """, "every result's start date is before $to")
        .go
    }
  }
}
