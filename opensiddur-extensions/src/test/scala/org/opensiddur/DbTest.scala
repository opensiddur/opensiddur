package org.opensiddur

import org.exist.xmldb.EXistResource
import org.opensiddur.DbTest._
import org.scalatest.funspec.AnyFunSpec
import org.scalatest.{BeforeAndAfterEach, BeforeAndAfterAll}
import org.xmldb.api.DatabaseManager
import org.xmldb.api.base._
import org.xmldb.api.modules._
import Numeric._

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
      (if (_auth.user.nonEmpty)
        s"system:as-user('${_auth.user.get}', ${if (_auth.user.get == "admin") "$magic:password" else s"'${_auth.pass.get}'"},"
       else "") +
      (if (_throws.nonEmpty) "try { " else "") +
      s"${_code}" +
      (if (_throws.nonEmpty) s"} catch ${_throws} { element threwException { '${_throws}' } }" else "") +
      ( if (_auth.user.nonEmpty) ")" else "") +
      "\nreturn (" + (
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

  def assertEquals[T : Numeric](value: T): Xq = {
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

  def assertXmlEquals(xml: String*): Xq = {
    val xmlSequence = "(" + xml.mkString(",") +  ")"
    assertXPathEquals("$output", s" output did not equal $xmlSequence", xml :_*)
  }

  def assertXPathEquals(xpath: String, clue: String, xml: String*): Xq = {
    val xmlSequence = "(" + xml.mkString(",") +  ")"

    new Xq(
      _code = _code,
      _prolog = _prolog,
      _throws = _throws,
      _assertions = _assertions :+ XPathAssertion(s"empty(tcommon:deep-equal($xpath, $xmlSequence))", clue),
      _auth = _auth
    )
  }

  // complex assertions
  def assertHttpNotFound: Xq = {
    this
      .assertXPath("""$output/self::rest:response/http:response/@status = 404""", "expected HTTP not found")
  }

  def assertHttpCreated: Xq = {
    this
      .assertXPath("""$output/self::rest:response/http:response/@status = 201""", "expected HTTP created")
      .assertXPath("""exists($output/self::rest:response/http:response/http:header[@name="Location"][@value])""", "returns a Location header")
  }

  def assertHttpBadRequest: Xq = {
    this
      .assertXPath("""$output/self::rest:response/http:response/@status = 400""", "expected HTTP bad request")
  }

  def assertHttpForbidden: Xq = {
    this
      .assertXPath("""$output/self::rest:response/http:response/@status = 403""", "expected HTTP forbidden")
  }

  def assertHttpNoData: Xq = {
    this
      .assertXPath("""$output/self::rest:response/http:response/@status = 204""", "expected HTTP No data")
      .assertXPath("""$output/self::rest:response/output:serialization-parameters/output:method = "text"""", "output is declared as text")
  }

  def assertHttpUnauthorized: Xq = {
    this
      .assertXPath("""$output/self::rest:response/http:response/@status = 401""", "expected HTTP unauthorized")
  }

  def assertSearchResults: Xq = {
    this
      .assertXPath("""$output/self::rest:response/output:serialization-parameters/output:method="xhtml"""", "serialize as XHTML")
      .assertXPath("""empty($output//html:head/@profile)""", "reference to Open Search @profile removed for html5 compliance")
      .assertXPath("""count($output//html:meta[@name='startIndex'])=1""", "@startIndex is present")
      .assertXPath("""count($output//html:meta[@name='endIndex'])=0""", "@endIndex has been removed")
      .assertXPath("""count($output//html:meta[@name='totalResults'])=1""", "@totalResults is present")
      .assertXPath("""count($output//html:meta[@name='itemsPerPage'])=1""", "@itemsPerPage is present")
  }

  def assertDiscoveryApi: Xq = {
    this
      .assertXPath("""exists($output/self::html:html/html:body/*[@class="apis"]/html:li[@class="api"]/html:a[@class="discovery"])""", "has a discovery API")
  }

  def assertSerializesAs(serialization: String): Xq = {
    this
      .assertXPath(s"""$$output/self::rest:response/output:serialization-parameters/output:method="$serialization" """, s"serializes as $serialization")
  }
}

abstract class DbTest extends AnyFunSpec with BeforeAndAfterEach with BeforeAndAfterAll with XQueryCall {
  def xq(code: String): Xq = {
      new Xq(code, prolog)
    }

  def setupUsers(n: Int) = {
    xq(s"""
    let $$users := tcommon:setup-test-users($n)
    return ()
    """)
      .go
  }

  def teardownUsers(n: Int) = {
    xq(
      s"""
        let $$users := tcommon:teardown-test-users($n)
        return ()
        """)
      .go
  }

  def readXmlFile(localSource: String): String = {
    val contentSource = io.Source.fromFile(localSource)
    val content = try {
      contentSource.getLines.mkString
    } finally {
      contentSource.close()
    }

    content
  }

  /** Store arbitrary content to an arbitrary path */
  def store(
             localSource: String,
             collection: String,
             resourceName: String,
             dataType: String = "application/xml",
             firstParamIsContent: Boolean = false
            ): Array[String] = {
    val content = if (firstParamIsContent) ("'" + localSource + "'") else readXmlFile(localSource)
    xq(s"""xmldb:store('$collection', '$resourceName', $content, '$dataType')""")
      .go
  }

  /** Remove an arbitrary path from the db */
  def remove(collection: String, resourceName: String) = {
    xq(s"""xmldb:remove('$collection', '$resourceName')""")
      .go
  }

  def setupResource(localSource: String,
                    resourceName: String,
                    dataType: String,
                    owner: Int,
                    subType: Option[String] = None,
                    group: Option[String] = None,
                    permissions: Option[String] = None,
                    firstParamIsContent: Boolean = false
                   ) = {
    val content = if (firstParamIsContent) ("'" + localSource + "'") else readXmlFile(localSource)
    xq(
      s"""
         let $$file := tcommon:setup-resource('${resourceName}',
          '${dataType}', $owner, $content,
          ${subType.fold("()") { "'" + _ + "'"}},
          ${group.fold("()") { "'" + _ + "'"}},
          ${permissions.fold("()") { "'" + _ + "'"}})
          return ()
        """)
      .go
  }

  def teardownResource(resourceName: String, dataType: String, owner: Int) = {
    xq(
      s"""
         let $$file := tcommon:teardown-resource('${resourceName}', '${dataType}', $owner)
          return ()
        """)
      .go
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

  val HTML5_SERIALIZATION = "xhtml"
  val XHTML_SERIALIZATION = "xhtml"
}