import Foundation

extension JSON {
    public init(fuzzy: Any) throws {
        if let data = fuzzy as? Data {
            self = try JSON.decode(data)
        } else if let e = fuzzy as? Encodable {
            self = try e.toJson()
        } else if let nsobj = fuzzy as? NSObject {
            self = try JSON(nsobj: nsobj)
        } else {
            throw "unknown type: \(type(of: fuzzy))"
        }
    }

    public init(nsobj: NSObject) throws {
        if let dict = nsobj as? NSDictionary {
            var obj = JSON.emptyObj
            try dict.forEach { k, v in
                obj["\(k)"] = try .init(fuzzy: v)
            }
            self = obj
        } else if let array = nsobj as? NSArray {
            self = try .array(array.map(JSON.init(fuzzy:)))
        } else {
            let serialized = try! JSONSerialization.data(
                withJSONObject: nsobj,
                options: [.fragmentsAllowed])

            self = try serialized.toJson()
        }
    }
}

extension JSON {
    public init(_ kvp: KeyValuePairs<String, Any>) {
        var ob = JSON.emptyObj
        kvp.forEach { k, v in
            do {
                ob[k] = try JSON(fuzzy: v)
            } catch {
                Log.error(error)
                Log.info("unable to serialize: \(type(of: v)): \(v)")
            }
        }
        self = ob
    }
}
