import XCTest
@testable import mishmash

final class DBTests: XCTestCase {
    let sql = SQLManager.unsafe_testable

    func testExtractProperties() {
        let properties = Weapon.unsafe_getProperties()
        let columns = properties.compactMap { $0.val as? SQLColumn }
        XCTAssertEqual(properties.count, 2)
        XCTAssertEqual(properties.count, columns.count)
        XCTAssert(columns.map(\.key).contains("id"))
        XCTAssert(columns.map(\.key).contains("power"))
    }

    func testIncompatiblePropertyWarn() {
        struct Foo: Schema {
            var id = IDColumn<Int>()
            var ohnooo = "that's not right"
        }

        /// I think we should probably throw or exit on incompatible properties,
        /// but right now just warning
        let _ = Foo.unsafe_getColumns()
        XCTAssert(Log._testable_logs.contains(where: { $0.contains("incompatible schema property") }))
        XCTAssert(Log._testable_logs.contains(where: { $0.contains("\(Foo.self)") }))
    }
}

struct Weapon: Schema {
    var id = IDColumn<Int>()
    var power = CCColumn<Int>("power")
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
