import Foundation

public let IS_TESTING = NSClassFromString("XCTest") != nil

public let IS_SIMULATOR: Bool = {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
}()

public let IS_PRODUCTION: Bool = {
    #if DEBUG
    return false
    #else
    return true
    #endif
}()
