import Foundation

struct Version: Codable, Equatable {
    /// I saw some versions like `v1`, just to preserve whatever we get
    fileprivate let leading: String

    let major: Int
    let minor: Int?
    let patch: Int?

    var string: String {
        var version = "\(major)"
        if let minor = minor {
            version += ".\(minor)"
            if let patch = patch {
                version += ".\(patch)"
            }
        } else if let _ = patch {
            fatalError("shouldn't have patch w/o minor")
        }
        return leading + version
    }

    init(tag: String = "", major: Int, minor: Int? = nil, patch: Int? = nil) {
        self.leading = tag
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        try self.init(from: raw)
    }

    init(from raw: String) throws {
        let versionCharacters = CharacterSet(charactersIn: "0123456789.")
        let comps = raw
            .trimmingCharacters(in: versionCharacters.inverted)
            .split(separator: ".")
            .map(String.init)
        guard (1...3) ~= comps.count else { throw "unexpected version string: \(raw)" }
        guard let major = comps[safe: 0].flatMap(Int.init) else { throw "at least major required" }
        self.major = major
        self.minor = comps[safe: 1].flatMap(Int.init)
        self.patch = comps[safe: 2].flatMap(Int.init)
        self.leading = raw.prefix(untilFirstIn: versionCharacters)
    }

    func encode(to encoder: Swift.Encoder) throws {
        try string.encode(to: encoder)
    }
}

extension Version: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        guard lhs.major == rhs.major else { return lhs.major < rhs.major }
        let lmin = lhs.minor ?? 0
        let rmin = rhs.minor ?? 0
        guard lmin == rmin else { return lmin < rmin }
        let lpatch = lhs.patch ?? 0
        let rpatch = rhs.patch ?? 0
        return lpatch < rpatch
    }
    static func <= (lhs: Self, rhs: Self) -> Bool {
        return lhs < rhs || lhs == rhs
    }
    static func >= (lhs: Self, rhs: Self) -> Bool {
        return lhs > rhs || lhs == rhs
    }
    static func > (lhs: Self, rhs: Self) -> Bool {
        if lhs < rhs || lhs == rhs { return false }
        return true
    }
}

extension Version: CustomStringConvertible {
    var description: String { string }
}

extension String {
    var version: Version {
        return try! .init(from: self)
    }

    /// only for use internally to version, is NOT tested outside of that, maybe works, test if need it
    fileprivate func prefix(untilFirstIn set: CharacterSet) -> String {
        guard let match = scalars.firstIndex(where: set.contains) else { return "" }
        let prefix = scalars[0..<match]
        let view = UnicodeScalarView(prefix)
        return String(view)
    }
}

extension String {
    var scalars: [Unicode.Scalar] { Array(unicodeScalars) }
    var chars: [Character] { Array(self) }
}
