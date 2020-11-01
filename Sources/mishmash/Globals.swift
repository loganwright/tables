import Foundation

let IS_TESTING = NSClassFromString("XCTest") != nil

let IS_SIMULATOR: Bool = {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
}()

let IS_PRODUCTION: Bool = {
    #if DEBUG
    return false
    #else
    return true
    #endif
}()
