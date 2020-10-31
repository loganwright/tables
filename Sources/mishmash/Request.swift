import Foundation

enum Method: String, Codable {
    case get = "get"
    case post = "post"
    case put = "put"
    case patch = "patch"
    case delete = "delete"
    case GET = "sadf"

    /// testing out alternative syntax, this is silly
    init(_ method: Method) {
        self = method
    }
}

/// done as a struct because we can use these keys
/// to bind additional functions without polluting with repeats
struct _Method {
    let _get = "get"
    let _post = "post"
    let _put = "put"
    let _patch = "patch"
    let _delete = "delete"
    let _GET = "get"

    static let shared = _Method()
    private init() {}
}

extension _Method {
    var custom: String { "custom" }
}

@_functionBuilder
struct RequestBuilder {
    static func buildBlock(_ method: Method = .get,
                           _ headers: Headers,
                           _ body: Body) -> Request {
        fatalError()
    }
}



struct Projection<T> {
    let key: String
}


@dynamicMemberLookup
struct Request {
    let headers: [String: String]
    let path: String
    let query: String?
    let body: Data?


//    static subscript(dynamicMember member: Method) -> Self.Type {
////         "Dynamic: \(member)"
//        fatalError()
//     }

    static subscript(dynamicMember member: KeyPath<_Method, String>) -> Self.Type {
//         "Dynamic: \(member)"
        fatalError()
     }
}

extension Request {
    init(@RequestBuilder _ builder: () -> Request) {
        self = builder()
    }


    init(@RequestBuilder _ builder: () -> Request, onError: (Error) -> Void, onSuccess: (Data) -> Void) {
        self = builder()
    }
}


protocol AttachableProperty {}

@dynamicMemberLookup
class old_Template<T> {
    var backing: [Any] = []
    subscript<U>(dynamicMember key: KeyPath<T, U>) -> U {
        fatalError()
    }
}

//func _propertyAttaching() {
//    let js = JSON.obj(["id": "1".json])
//    js.id
//    let kp = \Derpy.isDerp
////    let e = NSExpression(forKeyPath: kp)
////    let kpz = \Derpy.$isDerp
//
//    let foo = Template<Sleepy & Derpy>(.obj([:])).isDerp
//
//}

protocol PropertyTemplate {
    var id: String { get }
}

protocol AttachKeys {
    var id: String { get }
}

open class Keyyyys {
    static var shared: Self { print("FIX"); return Self.init() }
    required public init() {}

    var base: Int = 0
}

class One: Keyyyys {
    var id = "id"
}

//extension JSON {
//    subscript(dynamicMember key: KeyPath<AttachKeys>) -> String {
//        fatalError()
//    }
//}

extension KeyPath where Root: NSObject {
    fileprivate var unsafe_name: String {
        NSExpression(forKeyPath: self).keyPath
    }
}

fileprivate func _key() -> Never { fatalError() }

@objc class KeySet: NSObject {
    var id: String { _key() }
}

@dynamicMemberLookup
class KeyAggregator<T: NSObject> {
    private var backing: JSON
    init(_ backing: JSON) {
        self.backing = backing
    }
    subscript<C: Codable>(dynamicMember key: KeyPath<T, C>) -> C {
        get {
            let val = backing[key.unsafe_name] ?? .null
            return try! C(json: val)
        }
        set {
            backing[key.unsafe_name] = newValue.json
        }
    }
}

@propertyWrapper
struct Coding<T: Codable> {
    var wrappedValue: T! = nil
    let key: String
    init(key: String) {
        self.key = key
    }
}

struct Keyyer {
    let id = "id"
}

@dynamicMemberLookup
class Template<T> {
    typealias Keys = T
    private var backing: JSON
    init(_ backing: JSON) {
        self.backing = backing
    }


//    #if XCODE
    subscript<C: Codable>(dynamicMember key: KeyPath<T, C>) -> C {
//        fatalError()
        get {
//            Data(conte)
            let data = NSArchiver.archivedData(withRootObject: key)
            print(data)
            fatalError()
//            let val = backing[keyPath: key]
//            return try! C(json: val)
        }
        set {
            fatalError()
//            backing[keyPath: key] = newValue.json
        }
    }
//    #else
//    subscript<C: Codable>(dynamicMember key: String) -> C {
//        get {
//            let val = backing[key] ?? .null
//            return try! C(json: val)
//        }
//        set {
//            backing[key] = newValue.json
//        }
//    }
//    #endif
}

protocol Derpy: class {
    var isDerp: Bool { get set }
}
protocol Sleepy: class {
    var isSleepy: Bool { get set }
}

extension Sleepy {
    static var other: String { fatalError() }
    var another: String { fatalError() }

    var id: String { fatalError() }
}

//extension JSON {
//    subscript<R, V>(keyPath: KeyPath<R, V>) -> JSON? {
//        get {
//            fatalError()
//        }
//        set {
//            fatalError()
//        }
//    }
//}


@propertyWrapper
struct Attribute<T> {
    let key: String
    private var _wrappedValue: T? = nil
    var wrappedValue: T {
        get { _wrappedValue! }
        set { _wrappedValue = newValue }
    }

