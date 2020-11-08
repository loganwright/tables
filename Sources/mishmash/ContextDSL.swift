import Foundation

protocol DSLContext {
    func value(at path: [String]) -> JSON?
}

/**

 This class is meant to facilitate find and replace using a simple custom dsl
 of an opening/closing token, for example, if our token is `~`

 Hi ~user.name~,

 You got a score of -activity-id.total~ on the last activity.
 (if multiple) ~activity-id.0.total~; (otherwise will default last

 You're scheduled for ~user.notifications~
 */
typealias ContextEntryDSL = ModuleContextDSL
struct ModuleContextDSL {
    static let `default` = ModuleContextDSL()
    /// signifies open character
    let open: String
    let close: String
    let pattern: String
    let regex: NSRegularExpression

    /// initialize with a custom open or close token to identify items to be replaced in the dsl
    init(open: String = "~", close: String = "~") {
        self.open = open
        self.close = close

        // this is pretty fuzzy just for now since we only have one case
        let _open: String
        if open == "{" { _open = "\\" + open }
        else { _open = open }
        let _close: String
        if close == "}" { _close = "\\" + close }
        else { _close = close }


        let pattern = "\(_open)(.*?)\(_close)"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        self.pattern = pattern
        self.regex = regex
    }

    /// hydrate a current screen, using a given context as a source for replacement values
    func hydrate(_ str: String, with context: DSLContext) -> String {
        let entries = self.entries(in: str).unique

        var updates: [String: String] = [:]
        entries.forEach { entry in
            let path = makePath(from: entry)
            let val = context.value(at: path)
            if val == nil { Log.warn("no value found for module entry: \(entry)") }
            updates[entry] = val?.string ?? ""
        }

        return hydrate(str, replacements: updates)
    }

    func makePath(from entry: String) -> [String] {
        var entry = entry
        if entry.hasPrefix(open) {
            entry = String(entry.dropFirst(open.count))
        }
        if entry.hasSuffix(close) {
            entry = String(entry.dropLast(close.count))
        }

        return entry.components(separatedBy: ".")
    }

    struct Entry {
        let text: String
        let range: Range<String.Index>
    }

    private func entries(in text: String) -> [String] {
        var results = [String]()
        // https://stackoverflow.com/a/35996129/2611971
        regex.enumerateMatches(in: text,
                               options: [], range: NSMakeRange(0, text.count)) { result, flags, stop in
            if let r = result?.range(at: 1), let range = Range(r, in: text) {
                results.append(String(text[range]))
            }
        }
        return results
    }

    /**
     at this point, we have a text string,
     */
    private func hydrate(_ text: String, replacements: [String: String]) -> String {
        var text = text
        replacements.forEach { entry, replacement in
            let complete = "\(open)\(entry)\(close)"
            text = text.replacingOccurrences(of: complete, with: replacement)
        }
        return text
    }
}

extension Array where Element == String {
    fileprivate var unique: Array {
        var arr = Array()
        for next in self where !arr.contains(next) {
            arr.append(next)
        }
        return arr
    }
}
