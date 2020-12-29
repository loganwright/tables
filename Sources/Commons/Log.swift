public struct Log {
    public static func info(file: String = #file, line: Int = #line, _ msg: String) {
        let file = file.components(separatedBy: "/").last ?? "<>"
        print("\(file):\(line) - \(msg)")
    }
    public static func warn(file: String = #file, line: Int = #line, _ msg: String) {
        let file = file.components(separatedBy: "/").last ?? "<>"
        print("*** WARNING ***")
        print("\(file):\(line) - \(msg)")
    }
    public static func error(file: String = #file, line: Int = #line, _ err: Error) {
        let file = file.components(separatedBy: "/").last ?? "<>"
        print("!!*** ERROR ***!!")
        print("*****************")
        print("\(file):\(line) - \(err.display)")
    }

    // MARK: Logs


    /// storing logs for easier testng
    static var _testable_logs: [String] = []
    #if DEBUG
    private static func print(_ str: String) {
        _testable_logs.append(str)
        Swift.print(str)
    }
    #else
    private static func print(_: String) {}
    #endif
}

import Foundation

extension Error {
    public var display: String {
        let ns = self as NSError
        let _localized = ns.userInfo[NSLocalizedDescriptionKey]
        if let nested = _localized as? NSError {
            return nested.display
        } else if let string = _localized as? String {
            let raw = Data(string.utf8)
            if let json = try? JSON.decode(raw) {
                return json.message?.string ?? "\(json)"
            } else {
                return ns.domain + ":\n" + "\(ns.code) - " + string
            }
        } else {
            return "\(self)"
        }
    }
}
