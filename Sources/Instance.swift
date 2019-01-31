import Foundation

@objc public class Instance: NSObject {
    public let id: String
    public var serviceName: String
    public var serviceVersion: String
    public var tokenProvider: PPTokenProvider?
    public var client: PPBaseClient
    public var logger: PPLogger {
        willSet {
            self.client.logger = newValue
        }
    }

    public convenience init(
        locator: String,
        serviceName: String,
        serviceVersion: String,
        sdkInfo: PPSDKInfo,
        tokenProvider: PPTokenProvider? = nil,
        logger: PPLogger = PPDefaultLogger()
    ) {
        self.init(
            locator: locator,
            serviceName: serviceName,
            serviceVersion: serviceVersion,
            client: nil,
            sdkInfo: sdkInfo,
            tokenProvider: tokenProvider,
            logger: logger
        )
    }

    public convenience init(
        locator: String,
        serviceName: String,
        serviceVersion: String,
        client: PPBaseClient,
        tokenProvider: PPTokenProvider? = nil,
        logger: PPLogger = PPDefaultLogger()
    ) {
        self.init(
            locator: locator,
            serviceName: serviceName,
            serviceVersion: serviceVersion,
            client: client,
            sdkInfo: nil,
            tokenProvider: tokenProvider,
            logger: logger
        )
    }

    fileprivate init(
        locator: String,
        serviceName: String,
        serviceVersion: String,
        client: PPBaseClient?,
        sdkInfo: PPSDKInfo?,
        tokenProvider: PPTokenProvider? = nil,
        logger: PPLogger = PPDefaultLogger()
    ) {
        assert(client != nil || sdkInfo != nil, "You must provide at least one of client and sdkInfo")
        assert (!locator.isEmpty, "Expected locator property in Instance!")
        let splitInstance = locator.components(separatedBy: ":")
        assert(splitInstance.count == 3, "Expecting locator to be of the form 'v1:us1:1a234-123a-1234-12a3-1234123aa12' but got this instead: '\(locator)'. Check the dashboard to ensure you have a properly formatted locator.")
        assert(!serviceName.isEmpty, "Expected serviceName property in Instance options!")
        assert(!serviceVersion.isEmpty, "Expected serviceVersion property in Instance otpions!")

        self.id = splitInstance[2]
        self.serviceName = serviceName
        self.serviceVersion = serviceVersion
        self.tokenProvider = tokenProvider

        self.logger = logger

        if client == nil {
            let cluster = splitInstance[1]
            let host = "\(cluster).pusherplatform.io"

            self.client = PPBaseClient(host: host, sdkInfo: sdkInfo!)
        } else {
            self.client = client!
        }

        self.client.logger = self.client.logger ?? logger
    }

