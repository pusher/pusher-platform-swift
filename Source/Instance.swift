import Foundation

@objc public class Instance: NSObject {
    public var instanceId: String
    public var serviceName: String
    public var serviceVersion: String
    public var tokenProvider: PPTokenProvider?
    public var client: PPBaseClient
    public var logger: PPLogger {
        willSet {
            self.client.logger = newValue
        }
    }

    public init(
        instanceId: String,
        serviceName: String,
        serviceVersion: String,
        tokenProvider: PPTokenProvider? = nil,
        client: PPBaseClient? = nil,
        logger: PPLogger? = nil
    ) {
        self.instanceId = instanceId
        self.serviceName = serviceName
        self.serviceVersion = serviceVersion
        self.tokenProvider = tokenProvider
        self.client = client ?? PPBaseClient(host: "")
        self.logger = logger ?? PPDefaultLogger()
        if self.client.logger == nil {
            self.client.logger = self.logger
        }
    }

    @discardableResult
    public func request(
        using requestOptions: PPRequestOptions,
        onSuccess: ((Data) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> PPRequest {
        let sanitisedPath = sanitise(path: requestOptions.path)
        let namespacedPath = namespace(path: sanitisedPath, instanceId: self.instanceId)

        let mutableBaseClientRequestOptions = requestOptions
        mutableBaseClientRequestOptions.path = namespacedPath

        var generalRequest = PPRequest(type: .general)

        if self.tokenProvider != nil {
            self.tokenProvider!.fetchToken { result in
                switch result {
                case .error(let error): onError?(error)
                case .success(let jwtFromTokenProvider):
                    let authHeaderValue = "Bearer \(jwtFromTokenProvider)"
                    mutableBaseClientRequestOptions.addHeaders(["Authorization": authHeaderValue])
                    self.client.request(
                        with: &generalRequest,
                        using: mutableBaseClientRequestOptions,
                        onSuccess: onSuccess,
                        onError: onError
                    )
                }
            }
        } else {
            self.client.request(
                with: &generalRequest,
                using: mutableBaseClientRequestOptions,
                onSuccess: onSuccess,
                onError: onError
            )
        }

        return generalRequest
    }

    @discardableResult
    public func requestWithRetry(
        using requestOptions: PPRequestOptions,
        onSuccess: ((Data) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> PPRetryableGeneralRequest {
        let sanitisedPath = sanitise(path: requestOptions.path)
        let namespacedPath = namespace(path: sanitisedPath, instanceId: self.instanceId)

        let mutableBaseClientRequestOptions = requestOptions
        mutableBaseClientRequestOptions.path = namespacedPath

        var generalRetryableRequest = PPRetryableGeneralRequest(instance: self, requestOptions: requestOptions)

        if self.tokenProvider != nil {
            self.tokenProvider!.fetchToken { result in
                switch result {
                case .error(let error): onError?(error)
                case .success(let jwtFromTokenProvider):
                    let authHeaderValue = "Bearer \(jwtFromTokenProvider)"
                    mutableBaseClientRequestOptions.addHeaders(["Authorization": authHeaderValue])
                    self.client.requestWithRetry(
                        with: &generalRetryableRequest,
                        using: mutableBaseClientRequestOptions,
                        onSuccess: onSuccess,
                        onError: onError
                    )
                }
            }
        } else {
            self.client.requestWithRetry(
                with: &generalRetryableRequest,
                using: mutableBaseClientRequestOptions,
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
        let namespacedPath = namespace(path: sanitisedPath, instanceId: self.instanceId)

        let mutableBaseClientRequestOptions = requestOptions
        mutableBaseClientRequestOptions.path = namespacedPath

        if self.tokenProvider != nil {
            // TODO: The weak here feels dangerous, also probably should be weak self

            self.tokenProvider!.fetchToken { [weak subscription] result in
                switch result {
                case .error(let error): onError?(error)
                case .success(let jwtFromTokenProvider):
                    let authHeaderValue = "Bearer \(jwtFromTokenProvider)"
                    mutableBaseClientRequestOptions.addHeaders(["Authorization": authHeaderValue])

                    self.client.subscribe(
                        with: &subscription!,
                        using: mutableBaseClientRequestOptions,
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
                using: mutableBaseClientRequestOptions,
                onOpening: onOpening,
                onOpen: onOpen,
                onEvent: onEvent,
                onEnd: onEnd,
                onError: onError
            )
        }
    }

    public func subscribeWithResume(
        with resumableSubscription: inout PPResumableSubscription,
        using requestOptions: PPRequestOptions,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onResuming: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let sanitisedPath = sanitise(path: requestOptions.path)
        let namespacedPath = namespace(path: sanitisedPath, instanceId: self.instanceId)

        let mutableBaseClientRequestOptions = requestOptions
        mutableBaseClientRequestOptions.path = namespacedPath

        if self.tokenProvider != nil {
            self.tokenProvider!.fetchToken { [weak resumableSubscription] result in
                switch result {
                case .error(let error): onError?(error)
                case .success(let jwtFromTokenProvider):
                    let authHeaderValue = "Bearer \(jwtFromTokenProvider)"
                    mutableBaseClientRequestOptions.addHeaders(["Authorization": authHeaderValue])

                    self.client.subscribeWithResume(
                        with: &resumableSubscription!,
                        using: mutableBaseClientRequestOptions,
                        instance: self,
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
                using: mutableBaseClientRequestOptions,
                instance: self,
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
        let namespacedPath = namespace(path: sanitisedPath, instanceId: self.instanceId)

        let mutableBaseClientRequestOptions = requestOptions
        mutableBaseClientRequestOptions.path = namespacedPath

        var subscription = PPRequest(type: .subscription)

        if self.tokenProvider != nil {
            self.tokenProvider!.fetchToken { result in
                switch result {
                case .error(let error): onError?(error)
                case .success(let jwtFromTokenProvider):
                    let authHeaderValue = "Bearer \(jwtFromTokenProvider)"
                    mutableBaseClientRequestOptions.addHeaders(["Authorization": authHeaderValue])

                    self.client.subscribe(
                        with: &subscription,
                        using: mutableBaseClientRequestOptions,
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
                using: mutableBaseClientRequestOptions,
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
    ) -> PPResumableSubscription {
        let sanitisedPath = sanitise(path: requestOptions.path)
        let namespacedPath = namespace(path: sanitisedPath, instanceId: self.instanceId)

        let mutableBaseClientRequestOptions = requestOptions
        mutableBaseClientRequestOptions.path = namespacedPath

        var resumableSubscription = PPResumableSubscription(instance: self, requestOptions: requestOptions)

        if self.tokenProvider != nil {
            // TODO: Does resumableSubscription need to be weak here?

            self.tokenProvider!.fetchToken { [weak resumableSubscription] result in
                switch result {
                case .error(let error): onError?(error)
                case .success(let jwtFromTokenProvider):
                    let authHeaderValue = "Bearer \(jwtFromTokenProvider)"
                    mutableBaseClientRequestOptions.addHeaders(["Authorization": authHeaderValue])

                    self.client.subscribeWithResume(
                        with: &resumableSubscription!,
                        using: mutableBaseClientRequestOptions,
                        instance: self,
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
                using: mutableBaseClientRequestOptions,
                instance: self,
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

    public func unsubscribe(taskIdentifier: Int, completionHandler: ((Error?) -> Void)? = nil) {
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
    internal func namespace(path: String, instanceId: String) -> String {
        let endIndex = path.index(path.startIndex, offsetBy: 6)

        if path.substring(to: endIndex) == "/apps/" {
            return path
        } else {
            let namespacedPath = "/apps/\(instanceId)/services\(path)"
            return namespacedPath
        }
    }
}
