import Foundation
import Commons

@dynamicMemberLookup
public class Base {
    public private(set) var baseUrl: String
    public var _method: HTTPMethod = .get
    public var _path: String = ""
    public var _headers: [String: String] = [:]
    public var _body: JSON? = nil

    // additional attributes
    private var _timeout: TimeInterval = 30.0
    private lazy var session: URLSession = URLSession(configuration: .default)

    public init(_ url: String) {
        self.baseUrl = url
    }

    // MARK: PathBuilder

    /// add keys to EP in an extension to support
    public subscript(dynamicMember key: KeyPath<Endpoint, Endpoint>) -> PathBuilder {
        let ep = Endpoint("")[keyPath: key]
        _path += ep.stringValue
        let builder = PathBuilder(self, startingPath: _path)
        return builder
    }

    /// for better building
    public subscript(dynamicMember key: KeyPath<Endpoint, Endpoint>) -> Self {
        let ep = Endpoint("")[keyPath: key]
        _path += ep.stringValue
        return self
    }

    /// get, post, put, patch, delete
    public subscript(dynamicMember key: KeyPath<PathBuilder, HTTPMethod>) -> PathBuilder {
        let builder = PathBuilder(self, startingPath: _path)
        self._method = builder[keyPath: key]
        return builder
    }

    /// get, post, put, patch, delete
    public subscript(dynamicMember key: KeyPath<PathBuilder, HTTPMethod>) -> Self {
        let builder = PathBuilder(self)
        self._method = builder[keyPath: key]
        return self
    }

    fileprivate func set(path: String) -> Self {
        self._path = path
        return self
    }

    // MARK: HeadersBuilder

    public var header: HeadersBuilder { HeadersBuilder(self) }

    fileprivate func set(header: String, _ v: String) -> Self {
        self._headers[header] = v
        return self
    }

    public subscript(dynamicMember key: KeyPath<HeaderKey, String>) -> HeadersBuilderExistingKey {
        let headerKey = HeaderKey(stringLiteral: "")[keyPath: key]
        return .init(self, key: headerKey)
    }

    // MARK: BodyBuilder

    public var query: BodyBuilder {
        assert(_method == .get, "query only allowed on get requests")
        return BodyBuilder(self)
    }

    public var body: BodyBuilder { BodyBuilder(self) }

    fileprivate func set(body: JSON) -> Self {
        assert(self._body == nil)
        self._body = body
        return self
    }

    // MARK: Handlers

    /// idk if I like this syntax or the other
    public var on: OnBuilder { OnBuilder(self) }

    // MARK: Middleware

    private var middlewares: [Middleware] = []

    public enum MiddlewareInsert {
        case front
        case back
    }

    public func middleware(_ middleware: Middleware, to: MiddlewareInsert = .back) -> Self {
        switch to {
        case .front:
            self.middlewares.insert(middleware, at: 0)
        case .back:
            self.middlewares.append(middleware)
        }
        return self
    }

    public func drop(middleware matching: (Middleware) -> Bool) -> Self {
        middlewares.removeAll(where: matching)
        return self
    }

    // MARK: Send

    public var _logging = false

    public func send() {
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
        if url.hasSuffix("/") { url.removeLast() }
        return url + "?" + makeQueryString(parameters: query)
    }


    enum QueryArrayEncodingStrategy {
        case commaSeparated, multiKeyed
    }
    let queryArrayEncodingStrategy: QueryArrayEncodingStrategy = .commaSeparated

    func makeQueryString(parameters: JSON) -> String {
        guard let object = parameters.obj else {
            fatalError("object required for query params")
        }
        switch queryArrayEncodingStrategy {
        case .multiKeyed:
            return makeMultiKeyedQuery(object: object)
        case .commaSeparated:
            return makeCommaSeparatedQuery(object: object)
        }
    }

    private func makeCommaSeparatedQuery(object: [String: JSON]) -> String {
        let query = object
            .map { key, val in
                let entry = val.array?.compactMap(\.string).joined(separator: ",") ?? val.string ?? ""
                return key + "=\(entry)"
            }
            .sorted(by: <)
            .joined(separator: "&")

        // todo: fallback to percent fail onto original query
        // verify ideal behavior
        return query.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? query
    }

