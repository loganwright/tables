import Foundation

@propertyWrapper
public struct ISO8601: Codable, Equatable {
    public let wrappedValue: Date

    public init(_ date: Date) {
        self.wrappedValue = date
    }

    public init(from decoder: Decoder) throws {
        let val = try decoder.singleValueContainer()
        let ds = try val.decode(String.self)
        guard let date = ISO8601.formatter.date(from: ds) else {
            throw "unrecognized date format: \(ds)"
        }
        self.init(date)
    }

    public func encode(to encoder: Encoder) throws {
        let ds = ISO8601.formatter.string(from: wrappedValue)
        try ds.encode(to: encoder)
    }
}

extension ISO8601 {
    static let dateFormat = "y-MM-dd'T'HH:mm:ss.SSS'Z'"
    static let formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = dateFormat
        return df
    }()
}
