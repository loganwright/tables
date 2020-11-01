extension Result {
    var isSuccess: Bool {
        guard case .success = self else { return false }
        return true
    }

    var value: Success? {
        guard case .success(let val) = self else { return nil }
        return val
    }

    var error: Error? {
        guard case .failure(let err) = self else { return nil }
        return err
    }
}
