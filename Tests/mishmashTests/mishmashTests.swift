import XCTest
@testable import mishmash

final class MishMashTests: XCTestCase {
    func testMishMash() {
        let atLeastItsNot = "hodgepodge"
        XCTAssert(!Mish.mash.contains(atLeastItsNot))
    }

    func testGo() {
//        go()
    }

    func testKeyPaths() {
        struct Ob {
            let a: String
        }
        
    }
}

struct Router {
    let get: PathBuilder = PathBuilder()
}

@propertyWrapper
@dynamicMemberLookup
struct PathBuilder {
    var projectedValue: PathBuilder { self }
    let wrappedValue: Int = 0
    subscript(dynamicMember key: String) -> Self {
        return self
    }

    func callAsFunction(_ foo: () -> Void) {

    }
}


//router.get.path.$goes.here
func routerapitest() {
    let router = Router()

    router.get.users.$id.favorites {

    }
}
