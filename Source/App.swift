import Foundation

@objc public class App: NSObject {
    public var id: String
    public var cluster: String?
    public var authorizer: Authorizer?
    public var client: BaseClient
    public let logger: PPLogger

    public init(
        id: String,
        cluster: String? = nil,
        authorizer: Authorizer? = nil,
        client: BaseClient? = nil,
        logger: PPLogger = PPDefaultLogger()
    ) {
        self.id = id
        self.cluster = cluster
        self.authorizer = authorizer
        self.client = client ?? BaseClient(cluster: cluster)
        self.logger = logger
        self.client.logger = logger
    }

    public func request(
        using requestOptions: PPRequestOptions,
        onSuccess: ((Data) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> PPRequest {
        let sanitisedPath = sanitise(path: requestOptions.path)
        let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

        let mutableBaseClientRequest = requestOptions
        mutableBaseClientRequest.path = namespacedPath

        var generalRequest = PPRequest(type: .general)

        if self.authorizer != nil {
            self.authorizer!.authorize { result in
                switch result {
                case .failure(let error): onError?(error)
                case .success(let jwtFromAuthorizer):
                    let authHeaderValue = "Bearer \(jwtFromAuthorizer)"
                    mutableBaseClientRequest.addHeaders(["Authorization": authHeaderValue])
                    self.client.request(
                        with: &generalRequest,
                        using: mutableBaseClientRequest,
                        onSuccess: onSuccess,
                        onError: onError
                    )
                }
            }
        } else {
            self.client.request(
                with: &generalRequest,
                using: mutableBaseClientRequest,
                onSuccess: onSuccess,
                onError: onError
            )
        }

        return generalRequest
    }


    public func requestWithRetry(
        using requestOptions: PPRequestOptions,
        onSuccess: ((Data) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> PPRetryableGeneralRequest {
        let sanitisedPath = sanitise(path: requestOptions.path)
        let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

        let mutableBaseClientRequest = requestOptions
        mutableBaseClientRequest.path = namespacedPath

        var generalRetryableRequest = PPRetryableGeneralRequest(app: self, requestOptions: requestOptions)

        if self.authorizer != nil {
            self.authorizer!.authorize { result in
                switch result {
                case .failure(let error): onError?(error)
                case .success(let jwtFromAuthorizer):
                    let authHeaderValue = "Bearer \(jwtFromAuthorizer)"
                    mutableBaseClientRequest.addHeaders(["Authorization": authHeaderValue])
                    self.client.requestWithRetry(
                        with: &generalRetryableRequest,
                        using: mutableBaseClientRequest,
                        onSuccess: onSuccess,
                        onError: onError
                    )
                }
            }
        } else {
            self.client.requestWithRetry(
                with: &generalRetryableRequest,
                using: mutableBaseClientRequest,
                onSuccess: onSuccess,
                onError: onError
            )
        }

        return generalRetryableRequest
    }

    public func subscribe(
        with subscription: inout PPRequest,
        using requestOptions: PPRequestOptions,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let sanitisedPath = sanitise(path: requestOptions.path)
        let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

        let mutableBaseClientRequest = requestOptions
        mutableBaseClientRequest.path = namespacedPath

        if self.authorizer != nil {
            // TODO: The weak here feels dangerous

            self.authorizer!.authorize { [weak subscription] result in
                switch result {
                case .failure(let error): onError?(error)
                case .success(let jwtFromAuthorizer):
                    let authHeaderValue = "Bearer \(jwtFromAuthorizer)"
                    mutableBaseClientRequest.addHeaders(["Authorization": authHeaderValue])

                    self.client.subscribe(
                        with: &subscription!,
                        using: mutableBaseClientRequest,
                        onOpening: onOpening,
                        onOpen: onOpen,
                        onEvent: onEvent,
                        onEnd: onEnd,
                        onError: onError
                    )
                }
            }
        } else {
            self.client.subscribe(
                with: &subscription,
                using: mutableBaseClientRequest,
                onOpening: onOpening,
                onOpen: onOpen,
                onEvent: onEvent,
                onEnd: onEnd,
                onError: onError
            )
        }
    }

    public func subscribeWithResume(
        with resumableSubscription: inout ResumableSubscription,
        using requestOptions: PPRequestOptions,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onResuming: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let sanitisedPath = sanitise(path: requestOptions.path)
        let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

        let mutableBaseClientRequest = requestOptions
        mutableBaseClientRequest.path = namespacedPath

        if self.authorizer != nil {
            self.authorizer!.authorize { [weak resumableSubscription] result in
                switch result {
                case .failure(let error): onError?(error)
                case .success(let jwtFromAuthorizer):
                    let authHeaderValue = "Bearer \(jwtFromAuthorizer)"
                    mutableBaseClientRequest.addHeaders(["Authorization": authHeaderValue])

                    self.client.subscribeWithResume(
                        with: &resumableSubscription!,
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
                with: &resumableSubscription,
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

    public func subscribe(
        using requestOptions: PPRequestOptions,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> PPRequest {
        let sanitisedPath = sanitise(path: requestOptions.path)
        let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

        let mutableBaseClientRequest = requestOptions
        mutableBaseClientRequest.path = namespacedPath

        var subscription = PPRequest(type: .subscription)

        if self.authorizer != nil {
            self.authorizer!.authorize { result in
                switch result {
                case .failure(let error): onError?(error)
                case .success(let jwtFromAuthorizer):
                    let authHeaderValue = "Bearer \(jwtFromAuthorizer)"
                    mutableBaseClientRequest.addHeaders(["Authorization": authHeaderValue])

                    self.client.subscribe(
                        with: &subscription,
                        using: mutableBaseClientRequest,
                        onOpening: onOpening,
                        onOpen: onOpen,
                        onEvent: onEvent,
                        onEnd: onEnd,
                        onError: onError
                    )
                }
            }
        } else {
            self.client.subscribe(
                with: &subscription,
                using: mutableBaseClientRequest,
                onOpening: onOpening,
                onOpen: onOpen,
                onEvent: onEvent,
                onEnd: onEnd,
                onError: onError
            )
        }

        return subscription
    }

    public func subscribeWithResume(
        using requestOptions: PPRequestOptions,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onResuming: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> ResumableSubscription {
        let sanitisedPath = sanitise(path: requestOptions.path)
        let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

        let mutableBaseClientRequest = requestOptions
        mutableBaseClientRequest.path = namespacedPath

        var resumableSubscription = ResumableSubscription(app: self, requestOptions: requestOptions)

        if self.authorizer != nil {
            // TODO: Does resumableSubscription need to be weak here?

            self.authorizer!.authorize { [weak resumableSubscription] result in
                switch result {
                case .failure(let error): onError?(error)
                case .success(let jwtFromAuthorizer):
                    let authHeaderValue = "Bearer \(jwtFromAuthorizer)"
                    mutableBaseClientRequest.addHeaders(["Authorization": authHeaderValue])

                    self.client.subscribeWithResume(
                        with: &resumableSubscription!,
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
                with: &resumableSubscription,
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

        return resumableSubscription
    }

    public func unsubscribe(taskIdentifier: Int, completionHandler: ((Result<Bool>) -> Void)? = nil) {
        self.client.unsubscribe(taskIdentifier: taskIdentifier, completionHandler: completionHandler)
    }

    internal func sanitise(path: String) -> String {
        var sanitisedPath = ""

        for char in path.characters {
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
