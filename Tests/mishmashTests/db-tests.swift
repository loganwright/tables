import XCTest
@testable import mishmash

final class DBTests: XCTestCase {
    func testRequestBuasdfilder() {
        
    }
}

struct Weapon: Schema {
    var id = IDColumn<Int>()
}

struct Food: Schema {
    var id = IDColumn<Int>()
    var health = CCColumn<Int>("health")
}

struct Hero: Schema {
    // id
    var id = IDColumn<String>("id")
    // basics
    var name = CCColumn<String>("name")
    var age = CCColumn<Int>("age")
    // nullable
    var nickname = CCColumn<String?>("nickname")

    // relations
    var weapon = CCColumn<Weapon?>("weapon", \.id)
}
