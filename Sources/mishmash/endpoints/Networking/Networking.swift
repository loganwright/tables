import Foundation

/// whether the network is available, not whether or not to test
var UNSAFE_TESTABLE_NETWORK_IS_AVAILABLE: Bool? = nil

let NoNetworkErrorCode = NSURLErrorNotConnectedToInternet

final class Network {
    static var isAvailable: Bool {
        return UNSAFE_TESTABLE_NETWORK_IS_AVAILABLE
            ?? shared.reachability?.isReachable
            ?? false
    }

    private static let shared = Network()
    private let reachability = Reachability()
    private init() {
        // does this have to be on? or will it check each time `isReachable`
        try? reachability?.startNotifier()
    }
}
