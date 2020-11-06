//import Foundation
//
//protocol Auth: class {
//    var access: String { get set }
//    var refresh: String { get }
//}
//
//class AuthToken: Auth {
//    var access: String = ""
//    var refresh: String = ""
//}
//
//extension Host {
//    func using(_ auth: Auth) -> Self {
//        let refresh = RefreshMiddleware(self, auth)
//        return middleware(refresh)
//            .header.authorization("Bearer \(auth.access)")
//            as! Self
//    }
//}
//
//struct RefreshMiddleware: Middleware {
//
//    let host: Host
//    let auth: Auth
//
//    init(_ host: Host, _ auth: Auth) {
//        self.host = host
//        self.auth = auth
//    }
//
//    // MARK: Middleware
//
//    // TODO: can I move this to a private object and pass through in this file
//    // so that it's not exposed
//    func handle(_ result: Result<NetworkResponse, Error>,
//                next: @escaping NetworkCompletion) {
//         //todo: are there somoe potential threading issues here?
//        // maybe setup some sort of operation queue
//        switch result {
//        // detect unauthorized expired
//        case .failure(let err as NSError) where err.code == 401:
//            Log.info("unauthorized request, attempting refresh")
//            // attempt a refresh
//            Log.info("refresh.started: \(host.expandedUrl)")
//
//            Hyka.api.post
//                .refresh
//                .body(refresh: auth.refresh)
//                .on.success(retry(withRefreshResult:))
//                .on.error { error in
//                    next(.failure(error))
//                }
//                .send()
//        default:
//            // all other failures or success pass down chain
//            next(result)
//        }
//    }
//
//    private func retry(withRefreshResult result: JSON) {
//        auth.access = result.access!.string!
//        host.drop(middleware: {
//            $0 is RefreshMiddleware
//        })
//        .authorization("Bearer \(auth.access)")
//        .send()
//    }
//}