    var projectedValue: Self { self }

    init(wrappedValue: T, key: String) {
        self.key = key
        self._wrappedValue = nil
    }
}

//protocol Keyable {
//    static var template: Self { get }
//}
//
final class JSONKeys {
    @Attribute(key: "id") var id: String = ""
    @Attribute(key: "age") var age: Int = 0
//    init() {}
    static let template = JSONKeys()
}

extension JSON {
//    subscript<K: Keyable, C: Codable>(dynamicMember key: KeyPath<K, Attribute<C>>) -> C {
//        get {
//            let attribute = K.template[keyPath: key]
//            // bumpy for now, smooth out lataa
//            return try! C(json: self[attribute.key]!)
//        }
//        set {
//            let attribute = K.template[keyPath: key]
//            // bumpy for now, smooth out lataa
//            self[attribute.key] = newValue.json
//        }
//    }
    subscript<C: Codable>(dynamicMember key: KeyPath<JSONKeys, Attribute<C>>) -> C {
        get {
            let attribute = JSONKeys.template[keyPath: key]
            // bumpy for now, smooth out lataa
            return try! C(json: self[attribute.key]!)
        }
        set {
            let attribute = JSONKeys.template[keyPath: key]
            // bumpy for now, smooth out lataa
            self[attribute.key] = newValue.json
        }
    }
}

func propertyAttaching() {
    let kers = \JSONKeys.$age
    var blerb = JSON.emptyObj
    blerb.$id = "abc.123"
    blerb.$age = 14
    print("blerb: \(blerb.$id), \(blerb.$age)")
    let aggregatedKeysType = Template<Sleepy & Derpy>.Keys.self
    print(aggregatedKeysType)
    let mirrrrrr = Mirror(reflecting: aggregatedKeysType)
    print(mirrrrrr)

    let foo = Template<Sleepy & Derpy>(.obj([:])).another
    let js = JSON.obj(["id": "1".json])
//    js[keyPath: <#T##KeyPath<JSON, Value>#>]
//    let ka = KeyAggregator<KeySet>(js)
//    print(ka.id)

    let l = (\Sleepy.id) as AnyKeyPath
    let r = (\One.id) as AnyKeyPath
    print(js[keyPath: l])
    print(js[keyPath: r])
    js.id
    let a = \Derpy.isDerp
    let b = \Derpy.isDerp
    print("0 match: \(a == b)")
    let c = \One.id
    let d = \One.id
    print("1 match: \(c == d)")
    let e = \One.base
    let f = \Keyyyys.base
    print("2 match: \(e == f)")


    let _a = NSExpression(forKeyPath: a)
    let _c = NSExpression(forKeyPath: c)
    let _e = NSExpression(forKeyPath: e)
//    let kpz = \Derpy.$isDerp
//    let foo = Template<Sleepy & Derpy>(.obj([:])).isDerp

}

struct Entry {
    let key: String
    /// simple for now
    let val: String?
}

@_functionBuilder
struct Headers {

    init(@Headers _ builder: () -> [Entry]) {

    }
    static func buildBlock(_ entries: Entry...) -> [Entry] {
        fatalError()
    }
}


@_functionBuilder
struct Body {
    init(@Body _ builder: () -> Body) {

    }

//    init(_ builder: @escaping () -> Encodable) {
//
//    }

    static func buildBlock(_ entries: Encodable...) -> Body {
        fatalError()
    }
}

extension Encodable {
    func with(key: CodingKey) {

    }
}
struct Package: Codable {
    let id: String
}

func requestRun() {
//    Request
    let pack = Package(id: "asdf")

    let req = Request {
        Method(.GET)
        Headers {
            Entry(key: "Authorization", val: "Bearer token")
        }
        Body {
            pack
        }
    } onError: { error in
        print("error: \(error)")
    } onSuccess: { data in

    }

//    req.onError {
//
//    } .onSuccess {
//
//    }

//    Request.get.init {
//        Headers {
//            Entry(key: "Authorization", val: "Bearer token")
//        }
//    }
//    let a = Method.get
//    let _ = Request.build {
//        Method.GET
//    }
}

private let timeout = 30.0

//let endpoint: Endpoint
//
//let url: String
//let query: String
//let httpMethod: HTTPMethod
//private(set) var headers: [String: String]
//let body: Data?
//
//private var fired = false
//fileprivate(set) var middlewares: [ResponseMiddleware] = []
//
//private lazy var expandedUrl: URL = {

//protocol Endpoint {
//    /// the slug pointing to the endpoint, ie: `login`
//    var slug: String { get }
//    /// it's weird that endpoints only can have one associated http method
//    /// retrofitting here, rm when possible
//    var httpMethod: HTTPMethod { get }
//    /// the base url associated with the endpoint to which the slug should be appended
//    var baseUrl: String { get }
//    var defaultHeaders: [String: String] { get }
//    var rawValue: String { get }
//    static var identifier: String { get }
//}
//
//extension Endpoint {
//    var fullUrl: String {
//        return baseUrl.trailingSlash + slug
//    }
//}
