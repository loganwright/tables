import Foundation

@dynamicMemberLookup
class Host {
    private(set) var baseUrl: String
    fileprivate var _method: HTTPMethod = .get
    fileprivate var _path: String = ""
    fileprivate var _headers: [String: String] = [:]
    fileprivate var _body: JSON? = nil

    // additional attributes
    private var _timeout: TimeInterval = 30.0
    private lazy var session: URLSession = URLSession(configuration: .default)

    init(_ url: String) {
        self.baseUrl = url
    }

    // MARK: PathBuilder

    /// add keys to EP in an extension to support
    subscript(dynamicMember key: KeyPath<EP, EP>) -> PathBuilder {
        let ep = EP("")[keyPath: key]
        _path = ep.stringValue
        let builder = PathBuilder(self, startingPath: _path)
        return builder
    }

    /// get, post, put, patch, delete
    subscript(dynamicMember key: KeyPath<PathBuilder, HTTPMethod>) -> PathBuilder {
        let builder = PathBuilder(self)
        self._method = builder[keyPath: key]
        return builder
    }

    /// get, post, put, patch, delete
    subscript(dynamicMember key: KeyPath<PathBuilder, HTTPMethod>) -> Self {
        let builder = PathBuilder(self)
        self._method = builder[keyPath: key]
        return self
    }

    fileprivate func set(path: String) -> Self {
        self._path = path
        return self
    }

    // MARK: HeadersBuilder

    var header: HeadersBuilder { HeadersBuilder(self) }

    fileprivate func set(header: String, _ v: String) -> Self {
        self._headers[header] = v
        return self
    }

    subscript(dynamicMember key: KeyPath<HeaderKey, String>) -> HeadersBuilderExistingKey {
        let headerKey = HeaderKey(stringLiteral: "")[keyPath: key]
        return .init(self, key: headerKey)
    }

    // MARK: BodyBuilder

    var query: BodyBuilder {
        assert(_method == .get, "query only allowed on get requests")
        return BodyBuilder(self)
    }

    var body: BodyBuilder { BodyBuilder(self) }

    fileprivate func set(body: JSON) -> Self {
        assert(self._body == nil)
        self._body = body
        return self
    }

    // MARK: Handlers

    /// idk if I like this syntax or the other
    var on: OnBuilder { OnBuilder(self) }

    func on(success: @escaping () -> Void) -> Self {
        middleware(BasicHandler(onSuccess: success))
    }

    func on(success: @escaping (NetworkResponse) -> Void) -> Self {
        middleware(BasicHandler(onSuccess: success))
    }

    func on<D: Decodable>(success: @escaping (D) -> Void) -> Self {
        middleware(BasicHandler(onSuccess: success))
    }

    func on(error: @escaping (Error) -> Void) -> Self {
        middleware(BasicHandler(onError: error))
    }

    func on(result: @escaping (Result<NetworkResponse, Error>) -> Void) -> Self {
        middleware(BasicHandler(basic: result))
    }

    // MARK: Middleware

    private var middlewares: [Middleware] = []

    enum MiddlewareInsert {
        case front
        case back
    }

    func middleware(_ middleware: Middleware, to: MiddlewareInsert = .back) -> Self {
        switch to {
        case .front:
            self.middlewares.insert(middleware, at: 0)
        case .back:
            self.middlewares.append(middleware)
        }
        return self
    }

    func drop(middleware matching: (Middleware) -> Bool) -> Self {
        middlewares.removeAll(where: matching)
        return self
    }

    // MARK: Send
    var _logging = false

    func send() {
        if _logging { Log.info("requesting: \(expandedUrl)") }

        let queue = self.middlewares.reversed().reduce(onComplete) { (result, next) in
            return { res in
                next.handle(res, next: result)
            }
        } as NetworkCompletion

        guard Network.isAvailable else {
            queue(.failure(NSError.networkUnavailable))
            return
        }

        do {
            let request = try makeRequest()
            session.dataTask(with: request) { (data, response, error) in
                DispatchQueue.main.async {
                    queue(.init(response as? HTTPURLResponse, body: data, error: error))
                }
            }.resume()
        } catch {
            queue(.failure(error))
        }
    }

    private func makeRequest() throws -> URLRequest {
        guard let url = URL(string: expandedUrl) else {
            throw "can't make url from: \(expandedUrl)"
        }
        var request = URLRequest(url: url,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: _timeout)
        request.allHTTPHeaderFields = _headers
        request.httpMethod = _method.rawValue
        if _method != .get, let body = _body {
            let body = try body.encoded()
            request.setBody(json: body)
        }
        return request
    }

    var expandedUrl: String {
        var url = self.baseUrl.withTrailingSlash
        if _path.hasPrefix("/") {
            url += _path.dropFirst()
        } else {
            url += _path
        }
        guard _method == .get, let query = _body else { return url }
        return url + "?" + makeQueryString(parameters: query)
    }


    func makeQueryString(parameters: JSON) -> String {
        guard let object = parameters.obj else {
            assert(false, "object required for query params")
        }

        var params: [(key: String, val: String)] = []
        object.forEach { k, v in
            if let array = v.array {
                array.map(\.string!).forEach { v in
                    params.append((k, v))
                }
            } else {
                params.append((k, v.string!))
            }
        }

        let query = params.map { param in param.key + "=\(param.val)" }
            .sorted(by: <)
            .joined(separator: "&")
        // todo: fallback to percent fail onto original query
        // verify ideal behavior
        return query.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? query
    }

