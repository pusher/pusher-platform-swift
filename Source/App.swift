import Foundation

@objc public class App: NSObject {
    public var id: String
    public var cluster: String?
    public var authorizer: Authorizer?
    public var client: BaseClient

    public init(id: String, cluster: String? = nil, authorizer: Authorizer? = nil, client: BaseClient? = nil) throws {
        self.id = id
        self.cluster = cluster
        self.authorizer = authorizer
        try self.client = client ?? BaseClient(cluster: cluster)
    }

    public func request(using generalRequest: GeneralRequest, completionHandler: @escaping (Result<Data>) -> Void) -> Void {
        let sanitisedPath = sanitise(path: generalRequest.path)
        let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

        let mutableBaseClientRequest = generalRequest
        mutableBaseClientRequest.path = namespacedPath

//        if generalRequest.jwt == nil && self.authorizer != nil {
//            self.authorizer!.authorize { result in
//                switch result {
//                case .failure(let error): completionHandler(.failure(error))
//                case .success(let jwtFromAuthorizer):
//                    mutableBaseClientRequest.jwt = jwtFromAuthorizer
//                    self.client.request(using: mutableBaseClientRequest, completionHandler: completionHandler)
//                }
//            }
//        } else {
            self.client.request(using: mutableBaseClientRequest, completionHandler: completionHandler)
//        }
    }

    public func subscribe(
        using subscribeRequest: SubscribeRequest,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil) -> Subscription {
            let sanitisedPath = sanitise(path: subscribeRequest.path)
            let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

            let mutableBaseClientRequest = subscribeRequest
            mutableBaseClientRequest.path = namespacedPath

//            if subscribeRequest.jwt == nil && self.authorizer != nil {
//                self.authorizer!.authorize { result in
//                    switch result {
//                    case .failure(let error): completionHandler(.failure(error))
//                    case .success(let jwtFromAuthorizer):
//                        mutableBaseClientRequest.jwt = jwtFromAuthorizer
//                        return self.client.subscribe(
//                            using: mutableBaseClientRequest,
//                            onOpening: onOpening,
//                            onOpen: onOpen,
//                            onEvent: onEvent,
//                            onEnd: onEnd,
//                            onError: onError
//                        )
//                    }
//                }
//            } else {
                return self.client.subscribe(
                    using: mutableBaseClientRequest,
                    onOpening: onOpening,
                    onOpen: onOpen,
                    onEvent: onEvent,
                    onEnd: onEnd,
                    onError: onError
                )
//            }
    }

    public func subscribeWithResume(
        resumableSubscription: inout ResumableSubscription,
        using subscribeRequest: SubscribeRequest,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onResuming: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil) {
            let sanitisedPath = sanitise(path: subscribeRequest.path)
            let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

            let mutableBaseClientRequest = subscribeRequest
            mutableBaseClientRequest.path = namespacedPath

            if self.authorizer != nil {
                self.authorizer!.authorize { [weak resumableSubscription] result in
                    switch result {
                    case .failure(let error): onError?(error)
                    case .success(let jwtFromAuthorizer):
                        let authHeaderValue = "Bearer \(jwtFromAuthorizer)"
                        if mutableBaseClientRequest.headers != nil {
                            mutableBaseClientRequest.headers!["Authorization"] = authHeaderValue
                        } else {
                            mutableBaseClientRequest.headers = ["Authorization": authHeaderValue]
                        }

                        self.client.subscribeWithResume(
                            resumableSubscription: &resumableSubscription!,
                            using: mutableBaseClientRequest,
                            app: self,
                            onOpening: onOpening,
                            onOpen: onOpen,
                            onResuming: onResuming,
                            onEvent: onEvent,
                            onEnd: onEnd,
                            onError: onError
                        )
                    }
                }
            } else {
                self.client.subscribeWithResume(
                    resumableSubscription: &resumableSubscription,
                    using: mutableBaseClientRequest,
                    app: self,
                    onOpening: onOpening,
                    onOpen: onOpen,
                    onResuming: onResuming,
                    onEvent: onEvent,
                    onEnd: onEnd,
                    onError: onError
                )
            }
    }

//    public func subscribeWithResume(
//        using subscribeRequest: SubscribeRequest,
//        onOpening: (() -> Void)? = nil,
//        onOpen: (() -> Void)? = nil,
//        onResuming: (() -> Void)? = nil,
//        onEvent: ((String, [String: String], Any) -> Void)? = nil,
//        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
//        onError: ((Error) -> Void)? = nil) -> ResumableSubscription {
//            let sanitisedPath = sanitise(path: subscribeRequest.path)
//            let namespacedPath = namespace(path: sanitisedPath, appId: self.id)
//
//            let mutableBaseClientRequest = subscribeRequest
//            mutableBaseClientRequest.path = namespacedPath
//
////            if subscribeRequest.jwt == nil && self.authorizer != nil {
////                self.authorizer!.authorize { result in
////                    switch result {
////                    case .failure(let error): completionHandler(.failure(error))
////                    case .success(let jwtFromAuthorizer):
////                        mutableBaseClientRequest.jwt = jwtFromAuthorizer
////                        return self.client.subscribeWithResume(
////                            using: mutableBaseClientRequest,
////                            app: self,
////                            onOpening: onOpening,
////                            onOpen: onOpen,
////                            onResuming: onResuming,
////                            onEvent: onEvent,
////                            onEnd: onEnd,
////                            onError: onError
////                        )
////                    }
////                }
////            } else {
//                return self.client.subscribeWithResume(
//                    using: mutableBaseClientRequest,
//                    app: self,
//                    onOpening: onOpening,
//                    onOpen: onOpen,
//                    onResuming: onResuming,
//                    onEvent: onEvent,
//                    onEnd: onEnd,
//                    onError: onError
//                )
////            }
//    }

    public func unsubscribe(taskIdentifier: Int, completionHandler: ((Result<Bool>) -> Void)? = nil) {
        self.client.unsubscribe(taskIdentifier: taskIdentifier, completionHandler: completionHandler)
    }

    internal func sanitise(path: String) -> String {
        var sanitisedPath = ""

        for (_, char) in path.characters.enumerated() {
            // only append a slash if last character isn't already a slash
            if char == "/" {
                if !sanitisedPath.hasSuffix("/") {
                    sanitisedPath.append(char)
                }
            } else {
                sanitisedPath.append(char)
            }
        }

        // remove trailing slash
        if sanitisedPath.hasSuffix("/") {
            sanitisedPath.remove(at: sanitisedPath.index(before: sanitisedPath.endIndex))
        }

        // ensure leading slash
        if !sanitisedPath.hasPrefix("/") {
            sanitisedPath = "/\(sanitisedPath)"
        }

        return sanitisedPath
    }

    // Only prefix with /apps/APP_ID if /apps/ isn't at the start of the path
    internal func namespace(path: String, appId: String) -> String {
        let endIndex = path.index(path.startIndex, offsetBy: 6)

        if path.substring(to: endIndex) == "/apps/" {
            return path
        } else {
            let namespacedPath = "/apps/\(appId)\(path)"
            return namespacedPath
        }
    }
}