    private func makeMultiKeyedQuery(object: [String: JSON]) -> String {
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

// MARK: Body Builder

@dynamicCallable
public class BodyBuilder {
    public let base: Base

    fileprivate init(_ base: Base) {
        self.base = base
    }

    public func dynamicallyCall<T: Encodable>(withArguments args: [T]) -> Base {
        let body: JSON
        if args.isEmpty {
            body = JSON.emptyObj
        } else if args.count == 1 {
            body = args[0].json!
        } else {
            body = args.json!
        }
        return base.set(body: body)
    }

    public func dynamicallyCall(withKeywordArguments args: KeyValuePairs<String, Any>) -> Base {
        let body = JSON(args)
        return base.set(body: body)
    }
}

// MARK: Path Builder

@dynamicCallable
@dynamicMemberLookup
public class PathBuilder {
    public var get: HTTPMethod = .get
    public var post: HTTPMethod = .post
    public var put: HTTPMethod = .put
    public var patch: HTTPMethod = .patch
    public var delete: HTTPMethod = .delete

    private let base: Base
    private let startingPath: String?

    fileprivate init(_ base: Base, startingPath: String? = nil) {
        self.base = base
        self.startingPath = startingPath
    }

    public func dynamicallyCall(withKeywordArguments args: KeyValuePairs<String, Any>) -> Base {
        var updated: String = ""
        if let starting = startingPath {
            updated = starting
        }

        if let arg = args.first, arg.key.isEmpty || arg.key == "path" {
            assert(args.count >= 1)
            let arg = args[0]
            assert(arg.key.isEmpty || arg.key == "path",
                   "first arg should be path string with no label, or (path: ")
            updated += arg.value as! String
        }

        args.forEach { entry, replacement in
            guard !entry.isEmpty && entry != "path" else { return }
            let wrapped = "{\(entry)}"
            let replacement = "\(replacement)"
            updated.replaceFirstOccurence(of: wrapped, with: replacement)
        }

        return base.set(path: updated)
    }

    /// sometimes we do like `.get("path")`, sometimes we just do like `get.on(success:)`
    public subscript<T>(dynamicMember key: KeyPath<Base, T>) -> T {
        base[keyPath: key]
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
    public let base: Base

    fileprivate init(_ base: Base) {
        self.base = base
    }

    public func success(_ success: @escaping () -> Void) -> Base {
        base.middleware(BasicHandler(onSuccess: success))
    }

    public func success(_ success: @escaping (NetworkResponse) -> Void) -> Base {
        base.middleware(BasicHandler(onSuccess: success))
    }

    public func success<D: Decodable>(_ success: @escaping (D) -> Void) -> Base {
        base.middleware(BasicHandler(onSuccess: success))
    }

    public func error(_ error: @escaping () -> Void) -> Base {
        base.middleware(BasicHandler(onError: { _ in error() }))
    }

    public func error(_ error: @escaping (Error) -> Void) -> Base {
        base.middleware(BasicHandler(onError: error))
    }

    public func result(_ result: @escaping (Result<NetworkResponse, Error>) -> Void) -> Base {
        base.middleware(BasicHandler(basic: result))
    }

    public func either(_ run: @escaping (Result<NetworkResponse, Error>) -> Void) -> Base {
        result(run)
    }

    public func either(_ run: @escaping () -> Void) -> Base {
        base.middleware(BasicHandler(basic: { _ in run() }))
    }
}

public struct TypedOnBuilder<D: Decodable> {
    public let base: Base

    init(_ base: Base) {
        self.base = base
    }

    // todo: make `OnBuilder` a function builder w
    // enums for state and use properties so these can pass through

    public func success(_ success: @escaping (D) -> Void) -> TypedBuilder<D> {
        base.middleware(BasicHandler(onSuccess: success)).typed()
    }

    public func success(_ success: @escaping () -> Void) -> TypedBuilder<D> {
        base.middleware(BasicHandler(onSuccess: success)).typed()
    }

    public func error(_ error: @escaping () -> Void) -> TypedBuilder<D> {
        base.middleware(BasicHandler(onError: { _ in error() })).typed()
    }

    public func error(_ error: @escaping (Error) -> Void) -> TypedBuilder<D> {
        base.middleware(BasicHandler(onError: error)).typed()
    }

    public func either(_ runner: @escaping (Result<D, Error>) -> Void) -> TypedBuilder<D> {
        base.on.result { $0.map(to: runner) }.typed()
    }

    public func either(_ run: @escaping () -> Void) -> TypedBuilder<D> {
        base.middleware(BasicHandler(basic: { _ in run() })).typed()
    }

    public func result(_ result: @escaping (Result<NetworkResponse, Error>) -> Void) -> TypedBuilder<D> {
        base.on.result(result).typed()
    }
}

public struct TypedBuilder<D: Decodable> {
    public let base: Base

    init(_ base: Base) {
        self.base = base
    }

    public var on: TypedOnBuilder<D> { .init(base) }

    public func send() { base.send() }

    // is this needed?
    public var detyped: Base { base }
}

extension Base {
    public func typed<D: Decodable>(as: D.Type = D.self) -> TypedBuilder<D> {
        .init(self)
    }
}

// MARK: Headers Builder

public final class HeadersBuilderExistingKey {
    public let key: String
    private let base: Base

    fileprivate init(_ base: Base, key: String) {
        self.base = base
        self.key = key
    }

    public func callAsFunction(_ val: String) -> Base {
        return base.set(header: key, val)
    }
}

@dynamicMemberLookup
public final class HeadersBuilder {
    public let base: Base

    fileprivate init(_ base: Base) {
        self.base = base
    }

    public func callAsFunction(_ key: String, _ val: String) -> Base {
        return base.set(header: key, val)
    }

    public subscript(dynamicMember key: KeyPath<HeaderKey, String>) -> HeadersBuilderExistingKey {
        let headerKey = HeaderKey(stringLiteral: "")[keyPath: key]
        return .init(base, key: headerKey)
    }
}