    private(set) var done = false
    private func onComplete(_ result: Result<NetworkResponse, Error>) {
        done = true
    }

    /// looks a little funny, but enables logging
    var logging: Self {
        _logging = true
        let path = self._path.withTrailingSlash
        return on.result { result in
            switch result {
            case .success(let resp):
                Log.info("request.succeeded: \(path)" + "\n\(resp)")
            case .failure(let err):
                Log.error("request.failed: \(path), error: \(err)")
            }
        } as! Self
    }
}

// MARK: Logging Builder

@dynamicCallable
class LoggingBuilder {
    private let host: Host

    fileprivate init(_ host: Host) {
        self.host = host
    }

    func dynamicallyCall<T: Encodable>(withArguments args: [T]) -> Host {
        let body: JSON
        if args.isEmpty {
            body = JSON.emptyObj
        } else if args.count == 1 {
            body = args[0].json!
        } else {
            body = args.json!
        }
        return host.set(body: body)
    }

    func dynamicallyCall(withKeywordArguments args: KeyValuePairs<String, Any>) -> Host {
        let body = JSON(args)
        return host.set(body: body)
    }
}

// MARK: Body Builder

@dynamicCallable
class BodyBuilder {
    private let host: Host

    fileprivate init(_ host: Host) {
        self.host = host
    }

    func dynamicallyCall<T: Encodable>(withArguments args: [T]) -> Host {
        let body: JSON
        if args.isEmpty {
            body = JSON.emptyObj
        } else if args.count == 1 {
            body = args[0].json!
        } else {
            body = args.json!
        }
        return host.set(body: body)
    }

    func dynamicallyCall(withKeywordArguments args: KeyValuePairs<String, Any>) -> Host {
        let body = JSON(args)
        return host.set(body: body)
    }
}

// MARK: Path Builder

@dynamicCallable
@dynamicMemberLookup
class PathBuilder {
    var get: HTTPMethod = .get
    var post: HTTPMethod = .post
    var put: HTTPMethod = .put
    var patch: HTTPMethod = .patch
    var delete: HTTPMethod = .delete

    private let host: Host
    private let startingPath: String?

    fileprivate init(_ host: Host, startingPath: String? = nil) {
        self.host = host
        self.startingPath = startingPath
    }

    func dynamicallyCall(withKeywordArguments args: KeyValuePairs<String, Any>) -> Host {
        var updated: String
        if let starting = startingPath {
            updated = starting
        } else {
            assert(args.count >= 1)
            let arg = args[0]
            assert(arg.key.isEmpty || arg.key == "path",
                   "first arg should be path string with no label, or (path: ")
            updated = arg.value as! String
        }

        args.forEach { entry, replacement in
            guard !entry.isEmpty && entry != "path" else { return }
            let wrapped = "{\(entry)}"
            let replacement = "\(replacement)"
            updated.replaceFirstOccurence(of: wrapped, with: replacement)
        }

        return host.set(path: updated)
    }

    /// sometimes we do like `.get("path")`, sometimes we just do like `get.on(success:)`
    subscript<T>(dynamicMember key: KeyPath<Host, T>) -> T {
        host[keyPath: key]
    }
}

extension String {
    fileprivate mutating func replaceFirstOccurence(of entry: String, with: String) {
        guard let range = self.range(of: entry) else {
            Log.warn("no occurence of \(entry) in \(self)")
            return
        }
        self.replaceSubrange(range, with: with)
    }
}

// MARK: Handler Builder

open class OnBuilder {
    let host: Host

    fileprivate init(_ host: Host) {
        self.host = host
    }

    func success(_ success: @escaping () -> Void) -> Host {
        host.middleware(BasicHandler(onSuccess: success))
    }

    func success(_ success: @escaping (NetworkResponse) -> Void) -> Host {
        host.middleware(BasicHandler(onSuccess: success))
    }

    func success<D: Decodable>(_ success: @escaping (D) -> Void) -> Host {
        host.middleware(BasicHandler(onSuccess: success))
    }

    func error(_ error: @escaping (Error) -> Void) -> Host {
        host.middleware(BasicHandler(onError: error))
    }

    func result(_ result: @escaping (Result<NetworkResponse, Error>) -> Void) -> Host {
        host.middleware(BasicHandler(basic: result))
    }
}

// MARK: Headers Builder

final class HeadersBuilderExistingKey {
    private let key: String
    private let host: Host

    fileprivate init(_ host: Host, key: String) {
        self.host = host
        self.key = key
    }

    func callAsFunction(_ val: String) -> Host {
        return host.set(header: key, val)
    }
}

@dynamicMemberLookup
final class HeadersBuilder {
    private let host: Host

    fileprivate init(_ host: Host) {
        self.host = host
    }

    func callAsFunction(_ key: String, _ val: String) -> Host {
        return host.set(header: key, val)
    }

    subscript(dynamicMember key: KeyPath<HeaderKey, String>) -> HeadersBuilderExistingKey {
        let headerKey = HeaderKey(stringLiteral: "")[keyPath: key]
        return .init(host, key: headerKey)
    }
}
