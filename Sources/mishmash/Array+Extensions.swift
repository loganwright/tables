import Foundation

extension Array {
    var lastIdx: Int {
        return count - 1
    }
}

extension Array {
    func collectFirst(_ amount: Int) -> Array {
        assert(0...count ~= amount)
        var collected = Array()
        while collected.count < amount {
            collected.append(self[collected.count])
        }
        return collected
    }
}

extension Array {
    subscript(safe idx: Int) -> Element? {
        guard 0 <= idx, idx < count else { return nil }
        return self[idx]
    }
}
