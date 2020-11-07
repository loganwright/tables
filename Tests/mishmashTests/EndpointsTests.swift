import Foundation
import XCTest
@testable import mishmash

extension mishmash.Host {
    static var httpbin: mishmash.Host { Host("https://httpbin.org") }
}

extension Endpoint {

}

class EndpointsTests: XCTestCase {
    func testNotes() {
        Log.warn("should change name? ambiguous w Foundation.Host")
    }

    func testOrdered() throws {
        let orderedTestCases = [
            testGet,
            testPost,
            statusCode,
            testBasicAuth,
            testSerialize
//            getUser,
//            getCheckIns,
//            refresh
        ]

        orderedTestCases.forEach(execute)
    }

    private func execute(_ op: (XCTestExpectation) -> Void) {
        let expectation = XCTestExpectation(description: "user operation")
        op(expectation)
        wait(for: [expectation], timeout: 20.0)
    }

    func testGet(_ group: XCTestExpectation) {
        log()
        // we get from the get endoint, yes
        Host.httpbin.get("get")
            .header("Content-Type", "application/json")
            .header("Accept", "application/json")
            .query(name: "flia", age: 234)
            .on.success { result in
                let json = result.json
                XCTAssertEqual(json?.args?.name?.string, "flia")
                XCTAssertEqual(json?.args?.age?.int, 234)
            }
            .on.success(group.fulfill)
            .on.error(fail)
            .send()
    }

    func testPost(_ group: XCTestExpectation) {
        log()
        // we get from the get endoint, yes
        Host.httpbin.post("post")
            .contentType("application/json")
            .accept("application/json")
            .body(name: "flia", age: 234)
            .on.success { result in
                /// the json is also nested under json lol, the httpbin api makes funny calls
                let json = result.json?["json"]
                XCTAssertEqual(json?.name?.string, "flia")
                XCTAssertEqual(json?.age?.int, 234)
            }
            .on.success(group.fulfill)
            .on.error(fail)
            .send()
    }

    func statusCode(_ group: XCTestExpectation) {
        Host.httpbin.get("status/{code}", code: 345)
            .header.contentType("application/json")
            .header.accept("application/json")
            .on.success { result in
                XCTFail("should fail w error code")
            }
            .on.error { error in
                let ns = error as NSError
                XCTAssertEqual(ns.code, 345)
                group.fulfill()
            }
            .send()
    }

    func testBasicAuth(_ group: XCTestExpectation) {
        Log.warn("don't in practice use password in a url")
        Host.httpbin
            .get("basic-auth/{user}/{pass}", user: "lorbo", pass: "1038s002")
            .accept("application/json")
            .on.result { _ in group.fulfill() }
            .send()
    }

    func testSerialize(_ group: XCTestExpectation) {
        let sql = SQLManager.shared
        let db = sql.testable_db
        sql.open {
            try sql.unsafe_fatal_dropAllTables()
        } .commitSynchronously()
        try! db.prepare {
            BasicUser.self
        }
        Log.warn("don't in practice use password in a url")
        Host("https://httpbin.org")
            .post(path: "post")
            .contentType("application/json")
            .accept("application/json")
            .header("Custom", "more")
            .body(id: "asfdlkjdsf", name: "flia", age: 234)
            .on.success { resp in
                /// json is nested key in http bin :/
                let json = resp.json?["json"]?.obj ?? [:]
                let user = Ref<BasicUser>(json, db)
                try! user.save()
                XCTAssertEqual(user.id, "asfdlkjdsf")
                XCTAssertEqual(user.name, "flia")
                XCTAssertEqual(user.age, 234)
                group.fulfill()
            }
            .on.error(fail)
            .send()
    }


    func fail(_ error: Error) {
        XCTFail("error: \(error)")
    }

    func log(_ desc: String = #function) {
        Log.info("testing: \(desc)")
    }
}

extension EP {
    var testPost: EP { "post" }
}

struct BasicUser: Schema {
    let id = PrimaryKey<String>()
    let name = Column<String>()
    let age = Column<Int>()
}

////import SQKit
//

class TypedOn<S: Schema> {
    let on: OnBuilder
    init(_ on: OnBuilder) {
        self.on = on
    }
    func success(_ success: @escaping (Ref<S>) -> Void) -> mishmash.Host {
        return on.success { resp in
//            let nodb = Ref<S>(resp.json!.obj!, nil)
            fatalError()
//            success(nodb)
        }
    }
 }

extension OnBuilder {
    func typed<S: Schema>(_ schema: S.Type) -> TypedOn<S> {
        fatalError()
    }

//    func callAsFunction(_ db: Any) {
//        fatalError()
////        return SQLModelBuilder(host)
//    }
}
//
////@dynamicCallable
//class SQLModelBuilder {
//    private let host: mishmash.Host
//
//    fileprivate init(_ host: mishmash.Host) {
//        self.host = host
//    }
//
//    func make(_ schema: Schema) -> mishmash.Host {
//        fatalError()
//    }
//}
