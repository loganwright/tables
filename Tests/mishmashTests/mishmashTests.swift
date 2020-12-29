import XCTest
@testable import Commons

final class MishMashTests: XCTestCase {
    func testMishMash() {
        let atLeastItsNot = "hodgepodge"
        XCTAssertFalse("mishmash".contains(atLeastItsNot))
    }

    func testObjCSet() {
        let ob = Ob()
        ob.a = NSNumber(121)
        XCTAssertNil(ob.b)
        ob.b = NSNumber(322)
        XCTAssertEqual(ob.a?.intValue, 121)
        XCTAssertEqual(ob.b?.intValue, 322)
    }
}

class Ob {

}

extension Ob {
    static var a_key = UInt8(0)
    static var b_key = UInt8(0)

    var a: NSNumber? {
        get {
            objc_getAssociatedObject(
                self,
                &Ob.a_key
            ) as? NSNumber
        }

        set {
            objc_setAssociatedObject(
                self,
                &Ob.a_key,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }

    var b: NSNumber? {
        get {
            objc_getAssociatedObject(
                self,
                &Ob.b_key
            ) as? NSNumber
        }

        set {
            objc_setAssociatedObject(
                self,
                &Ob.b_key,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }
}

