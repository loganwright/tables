import Foundation

extension JSON {
    init(fuzzy: Any) throws {
        if let data = fuzzy as? Data {
            self = try JSON(jsonData: data)
        } else if let e = fuzzy as? Encodable {
            self = e.json
        } else if let nsobj = fuzzy as? NSObject {
            self = try JSON(nsobj: nsobj)
        } else {
            throw "unknown type: \(type(of: fuzzy))"
        }
    }

    init(nsobj: NSObject) throws {
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

            self = serialized.json
        }
    }
}

extension JSON {
    init(_ kvp: KeyValuePairs<String, Any>) {
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
