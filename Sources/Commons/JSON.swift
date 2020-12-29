import Foundation

extension String {
    public var data: Data { Data(utf8) }
}
extension Data {
    public var string: String? { String(data: self, encoding: .utf8) }
}

extension JSON {
    public static let emptyObj: JSON = .obj([:])
}

@dynamicMemberLookup
public enum JSON: Codable, Equatable {
    case int(Int)
    case double(Double)
    case str(String)
    case bool(Bool)
    case null
    case array([JSON])
    case obj([String: JSON])

    public init(from decoder: Decoder) throws {
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

    public func encode(to encoder: Swift.Encoder) throws {
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

extension JSON {
    public subscript(dynamicMember key: String) -> JSON? {
        get {
            return self[key]
        }
        set {
            self[key] = newValue
        }
    }

    public subscript<C: Codable>(dynamicMember key: String) -> C? {
        get {
            do {
                return try self[key].flatMap(C.init)
            } catch {
                Log.error(error)
                return nil
            }
        }
        set {
            self[key] = newValue?.json
        }
    }

    public subscript(key: String) -> JSON? {
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

    public subscript(idx: Int) -> JSON? {
        return array?[idx] ?? obj?["\(idx)"]
    }

    /// not very advanced, but supports really bassic `.` path access
    public subscript(path: [String]) -> JSON? {
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
    public subscript(path: String...) -> JSON? {
        return self[path]
    }
}


// MARK: Codable Interops

extension Decodable {
    public init(json: JSON) throws {
        let raw = try json.encoded()
        self = try .decode(raw)
    }
}

extension Encodable {
    public var json: JSON? {
        do {
            return try toJson()
        } catch {
            Log.error(error)
            return nil
        }
    }
    public func toJson() throws -> JSON {
        switch self {
        case let s as String:
            return .str(s)
        case let d as Double:
            return .double(d)
        case let i as Int:
            return .int(i)
        case let b as Bool:
            return .bool(b)
        default:
            return try self.encoded().toJson()
        }
    }
}

extension Data {
    public var json: JSON? {
        do {
            return try toJson()
        } catch {
            Log.error(error)
            return nil
        }
    }

    public func toJson() throws -> JSON {
        try JSON.decode(self)
    }
}

// MARK: Typing

extension JSON {
    public var int: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d): return Int(d)
        case .str(let s): return Int(s)
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }

    public var float: Float? {
        double.flatMap(Float.init)
    }

    public var double: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i): return Double(i)
        case .str(let s): return Double(s)
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }
    public var string: String? {
        switch self {
        case .int(let val): return val.description
        case .double(let val): return val.description
        case .str(let val): return val
        case .bool(let val): return val.description
        case .array(let arr) where arr.count == 1: return arr[0].string
        default: return nil
        }
    }
    public var bool: Bool? {
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

    public var null: Bool {
        guard case .null = self else { return false }
        return true
    }

    public var obj: [String: JSON]? {
        guard case .obj(let v) = self else { return nil }
        return v
    }
    
    public var array: [JSON]? {
        guard case .array(let v) = self else { return nil }
        return v
    }

    public var any: AnyObject? {
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
    public static func < (lhs: JSON, rhs: JSON) -> Bool {
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

