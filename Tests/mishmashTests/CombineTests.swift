import XCTest
@testable import mishmash

final class AlwaysTests: XCTestCase {
    func testItEmitsASingleValue() {
    }

    var cancellables = [AnyCancellable]()
    var published: JSON = .emptyObj {
        didSet {
            XCTAssertEqual(published.id, "asfdlkjdsf")
            XCTAssertEqual(published.name, "flia")
            XCTAssertEqual(published.age, 234)
        }
    }

    func testHostPublisher() {
        Host("https://httpbin.org")
            .post(path: "post")
            .contentType("application/json")
            .accept("application/json")
            .header("Custom", "more")
            .body(id: "asfdlkjdsf", name: "flia", age: 234)
            .publisher
            .compactMap { $0.json?["json"] }
            .catch { _ in
                Just(JSON.emptyObj)}
            .assign(to: \.published, on: self)
            .store(in: &cancellables)
    }
}
import Combine
