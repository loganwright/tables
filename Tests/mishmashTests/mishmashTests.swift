import XCTest
@testable import mishmash

final class MishMashTests: XCTestCase {
    func testMishMash() {
        let atLeastItsNot = "hodgepodge"
        XCTAssert(!Mish.mash.contains(atLeastItsNot))
    }
}

