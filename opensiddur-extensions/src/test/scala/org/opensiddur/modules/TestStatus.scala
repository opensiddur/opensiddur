package org.opensiddur.modules

import org.opensiddur.DbTest

class TestStatus extends DbTest {
  override val prolog: String =
    """xquery version '3.1';
import module namespace status="http://jewishliturgy.org/modules/status"
      at "xmldb:exist:///db/apps/opensiddur-server/modules/status.xqm";

import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
  at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";


declare function local:job-id() {
    let $resource-id := util:absolute-resource-id(doc("/db/data/original/en/test-status.xml"))
    let $timestamp :=  string((current-dateTime() - xs:dateTime("1970-01-01T00:00:00-00:00")) div xs:dayTimeDuration('PT0.001S'))
    return $resource-id || "-" || $timestamp
};

declare function local:job-document-name() {
    let $status-document := local:job-id() || ".status.xml"
    return $status-document
};

declare function local:job-document() {
    doc($status:status-collection || "/" || local:job-document-name())
};

declare function local:tei-document() {
    doc("/db/data/original/en/test-status.xml")
};
    """
    
  override def beforeAll: Unit = {
    super.beforeAll
    xq("""let $users := tcommon:setup-test-users(1)
         return ()""")
      .go
    setupResource("src/test/resources/modules/test-status.xml", "test-status", "original", 1, Some("en"))

  }
  
  override def afterAll(): Unit = {
    teardownResource("test-status", "original", 1)
    xq("""try {
              xmldb:remove($status:status-collection, local:job-document-name())
         }
         catch * { () }""")
      .user("xqtest1")
      .go
    xq("""
      let $users := tcommon:teardown-test-users(1)
         return ()""")
      .go

    super.afterAll()
  }
  
  describe("status:start-job") {
    it("starts a job") {
      xq("""let $doc := doc("/db/data/original/en/test-status.xml")
           let $start := status:start-job($doc)
           return doc($status:status-collection || "/" || $start || ".status.xml")""")
        .user("xqtest1")
        .assertXPath("""exists($output//status:job)""", "a status document has been created")
        .assertXPath("""$output//status:job/@user = "xqtest1"""", "the document references the user")
        .assertXPath("""matches($output//status:job/@started, "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?(Z|([+-]\d{2}:\d{2}))$")""",
          "the document references a start time")
        .assertXPath("""$output//status:job/@state = "working"""", "the document status is working")
        .assertXPath("""ends-with($output//status:job/@resource, "/api/data/original/test-status")""", "the document references the API path of the document")
        .go
    }
  }
  
  describe("status:complete-job") {
    it("marks a job as complete") {
      xq(
        """
          let $start := status:start-job(local:tei-document())
          let $complete := status:complete-job(local:job-id(), document-uri(local:tei-document()))
          return local:job-document()""")
        .user("xqtest1")
        .assertXPath("""exists($output//status:job/status:complete)""", "completion element has been added")
        .assertXPath("""exists($output//status:job/@completed)""", "completion timestamp has been added")
        .assertXPath("""$output//status:job/@state = "complete"""", "job status has been changed to 'complete'")
        .go
    }
  }
  
  describe("status:fail-job") {
    it("marks the job as failed ") {
      xq(
        """let $start := status:start-job(local:tei-document())
         let $fail := status:fail-job(local:job-id(), document-uri(local:tei-document()), "testing", "ERROR")
         return local:job-document()
        """)
        .user("xqtest1")
        .assertXPath("""exists($output//status:job/status:fail)""", "fail element has been added")
        .assertXPath("""$output//status:fail/@stage = "testing"""", "fail element records the fail stage")
        .assertXPath("""$output//status:fail = "ERROR"""", "fail element records the fail error")
        .assertXPath("""exists($output//status:job/@failed)""", "failed timestamp has been added")
        .assertXPath("""$output//status:job/@state = "failed"""", "job status has been changed to 'failed'")
        .go
    }
  }
  
  describe("status:start") {
    it("starts a stage") {
      xq(
        """let $setup := status:start-job(local:tei-document())
           let $start := status:start(local:job-id(), local:tei-document(), "testing")
           return local:job-document()
          """)
        .user("xqtest1")
        .assertXPath("""count($output//status:job/status:start)=1""", "start element has been added")
        .assertXPath("""exists($output//status:job/status:start/@timestamp)""", "start element has a timestamp")
        .assertXPath("""$output//status:job/status:start/@stage = "testing"""", "start element stage is recorded")
        .go
    }
  }
  
  describe("status:finish") {
    it("marks a stage as finished") {
      xq(
        """let $setup := status:start-job(local:tei-document())
           let $start := status:start($setup, local:tei-document(), "testing")
           let $finish := status:finish(local:job-id(), local:tei-document(), "testing")
           return local:job-document()
          """)
        .user("xqtest1")
        .assertXPath("""count($output//status:job/status:finish)=1""", "finish element has been added")
        .assertXPath("""$output//status:job/status:finish >> $output//status:job/status:start""", "finish element is after the start element")
        .assertXPath("""exists($output//status:job/status:finish/@timestamp)""", "finish element has a timestamp")
        .assertXPath("""$output//status:job/status:finish/@stage = "testing"""", "finish element stage is recorded")
        .go
    }
  }
  
  describe("status:log") {
    it("logs a message") {
      xq(
        """let $setup := status:start-job(local:tei-document())
           let $log := status:log(local:job-id(), local:tei-document(), "testing", "MESSAGE")
           return local:job-document()
          """)
        .user("xqtest1")
        .assertXPath("""count($output//status:job/status:log)=1""", "log element has been added")
        .assertXPath("""$output//status:job/status:log = "MESSAGE"""", "log element records the message")
        .assertXPath("""exists($output//status:job/status:log/@timestamp)""", "log element has a timestamp")
        .assertXPath("""$output//status:job/status:log/@stage = "testing"""", "log element stage is recorded")
        .go
    }
  }
}
