package org.opensiddur

import org.scalatest.BeforeAndAfter
import org.scalatest.funspec.AnyFunSpec

class DbTest extends AnyFunSpec with BeforeAndAfter {
  before {
    print("Before")
  }

  after {
    print("After")
  }

  it("should do something") {
    assert(true)
  }

  it("should fail") {
    assert(false)
  }
}