    @discardableResult
    public func request(
        using requestOptions: PPRequestOptions,
        onSuccess: ((Data) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> PPGeneralRequest {
        var generalRequest = PPGeneralRequest()

        fetchTokenIfRequiredAndMakeRequest(
            requestOptions: requestOptions,
            onError: onError,
            requestMaker: { options in
                self.client.request(
                    with: &generalRequest,
                    using: options,
                    onSuccess: onSuccess,
                    onError: onError
                )
            }
        )

        return generalRequest
    }

    @discardableResult
    public func requestWithRetry(
        using requestOptions: PPRequestOptions,
        onSuccess: ((Data) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> PPRetryableGeneralRequest {
        var generalRetryableRequest = PPRetryableGeneralRequest(instance: self, requestOptions: requestOptions)

        fetchTokenIfRequiredAndMakeRequest(
            requestOptions: requestOptions,
            onError: onError,
            requestMaker: { options in
                self.client.requestWithRetry(
                    with: &generalRetryableRequest,
                    using: options,
                    onSuccess: onSuccess,
                    onError: onError
                )
            }
        )

        return generalRetryableRequest
    }

    public func subscribe(
        with subscription: inout PPSubscription,
        using requestOptions: PPRequestOptions,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        fetchTokenIfRequiredAndMakeRequest(
            requestOptions: requestOptions,
            onError: onError,
            requestMaker: { [weak subscription] options in
                guard subscription != nil else {
                    // The token request has completed (successfully, presumably) but
                    // something else has cleaned up the subscription, so now this is
                    // really just a no-op
                    return
                }
                self.client.subscribe(
                    with: &subscription!,
                    using: options,
                    onOpening: onOpening,
                    onOpen: onOpen,
                    onEvent: onEvent,
                    onEnd: onEnd,
                    onError: onError
                )
            }
        )
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
        fetchTokenIfRequiredAndMakeRequest(
            requestOptions: requestOptions,
            onError: onError,
            requestMaker: { [weak resumableSubscription] options in
                guard resumableSubscription != nil else {
                    // The token request has completed (successfully, presumably) but
                    // something else has cleaned up the resumableSubscription, so
                    // now this is really just a no-op
                    return
                }
                self.client.subscribeWithResume(
                    with: &resumableSubscription!,
                    using: options,
                    instance: self,
                    onOpening: onOpening,
                    onOpen: onOpen,
                    onResuming: onResuming,
                    onEvent: onEvent,
                    onEnd: onEnd,
                    onError: onError
                )
            }
        )
    }

    public func subscribe(
        using requestOptions: PPRequestOptions,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> PPSubscription {
        var subscription = PPSubscription()

        fetchTokenIfRequiredAndMakeRequest(
            requestOptions: requestOptions,
            onError: onError,
            requestMaker: { options in
                self.client.subscribe(
                    with: &subscription,
                    using: options,
                    onOpening: onOpening,
                    onOpen: onOpen,
                    onEvent: onEvent,
                    onEnd: onEnd,
                    onError: onError
                )
            }
        )

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
        var resumableSubscription = PPResumableSubscription(instance: self, requestOptions: requestOptions)

        fetchTokenIfRequiredAndMakeRequest(
            requestOptions: requestOptions,
            onError: onError,
            requestMaker: { options in
                self.client.subscribeWithResume(
                    with: &resumableSubscription,
                    using: options,
                    instance: self,
                    onOpening: onOpening,
                    onOpen: onOpen,
                    onResuming: onResuming,
                    onEvent: onEvent,
                    onEnd: onEnd,
                    onError: onError
                )
            }
        )

        return resumableSubscription
    }

    @discardableResult
    public func download(
        using requestOptions: PPRequestOptions,
        to destination: PPDownloadFileDestination? = nil,
        onSuccess: ((URL) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        progressHandler: ((Int64, Int64) -> Void)? = nil
    ) -> PPDownload {
        var downloadRequest = PPDownload()

        fetchTokenIfRequiredAndMakeRequest(
            requestOptions: requestOptions,
            onError: onError,
            requestMaker: { options in
                self.client.download(
                    with: &downloadRequest,
                    using: options,
                    to: destination,
                    onSuccess: onSuccess,
                    onError: onError
                )
            }
        )

        return downloadRequest
    }

    // TODO: Fill this in
    //    @discardableResult
    //    public func download(
    //        resumingWith resumeData: Data,
    ////        to destination: DownloadRequest.DownloadFileDestination? = nil,
    //        onSuccess: ((Data) -> Void)? = nil,
    //        onError: ((Error) -> Void)? = nil
    //    ) -> PPDownload {
    //
    //    }

    // TODO: Should we be returning the PPUpload object?
    public func upload(
        using requestOptions: PPRequestOptions,
        multipartFormData: @escaping (PPMultipartFormData) -> Void,
        onSuccess: ((Data) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        progressHandler: ((Int64, Int64) -> Void)? = nil
    ) {
        var uploadRequest = PPUpload()

        fetchTokenIfRequiredAndMakeRequest(
            requestOptions: requestOptions,
            onError: onError,
            requestMaker: { options in
                self.client.upload(
                    with: &uploadRequest,
                    using: options,
                    multipartFormData: multipartFormData,
                    onSuccess: onSuccess,
                    onError: onError,
                    progressHandler: progressHandler
                )
            }
        )
    }

    public func unsubscribe(taskIdentifier: Int, completionHandler: ((Error?) -> Void)? = nil) {
        self.client.unsubscribe(taskIdentifier: taskIdentifier, completionHandler: completionHandler)
    }

    func fetchTokenIfRequiredAndMakeRequest(
        requestOptions: PPRequestOptions,
        onError: ((Error) -> Void)? = nil,
        requestMaker: @escaping (_: PPRequestOptions) -> Void
    ) {
        let mutableRequestOptions = namespacePathIfRelativeDestination(requestOptions)

        if requestOptions.shouldFetchToken, let tokenProvider = self.tokenProvider {
            tokenProvider.fetchToken { result in
                switch result {
                case .error(let error): onError?(error)
                case .success(let jwtFromTokenProvider):
                    let authHeaderValue = "Bearer \(jwtFromTokenProvider)"
                    mutableRequestOptions.addHeaders(["Authorization": authHeaderValue])
                    requestMaker(mutableRequestOptions)
                }
            }
        } else {
            requestMaker(mutableRequestOptions)
        }
    }

    fileprivate func namespacePathIfRelativeDestination(_ options: PPRequestOptions) -> PPRequestOptions {
        switch options.destination {
        case .absolute(_):
            return options
        case .relative(let path):
            let namespacedPath = namespace(path: path)

            // TODO: Should this be a proper copy instead?
            let mutableBaseClientRequestOptions = options
            mutableBaseClientRequestOptions.destination = .relative(namespacedPath)
            return mutableBaseClientRequestOptions
        }
    }

    internal func sanitise(path: String) -> String {
        var sanitisedPath = ""

        for char in path {
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

    internal func namespace(path: String) -> String {
        if path.hasPrefix("/services/") {
            return path
        }

        return sanitise(path: "services/\(self.serviceName)/\(self.serviceVersion)/\(self.id)/\(path)")
    }
}
