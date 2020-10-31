import Foundation

extension Decodable {
    /// deprecate
    static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        print("deprecate")
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Self.self, from: data)
    }

    init(jsonData: Data) throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self = try decoder.decode(Self.self, from: jsonData)
    }
}

extension Encodable {
    func encoded(pretty: Bool = false) throws -> Data {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = .prettyPrinted
        }
        return try encoder.encode(self)
    }
}
