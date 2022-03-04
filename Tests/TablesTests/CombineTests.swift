import XCTest
#if canImport(Combine)

import Combine
@testable import Commons
@testable import Endpoints

@available(iOS 13.0, *)
final class AlwaysTests: XCTestCase {
    func testItEmitsASingleValue() {
    }

    var cancellables = [AnyCancellable]()
    var published: JSON = [:] {
        didSet {
            XCTAssertEqual(published.id, "asfdlkjdsf")
            XCTAssertEqual(published.name, "flia")
            XCTAssertEqual(published.age, 234)
        }
    }

    func testBasePublisher() {
        Base("https://httpbin.org")
            .post(path: "post")
            .contentType("application/json")
            .accept("application/json")
            .header("Custom", "more")
            .body(id: "asfdlkjdsf", name: "flia", age: 234)
            .publisher
            .compactMap { $0.json?["json"] }
            .catch { _ in
                Just([:])}
            .assign(to: \.published, on: self)
            .store(in: &cancellables)
    }
}

#endif
