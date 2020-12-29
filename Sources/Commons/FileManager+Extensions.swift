import Foundation

extension FileManager {
    public var documentsDir: URL {
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
    }

    public var cachesDir: URL {
        return FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
    }
}
