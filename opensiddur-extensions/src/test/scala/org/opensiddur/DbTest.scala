package org.opensiddur

import org.exist.xmldb.EXistResource
import org.opensiddur.DbTest._
import org.scalatest.funspec.AnyFunSpec
import org.scalatest.{BeforeAndAfterEach, BeforeAndAfterAll}
import org.xmldb.api.DatabaseManager
import org.xmldb.api.base._
import org.xmldb.api.modules._

trait XQueryCall {
  def initDb(): Unit = {
    val cl = Class.forName(driver)
    val database = cl.newInstance.asInstanceOf[Database]
    //database.setProperty("create-database", "true")
    DatabaseManager.registerDatabase(database)
  }

  /** run a generic XQuery. return the content as strings */
  def callXQuery(query: String): Array[String] = {
    var results = Array[String]()
    val col = DatabaseManager.getCollection(existUri + "/db")
    try {
      val xqs = col.getService("XQueryService", "1.0").asInstanceOf[XQueryService]
      val compiled = xqs.compile(query)
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
    catch {
      case ex:XMLDBException => {
        println(s"XQuery: $query")
        throw ex
      }
    }
    finally {
      if (col != null) {
        col.close()
      }
    }
    results
  }

}

/*
 it(...) {
  xq
  before
  code
  after
  assertXmlEquals (requires deepequality library)
  assertThrows exception
  assertXPath xqueryTest clue (optional)
  assertEquals
  assertTrue
  assertFalse
  assertEmpty
  go
 }
 */
case class XPathAssertion(
                           xpath: String,
                           clue: String
                         )

case class UserAndPass(user: Option[String] = None, pass: Option[String] = None)

class Xq(
        _code: String = "",
        _prolog: String = "",
        _throws: String = "",
        _assertions: Seq[XPathAssertion] = Seq(),
        _auth: UserAndPass = UserAndPass()
        ) extends XQueryCall {

  def prolog(xquery: String): Xq = {
    new Xq(
      _code = _code,
      _prolog = xquery,
      _throws = _throws,
      _assertions = _assertions,
      _auth = _auth
    )
  }

  def user(user: String, password: Option[String] = None): Xq = {
    new Xq(
      _code = _code,
      _prolog = _prolog,
      _throws = _throws,
      _assertions = _assertions,
      _auth = UserAndPass(Some(user), password.orElse(Some(user)))
    )
  }

  def code(xquery: String): Xq = {
    new Xq(
      _code = xquery,
      _prolog = _prolog,
      _throws = _throws,
      _assertions = _assertions,
      _auth = _auth
    )
  }

  /** construct a query that contains the prolog, code and assertions
   * after the last assertion, all output is returned */
  private def constructXQuery: String = {
    _prolog + "\n" +
    s"let $$output := " +
      (if (_auth.user.nonEmpty) { up : UserAndPass =>
        s"system:as-user('${up.user}', '${up.pass}',"
      } else "") +
      (if (_throws.nonEmpty) "try { " else "") +
      s"${_code}" +
      (if (_throws.nonEmpty) s"} catch ${_throws} { element threwException { '${_throws}' } }" else "") +
      ( if (_auth.user.nonEmpty) { ")" } else "") +
      "return (" + (
      if (_throws.nonEmpty) s"if ($$output instance of element(threwException)) then 1 else 0"
      else {
        _assertions.map { assertion: XPathAssertion =>
          s"if (${assertion.xpath}) then 1 else 0"
        }.mkString(",\n")
      }) +
      (if (_throws.nonEmpty || _assertions.nonEmpty) "," else "") + "\n$output\n)"
  }

  def go: Array[String] = {
    val xquery = constructXQuery
    val returns = callXQuery(xquery)
    val actualOutput =
      if (_throws.nonEmpty) returns.tail
      else returns.drop(_assertions.length)

    if (_throws.nonEmpty) {
      assert(returns(0) == "1", s"Did not throw ${_throws}")
    }
    else {
      _assertions.zipWithIndex.foreach { case (assertion: XPathAssertion, idx: Int) =>
        assert(returns(idx) == "1", assertion.clue + ": output = (" + actualOutput.mkString(",") + ")")
      }
    }
    returns
  }

  def assertThrows(exceptionType: String): Xq = {
    new Xq(
      _code = _code,
      _prolog = _prolog,
      _throws = exceptionType,
      _assertions = _assertions,
      _auth = _auth)
  }

  def assertEquals(value: String): Xq = {
    new Xq(
      _code = _code,
      _prolog = _prolog,
      _throws = _throws,
      _assertions = _assertions :+ XPathAssertion(s"$$output='$value'", s" output did not equal '$value'"),
      _auth = _auth
    )
  }

  def assertXPath(xpath: String, clue: String = ""): Xq = {
    new Xq(
      _code = _code,
      _prolog = _prolog,
      _throws = _throws,
      _assertions = _assertions :+ XPathAssertion(xpath,
        if (clue.nonEmpty) clue else s" output did not conform to '$xpath'"),
      _auth = _auth
    )
  }

  def assertEquals[T](value: Numeric[T]): Xq = {
    new Xq(
      _code = _code,
      _prolog = _prolog,
      _throws = _throws,
      _assertions = _assertions :+ XPathAssertion(s"$$output=$value", s" output did not equal $value"),
      _auth = _auth
    )
  }

  def assertTrue: Xq = {
    new Xq(
      _code = _code,
      _prolog = _prolog,
      _throws = _throws,
      _assertions = _assertions :+ XPathAssertion("$output", s" output was not true()"),
      _auth = _auth
    )
  }

  def assertFalse: Xq = {
    new Xq(
      _code = _code,
      _prolog = _prolog,
      _throws = _throws,
      _assertions = _assertions :+ XPathAssertion("not($output)", s" output was not false()"),
      _auth = _auth
    )
  }

  def assertEmpty: Xq = {
    new Xq(
      _code = _code,
      _prolog = _prolog,
      _throws = _throws,
      _assertions = _assertions :+ XPathAssertion("empty($output)", s" output was not empty"),
      _auth = _auth
    )
  }

  def assertXmlEqual(xml: String): Xq = {
    new Xq(
      _code = _code,
      _prolog = _prolog,
      _throws = _throws,
      _assertions = _assertions :+ XPathAssertion(s"tcommon:deep-equal($$output, $xml)", s" output did not equal $xml"),
      _auth = _auth
    )
  }
}

abstract class DbTest extends AnyFunSpec with BeforeAndAfterEach with BeforeAndAfterAll with XQueryCall {
  def xq(code: String): Xq = {
      new Xq(code, prolog)
    }

  override def beforeAll: Unit = {
    initDb
  }

  /** imports, namespaces and variables */
  val prolog: String

  /** run xquery setup code. The XQuery result is ignored/assumed to be empty */
  def xquerySetup(query: String): Unit = {
    xq(query)
    .go
  }

  /** run xquery teardown code. The XQuery result is ignored/assumed to be empty */
  def xqueryTearDown(query: String): Unit = {
    xq(query)
    .go
  }

}

object DbTest {
  // docker port for eXistdb
  val existPort = 5000

  val driver = "org.exist.xmldb.DatabaseImpl"
  val existUri = s"xmldb:exist://localhost:${existPort}/exist/xmlrpc"
}