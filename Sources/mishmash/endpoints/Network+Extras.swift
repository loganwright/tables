import Foundation

/// saving for later use
fileprivate func makejson(with obj: [String: Any]) throws -> Data {
    do {
        return try JSONSerialization.data(withJSONObject: obj, options: [])
    } catch {
        Log.error("failed to serialize json object \(obj)")
        throw error
    }
}

fileprivate func makeobj(with json: Data) throws -> [String: Any] {
    let raw = try JSONSerialization.jsonObject(with: json, options: [])
    if let obj = raw as? [String: Any] { return obj }
    throw "unable to convert json data to expected object type \([String: Any].self)"
}
