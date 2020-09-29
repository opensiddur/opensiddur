package org.opensiddur

import org.exist.xmldb.EXistResource
import org.opensiddur.DbTest._
import org.scalatest.funspec.AnyFunSpec
import org.scalatest.{BeforeAndAfterEach, BeforeAndAfterAll}
import org.xmldb.api.DatabaseManager
import org.xmldb.api.base._
import org.xmldb.api.modules._

case class XQueryTest(
                     expr: String,
                     failureMessage: String,
                     result: Boolean = true
                     )

abstract class DbTest extends AnyFunSpec with BeforeAndAfterEach with BeforeAndAfterAll {
  def initDb(): Unit = {
    val cl = Class.forName(driver)
    val database = cl.newInstance.asInstanceOf[Database]
    //database.setProperty("create-database", "true")
    DatabaseManager.registerDatabase(database)
  }

  /** imports, namespaces and variables */
  def prolog: String

  /** run a generic XQuery. return the content as strings */
  protected def runXQuery(query: String): Array[String] = {
    var results = Array[String]()
    val col = DatabaseManager.getCollection(existUri + "/db")
    try {
      val xqs = col.getService("XQueryService", "1.0").asInstanceOf[XQueryService]
      val compiled = xqs.compile(prolog + "\n" + query)
      val result = xqs.execute(compiled)
      val iter = result.getIterator
      while (iter.hasMoreResources) {
        var res: EXistResource = null
        try {
          res = iter.nextResource.asInstanceOf[EXistResource]
          results = results :+ res.getContent.toString
        } finally {
          // cleanup resources
          res.freeResources()
        }
      }
    }
    finally {
      if (col != null) {
        col.close()
      }
    }
    results
  }

  /** run xquery setup code. The XQuery result is ignored/assumed to be empty */
  def xquerySetup(query: String): Unit = {
    runXQuery(query)
  }

  /** run xquery teardown code. The XQuery result is ignored/assumed to be empty */
  def xqueryTearDown(query: String): Unit = {
    runXQuery(query)
  }

  /** Run an XQuery test or set of tests.
   *
   *  @param codeUnderTest XQuery code to test. Will be placed in a let expression called $output
   *  @param testExpressions XQuery test code and failure messages. Each test must resolve to a boolean. It may reference $output
   */
  def xqueryTest(
                  codeUnderTest: String,
                  testExpressions: Seq[XQueryTest]
                ): Unit = {
    val testingQuery = prolog + "\n" +
      "let $output := \n" +
        s"$codeUnderTest\n" +
      "return (\n" +
      "<output>{$output}</output>\n" +
      testExpressions.map { testExpression =>
        s"if (${testExpression.expr}) then 0 else 1"
      }.mkString(",\n") + "\n)"
    val results = runXQuery(testingQuery)
    val output = results.head
    testExpressions.zip(results.tail).foreach { case (testExpression, result) =>
      assert(result == "1",
      s"${testExpression.failureMessage}\nfrom: ${testExpression.expr}\non $output")
    }
  }
}

object DbTest {
  // docker port for eXistdb
  val existPort = 5000

  val driver = "org.exist.xmldb.DatabaseImpl"
  val existUri = s"xmldb:exist://localhost:${existPort}/exist/xmlrpc"
}