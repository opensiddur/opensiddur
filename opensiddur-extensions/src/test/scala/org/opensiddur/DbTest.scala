package org.opensiddur

import scala.io.Source
import org.exist.xmldb.EXistResource
import org.opensiddur.DbTest._
import org.scalatest.funspec.AnyFunSpec
import org.scalatest.{BeforeAndAfterAll, BeforeAndAfterEach}
import org.xmldb.api.DatabaseManager
import org.xmldb.api.base._
import org.xmldb.api.modules._
import scala.xml.XML

import Numeric._

trait AbstractXQueryCall {
  def callXQuery(query: String): Array[String]
}

trait XQueryCall extends AbstractXQueryCall {
  def initDb(): Unit = {
    val cl = Class.forName(driver)
    val database = cl.newInstance.asInstanceOf[Database]
    //database.setProperty("create-database", "true")
    DatabaseManager.registerDatabase(database)
  }

  /** run a generic XQuery. return the content as strings */
  override def callXQuery(query: String): Array[String] = {
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

  def copy(__code: String = _code,
           __prolog: String = _prolog,
           __throws: String = _throws,
           __assertions: Seq[XPathAssertion] = _assertions,
           __auth: UserAndPass = _auth): Xq = {
    new Xq(__code, __prolog, __throws, __assertions, __auth)
  }

  def prolog(xquery: String): Xq = {
    copy(
      __prolog = xquery
    )
  }

  def user(user: String, password: Option[String] = None): Xq = {
    copy(
      __auth = UserAndPass(Some(user), password.orElse(Some(user)))
    )
  }

  def code(xquery: String): Xq = {
    copy(
      __code = xquery
    )
  }

  /** construct a query that contains the prolog, code and assertions
   * after the last assertion, all output is returned */
  protected def constructXQuery(
                             __prolog: String = _prolog,
                             __auth: UserAndPass = _auth,
                             __throws: String = _throws,
                             __code: String = _code,
                             __assertions: Seq[XPathAssertion] = _assertions
                             ): String = {
    __prolog + "\n" +
    s"let $$output := " +
      (if (__auth.user.nonEmpty)
        s"system:as-user('${__auth.user.get}', ${if (__auth.user.get == "admin") "$magic:password" else s"'${__auth.pass.get}'"},"
       else "") +
      (if (__throws.nonEmpty) "try { " else "") +
      s"${__code}" +
      (if (__throws.nonEmpty) s"} catch ${__throws} { element threwException { '${__throws}' } }" else "") +
      ( if (__auth.user.nonEmpty) ")" else "") +
      "\nreturn (" + (
      if (__throws.nonEmpty) s"if ($$output instance of element(threwException)) then 1 else 0"
      else {
        __assertions.map { assertion: XPathAssertion =>
          s"if (${assertion.xpath}) then 1 else 0"
        }.mkString(",\n")
      }) +
      (if (__throws.nonEmpty || __assertions.nonEmpty) "," else "") + "\n$output\n)"
  }

  def go: Array[String] = {
    val xquery = constructXQuery()
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
    copy(
      __throws = exceptionType)
  }

  def assertEquals(value: String*): Xq = {
    copy(
      __assertions = _assertions ++ value.zipWithIndex.map { case (v:String, idx: Int) =>
        val indexString = if (value.length > 1) s"[${idx + 1}]" else ""
        XPathAssertion(s"$$output$indexString='$v'", s" output$indexString did not equal '$v'")
      }
    )
  }

  def assertXPath(xpath: String, clue: String = ""): Xq = {
    copy(
      __assertions = _assertions :+ XPathAssertion(xpath,
        if (clue.nonEmpty) clue else s" output did not conform to '$xpath'")
    )
  }

  def assertEquals[T : Numeric](value: T*): Xq = {
    copy(
      __assertions = _assertions ++ value.zipWithIndex.map { case (v:T, idx: Int) =>
        val indexString = if (value.length > 1) s"[${idx + 1}]" else ""
        XPathAssertion(s"$$output$indexString=$v", s" output$indexString did not equal $v")
      }
    )
  }

  def assertTrue: Xq = {
    copy(
      __assertions = _assertions :+ XPathAssertion("$output", s" output was not true()")
    )
  }

  def assertFalse: Xq = {
    copy(
      __assertions = _assertions :+ XPathAssertion("not($output)", s" output was not false()")
    )
  }

  def assertEmpty: Xq = {
    copy(
      __assertions = _assertions :+ XPathAssertion("empty($output)", s" output was not empty")
    )
  }

  def assertXmlEquals(xml: String*): Xq = {
    val xmlSequence = "(" + xml.mkString(",") +  ")"
    assertXPathEquals("$output", s" output did not equal $xmlSequence", xml :_*)
  }

  def assertXPathEquals(xpath: String, clue: String, xml: String*): Xq = {
    val xmlSequence = "(" + xml.mkString(",") +  ")"

    copy(
      __assertions = _assertions :+ XPathAssertion(s"empty(tcommon:deep-equal($xpath, $xmlSequence))", clue)
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

class XqRest(
              _code: String = "",
              _prolog: String = "",
              _throws: String = "",
              _assertions: Seq[XPathAssertion] = Seq(),
              _auth: UserAndPass = UserAndPass()
            ) extends Xq(_code, _prolog, _throws, _assertions, _auth) {
  override def copy(__code: String, __prolog: String, __throws: String, __assertions: Seq[XPathAssertion], __auth: UserAndPass): XqRest = {
    new XqRest(__code, __prolog, __throws, __assertions, __auth)
  }

  override def constructXQuery(__prolog: String, __auth: UserAndPass, __throws: String, __code: String, __assertions: Seq[XPathAssertion]): String = {
    super.constructXQuery(__prolog, UserAndPass(), __throws, __code, __assertions)
  }

  override def callXQuery(query: String): Array[String] = {
    val auth = (_auth.user.getOrElse("guest"), _auth.pass.getOrElse("guest"))

    val response = requests.get(restUri,
      params = Map("_query" -> query),
      auth = auth
    )
    val xml = XML.loadString(response.text())
    if (response.statusCode == 200) { // results
      xml.child.
        map { c =>
          if (c.label == "value") c.child.text
          else c.toString().trim }.
        filter { _.nonEmpty }
    }.toArray
    else { // should never get here...
      throw new RuntimeException("Error in XML processing via REST: " + xml.toString())
    }
  }
}

abstract class DbTest extends AnyFunSpec with BeforeAndAfterEach with BeforeAndAfterAll with XQueryCall {
  def xq(code: String): Xq = {
      new Xq(code, prolog)
    }

  def xqRest(code: String): XqRest = {
    new XqRest(code, prolog)
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
    val contentSource = Source.fromFile(localSource)
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
             firstParamIsContent: Boolean = false,
             as: String = "guest"
            ): Array[String] = {
    val content = if (firstParamIsContent) ("'" + localSource + "'") else readXmlFile(localSource)
    xq(s"""xmldb:store('$collection', '$resourceName', $content, '$dataType')""")
      .user(as)
      .go
  }

  /** Remove an arbitrary path from the db */
  def remove(collection: String, resourceName: String, as: String = "guest") = {
    xq(s"""xmldb:remove('$collection', '$resourceName')""")
      .user(as)
      .go
  }

  def setupCollection(base: String, collection: String,
                      owner: Option[String] = None,
                      group: Option[String] = None,
                      permissions: Option[String] = None) = {
    val changeOwner =
      if (owner.isDefined)
        s"""let $$change-owner := sm:chown(xs:anyURI('$base/$collection'), '${owner.get}')"""
      else ""
    val changeGroup =
      if (group.isDefined)
        s"""let $$change-group := sm:chgrp(xs:anyURI('$base/$collection'), '${group.get}')"""
      else ""
    val changePermissions =
      if (permissions.isDefined)
        s"""let $$change-permissions := sm:chmod(xs:anyURI('$base/$collection'), '${permissions.get}')"""
      else ""

    xq(
      s"""
         let $$create := xmldb:create-collection('$base', '$collection')
         $changeOwner
         $changeGroup
         $changePermissions
         return ()
      """)
      .user("admin")
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

  def teardownCollection(collectionName: String) = {
    xq(s"""if (xmldb:collection-available('$collectionName')) then xmldb:remove('$collectionName') else ()""")
      .user("admin")
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

  val restUri = s"http://localhost:${existPort}/exist/rest/db"

  val HTML5_SERIALIZATION = "xhtml"
  val XHTML_SERIALIZATION = "xhtml"
}