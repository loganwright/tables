import Foundation

struct RefreshMiddleware: Middleware {

    let host: Host
    let refreshRequest: () -> Host
    let updateAuthHeaders: (Host, JSON) -> Void

    init(_ host: Host,
         refreshRequest: @escaping () -> Host,
         updateAuthHeaders: @escaping (Host, JSON) -> Void) {
        self.host = host
        self.refreshRequest = refreshRequest
        self.updateAuthHeaders = updateAuthHeaders
    }

    // MARK: Middleware

    // TODO: can I move this to a private object and pass through in this file
    // so that it's not exposed
    func handle(_ result: Result<NetworkResponse, Error>,
                next: @escaping NetworkCompletion) {
         //todo: are there somoe potential threading issues here?
        // maybe setup some sort of operation queue
        switch result {
        // detect unauthorized expired
        case .failure(let err as NSError) where err.code == 401:
            Log.info("unauthorized request, attempting refresh")
            // attempt a refresh
            Log.info("refresh.started: \(host.expandedUrl)")

            refreshRequest()
                .on.success(retry(withRefreshResult:))
                .on.error { error in
                    next(.failure(error))
                }
                .send()
        default:
            // all other failures or success pass down chain
            next(result)
        }
    }

    private func retry(withRefreshResult result: JSON) {
        updateAuthHeaders(host, result)
        host.drop(middleware: {
            $0 is RefreshMiddleware
        })
        .send()
    }
}


private class Auth {
    var access = ""
    var refresh = ""
}

private var globalAuth = Auth()

extension RefreshMiddleware {
    fileprivate static func example(on host: Host) -> RefreshMiddleware {
        RefreshMiddleware.init(
            host,
            refreshRequest: {
                Host("https://api.myapp.io")
                    .post("token/refresh")
                    .body(refresh: globalAuth.refresh)
                    .on.success { resp in
                        globalAuth.access = resp.json!.access!.string!
                    }

            },
            updateAuthHeaders: { host, resp in
                globalAuth.access = resp.json!.access!.string!
            }
        )
    }
}

extension Host {
    private func refreshing() -> Self {
        let refresh = RefreshMiddleware.example(on: self)
        return middleware(refresh, to: .front)
    }
}
