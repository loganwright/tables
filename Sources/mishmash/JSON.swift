import Foundation
//extension Decodable {
//    static func from(template: String) -> Self {
//        let filePath  = Bundle.main.path(
//            forResource: template,
//            ofType: "json"
//        )!
//        let data = NSData(contentsOfFile: filePath)!
//        return try! .decode(.init(data))
//    }
//}

extension String {
    var data: Data { Data(utf8) }
}
extension Data {
    var string: String? { String(data: self, encoding: .utf8) }
}

extension NSData {
    var ns: Data { Data(self) }
}

extension JSON {
    static let emptyObj: JSON = .obj([:])
}

@dynamicMemberLookup
enum JSON: Codable, Equatable {
    case int(Int)
    case double(Double)
    case str(String)
    case bool(Bool)
    case null
    case array([JSON])
    case obj([String: JSON])

    init(from decoder: Decoder) throws {
        if let val = try? Int.init(from: decoder) {
            self = .int(val)
        } else if let val = try? Double(from: decoder) {
            self = .double(val)
        } else if let val = try? String(from: decoder) {
            self = .str(val)
        } else if let val = try? Bool(from: decoder) {
            self = .bool(val)
        } else if let isNil = try? decoder.singleValueContainer().decodeNil(), isNil {
            self = .null
        } else if let val = try? [String: JSON](from: decoder) {
            self = .obj(val)
        } else if let val = try? [JSON](from: decoder) {
            self = .array(val)
        } else {
            throw "unexpected type, can't decode"
        }
    }

    func encode(to encoder: Swift.Encoder) throws {
        switch self {
        case .int(let val):
            try val.encode(to: encoder)
        case .double(let val):
            try val.encode(to: encoder)
        case .str(let val):
            try val.encode(to: encoder)
        case .bool(let val):
            try val.encode(to: encoder)
        case .obj(let val):
            try val.encode(to: encoder)
        case .array(let val):
            try val.encode(to: encoder)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

enum JSONAccessor {
    case total
}

extension JSON {
    subscript(dynamicMember key: String) -> JSON? {
        get {
            return self[key]
        }
        set {
            self[key] = newValue
        }
    }

    subscript<C: Codable>(dynamicMember key: String) -> C? {
        get {
            do {
                print("!!!!! NEED TO ADD BACK LOGS")
                return try self[key].flatMap(C.init)
            } catch {
                print("!!!!! NEED TO ADD BACK LOGS: \(error)")
//                Log.error(error)
                return nil
            }
        }
        set {
            self[key] = newValue?.json
        }
    }

    subscript(key: String) -> JSON? {
        get {
            switch key {
            case "first": return array?.first ?? obj?[key]
            case "last": return array?.last ?? obj?[key]
            default:
                return obj?[key] ?? Int(key).flatMap { self[$0] }
            }
        }
        set {
            guard var obj = self.obj else { fatalError("can't set non object type json: \(self)") }
            obj[key] = newValue
            self = .obj(obj)
        }
    }
    subscript(idx: Int) -> JSON? {
        return array?[idx] ?? obj?["\(idx)"]
    }

    /// not very advanced, but supports really bassic `.` path access
    subscript(path: [String]) -> JSON? {
        var obj: JSON? = self
        path.forEach { key in
            if let idx = Int(key) {
                obj = obj?[idx]
            } else {
                obj = obj?[key]
            }
        }
        return obj
    }

    ////// not very advanced, but supports really bassic `.` path access
    subscript(path: String...) -> JSON? {
        return self[path]
    }
}

// MARK: Codable Interops

extension Decodable {
    init(json: JSON) throws {
        let raw = json.encoded()
        try self.init(jsonData: raw)
    }
}

extension Encodable {
    var json: JSON {
        try! JSON(jsonData: self.encoded())
    }
}

@propertyWrapper
struct FuzzyBool: Codable {
    var wrappedValue: Bool

    init(wrappedValue value: Bool) {
        self.wrappedValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self.init(wrappedValue: bool)
        } else if let int = try? container.decode(Int.self), [0,1].contains(int) {
            self.init(wrappedValue: int == 1)
        } else if let str = try? container.decode(String.self), let bool = Bool(str) {
            self.init(wrappedValue: bool)
        } else {
            throw "unable to make bool: \(container)"
        }
    }

    func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension Encodable where Self: Decodable {
    func map<C: Codable>(to type: C.Type = C.self) -> C {
        do {

            print("!!!!! NEED TO ADD BACK LOGS")
            return try C.init(json: self.json)
        } catch {
            print("!!!!! NEED TO ADD BACK LOGS: \(error)")
//            Log.error(error)
            fatalError()
        }
    }
}

// MARK: Typing

extension JSON {
    var int: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d): return Int(d)
        case .str(let s): return Int(s)
        default: return nil
        }
    }

    var float: Float? {
        double.flatMap(Float.init)
    }

    var double: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i): return Double(i)
        case .str(let s): return Double(s)
        default: return nil
        }
    }
    var string: String? {
        switch self {
        case .int(let val): return val.description
        case .double(let val): return val.description
        case .str(let val): return val
        default: return nil
        }
    }
    var bool: Bool? {
        switch self {
        case .bool(let b):
            return b
        case .int(let i) where i == 0 || i == 1:
            return i == 1
        case .double(let d) where d == 0 || d == 1:
            return d == 1
        case .str(let s):
            return Bool(s.lowercased())
        case .array(let arr) where arr.count == 1:
            /// in some places (consent test) we get `["False"]` for example
            return arr[0].bool
        default:
            return nil
        }
    }
    var null: Bool {
        guard case .null = self else { return false }
        return true
    }
    var obj: [String: JSON]? {
        guard case .obj(let v) = self else { return nil }
        return v
    }
    var array: [JSON]? {
        guard case .array(let v) = self else { return nil }
        return v
    }

    var any: AnyObject? {
        switch self {
        case .int(let val):
            return val as AnyObject
        case .double(let val):
            return val as AnyObject
        case .str(let val):
            return val as AnyObject
        case .bool(let val):
            return val as AnyObject
        case .obj(let val):
            var any: [String: Any] = [:]
            val.forEach { k, v in
                any[k] = v.any
            }
            return any as AnyObject
        case .array(let val):
            return val.map { $0.any ?? NSNull() } as AnyObject
        case .null:
            return nil
        }
    }
}

// MARK: Comparable

extension JSON: Comparable {
    static func < (lhs: JSON, rhs: JSON) -> Bool {
        switch lhs {
        case .int(let val):
            guard
                let r = rhs.int
                else { fatalError("can't compare int w non-int") }
            return val < r
        case .double(let val):
            guard
                let r = rhs.double
                else { fatalError("can't compare double w non-double") }
            return val < r
        case .str(let val):
            guard
                let r = rhs.string
                else { fatalError("can't compare string w non-string") }
            return val < r
        default:
            fatalError("can not compare invalid values: \(lhs) < \(rhs)")
        }
    }
}

