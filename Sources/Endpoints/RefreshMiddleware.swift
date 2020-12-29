import Foundation
import Commons

struct RefreshMiddleware: Middleware {

    let base: Base
    let refreshRequest: () -> Base
    let updateAuthHeaders: (Base, JSON) -> Void

    init(_ base: Base,
         refreshRequest: @escaping () -> Base,
         updateAuthHeaders: @escaping (Base, JSON) -> Void) {
        self.base = base
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
            Log.info("refresh.started: \(base.expandedUrl)")

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
        updateAuthHeaders(base, result)
        base.drop(middleware: {
            $0 is RefreshMiddleware
        })
        .send()
    }
}


//private class Auth {
//    var access = ""
//    var refresh = ""
//}
//
//private var globalAuth = Auth()
//
//extension RefreshMiddleware {
//    fileprivate static func example(on base: Base) -> RefreshMiddleware {
//        RefreshMiddleware.init(
//            base: Base,
//            refreshRequest: {
//                base("https://api.myapp.io")
//                    .post("token/refresh")
//                    .body(refresh: globalAuth.refresh)
//                    .on.success { resp in
//                        globalAuth.access = resp.json!.access!.string!
//                    }
//
//            },
//            updateAuthHeaders: { base: Base, resp in
//                globalAuth.access = resp.json!.access!.string!
//            }
//        )
//    }
//}
//
//extension Base {
//    private func refreshing() -> Self {
//        let refresh = RefreshMiddleware.example(on: self)
//        return middleware(refresh, to: .front)
//    }
//}
