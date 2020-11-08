import Foundation

typealias NetworkCompletion = (Result<NetworkResponse, Error>) -> Void

struct NetworkResponse {
    let http: HTTPURLResponse
    let body: Data?

    var anyobj: AnyObject? {
        do {
            return try body.flatMap {
                try JSONSerialization.jsonObject(with: $0, options: [])
            } as AnyObject?
        } catch {
            Log.error("failed to serialize object: \(error) body: \(body?.string ?? "<>")")
            return nil
        }
    }
}

extension NetworkResponse {
    var json: JSON? {
        body.flatMap(\.json)
    }
}

extension NetworkResponse: CustomStringConvertible {
    var description: String {
        let msg = body.flatMap { String(bytes: $0, encoding: .utf8) } ?? "<no-body>"
        return """
        NetWorkResponse:
        \(http)

        Body:
        \(msg)
        """
    }
}

extension Result where Success == NetworkResponse, Failure == Error {
    var resp: NetworkResponse? {
        guard case .success(let resp) = self else { return nil }
        return resp
    }

    init(_ response: HTTPURLResponse?, body: Data?, error: Error?) {
        guard let http = response, http.isSuccessResponse else {
            let desc = error ?? body.flatMap(\.string) ?? "no error or response received"
            let err = NSError(domain: NSURLErrorDomain,
                              code: response?.statusCode ?? -1,
                              userInfo: [NSLocalizedDescriptionKey: desc])
            self = .failure(err)
            return
        }

        self = .success(.init(http: http, body: body))
    }
}

func makeQueryString(parameters: [String: Any]) -> String {
    var params: [(key: String, val: Any)] = []
    parameters.forEach { k, v in
        if let array = v as? [Any] {
            array.forEach { v in
                params.append((k, v))
            }
        } else {
            params.append((k, v))
        }
    }
    let query = params.map { param in param.key + "=\(param.val)" }
        .sorted(by: <)
        .joined(separator: "&")
    // todo: fallback to percent fail onto original query
    // verify ideal behavior
    return query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        ?? query
}

extension Dictionary where Key == String, Value == String {
    fileprivate func combined(with rhs: Dictionary?, overwrite: Bool = true) -> Dictionary {
        var combo = self
        rhs?.forEach { k, v in
            guard overwrite || combo[k] == nil else { return }
            combo[k] = v
        }
        return combo
    }
}

extension URLRequest {
    mutating func setBody(json: Data) {
        httpBody = json
        setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
}

extension NSError {
    static var networkUnavailable: NSError {
        NSError(
            domain: NSURLErrorDomain,
            code: NoNetworkErrorCode,
            userInfo: nil
        )
    }
}

extension HTTPURLResponse {
    /// set by the registration and metadata server
    var statusMessage: String? {
        return allHeaderFields["StatusMessage"] as? String
    }

    /// the standardized message associated with the given status code, localized
    var standardizedLocalizedStatusMessage: String {
        return HTTPURLResponse.localizedString(forStatusCode: statusCode)
    }

    fileprivate var isSuccessResponse: Bool {
        return (200...299).contains(statusCode) || statusCode == 0
    }
}

extension String {
    var nserr: NSError {
        return (self as Error) as NSError
    }
}

extension Encodable {
    var anyobj: AnyObject? {
        /// we could probably take some of this out, it was originally stitching for other systems to transition with
        let data = try? JSONEncoder().encode(self)
        let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0, options: []) }
        return json as AnyObject?
    }
}

// MARK: Result

extension Result where Success == NetworkResponse {
    func unwrap<D: Decodable>(as: D.Type) throws -> D {
        switch self {
        case .success(let resp):
            guard let body = resp.body
                else { throw "expected data on response: \(resp.http)" }
            return try D.decode(body)
        case .failure(let error):
            throw error
        }
    }

    func map<D: Decodable>(to completion: @escaping (Result<D, Error>) -> Void) {
        do {
            let ob = try self.unwrap(as: D.self)
            completion(.success(ob))
        } catch {
            completion(.failure(error))
        }
    }
}

// MARK: Decoding

extension Decodable {
    static func decode(_ resp: NetworkResponse) throws -> Self {
        guard let body = resp.body else { throw "expected to find body to decode" }
        return try decode(body)
    }
}

