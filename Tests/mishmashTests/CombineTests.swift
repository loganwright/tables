import XCTest

final class AlwaysTests: XCTestCase {
    func testItEmitsASingleValue() {
//        var output: [Int] = []
//        //    _ = Always(1).sink { print($0); output.append($0) }
//        let two = Always(2)
//        //    DispatchQueue.global().async {
//        //        two.sink { print("a: \($0)");
//        //            output.append($0) }
//        //    }
//        //    Always(1).
//        Always(1).combineLatest(two).sink { print("b: \($0)");
//            output.append($0.0); output.append($0.1) }
//        print(output)
//        XCTAssertEqual(output, [1])
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
