import Foundation

let REALLY_LONG_TIME: Double = 252_460_800

@objc public class PPBaseClient: NSObject {
    public var port: Int?
    var baseUrlComponents: URLComponents

    public var subscriptionURLSession: URLSession
    public var subscriptionSessionDelegate: PPSubscriptionURLSessionDelegate

    public var generalRequestURLSession: URLSession
    public var generalRequestSessionDelegate: PPGeneralRequestURLSessionDelegate

    public var downloadURLSession: URLSession
    public var downloadSessionDelegate: PPDownloadURLSessionDelegate

    public var uploadURLSession: URLSession
    public var uploadSessionDelegate: PPUploadURLSessionDelegate

    public var logger: PPLogger? = nil {
        willSet {
            self.subscriptionSessionDelegate.logger = newValue
            self.generalRequestSessionDelegate.logger = newValue
            self.downloadSessionDelegate.logger = newValue
            self.uploadSessionDelegate.logger = newValue
        }
    }

    // Queue used to ensure that creating directories for large upload tasks is
    // done serially
    let uploadQueue = DispatchQueue(label: "com.pusherplatform.swift.base-client.upload.\(UUID().uuidString)")

    // Queue used to ensure that cleaning up tempfiles used for large upload tasks
    // is done serially
    let uploadCleanupQueue = DispatchQueue(label: "com.pusherplatform.swift.base-client.upload-cleanup.\(UUID().uuidString)")

    // Should be between 30 and 300
    public let heartbeatTimeout: Int

    // Should be between 0 and 10240 (to avoid 422 response) - we don't need any
    // initial data because the custom content type header means that no data
    // gets buffered by URLSession
    public let heartbeatInitialSize: Int

    // Set to true if you want to trust all certificates
    public let insecure: Bool

    // If you want to provide a closure that builds a PPRetryStrategy based on
    // a request's options then you can use this property
    public var retryStrategyBuilder: (PPRequestOptions) -> PPRetryStrategy

    public let sdkInfo: PPSDKInfo

    // If you want every request to have the X-Client-Request-ID header set
    // then set this to true
    let enableTracing: Bool

    public init(
        host: String,
        port: Int? = nil,
        insecure: Bool = false,
        retryStrategyBuilder: @escaping (PPRequestOptions) -> PPRetryStrategy = PPBaseClient.methodAwareRetryStrategyGenerator,
        heartbeatTimeoutInterval: Int = 60,
        heartbeatInitialSize: Int = 0,
        sdkInfo: PPSDKInfo,
        enableTracing: Bool = false
    ) {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = host
        urlComponents.port = port

        self.baseUrlComponents = urlComponents
        self.insecure = insecure
        self.retryStrategyBuilder = retryStrategyBuilder
        self.heartbeatTimeout = heartbeatTimeoutInterval
        self.heartbeatInitialSize = heartbeatInitialSize
        self.sdkInfo = sdkInfo
        self.enableTracing = enableTracing

        self.subscriptionSessionDelegate = PPSubscriptionURLSessionDelegate(insecure: insecure)

        let subscriptionSessionConfiguration = URLSessionConfiguration.default
        subscriptionSessionConfiguration.timeoutIntervalForResource = REALLY_LONG_TIME
        subscriptionSessionConfiguration.timeoutIntervalForRequest = REALLY_LONG_TIME
        subscriptionSessionConfiguration.httpAdditionalHeaders = [
            "X-Heartbeat-Interval": String(self.heartbeatTimeout),
            "X-Initial-Heartbeat-Size": String(self.heartbeatInitialSize)
        ].merging(sdkInfo.headers, uniquingKeysWith: { (first, _) in first })

        self.subscriptionURLSession = URLSession(
            configuration: subscriptionSessionConfiguration,
            delegate: subscriptionSessionDelegate,
            delegateQueue: nil
        )
        self.subscriptionURLSession.sessionDescription = "subscriptionURLSession"

        self.generalRequestSessionDelegate = PPGeneralRequestURLSessionDelegate(insecure: insecure)

        let generalRequestSessionConfiguration = URLSessionConfiguration.default
        generalRequestSessionConfiguration.httpAdditionalHeaders = sdkInfo.headers

        self.generalRequestURLSession = URLSession(
            configuration: generalRequestSessionConfiguration,
            delegate: self.generalRequestSessionDelegate,
            delegateQueue: nil
        )
        self.generalRequestURLSession.sessionDescription = "generalRequestURLSession"

        self.uploadSessionDelegate =  PPUploadURLSessionDelegate(insecure: insecure)

        self.uploadURLSession = URLSession(
            configuration: PPBaseClient.backgroundSessionConfiguration(
                identifier: "com.pusherplatform.swift.upload",
                sdkHeaders: sdkInfo.headers
            ),
            delegate: self.uploadSessionDelegate,
            delegateQueue: nil
        )
        uploadURLSession.sessionDescription = "uploadURLSession"

        self.downloadSessionDelegate = PPDownloadURLSessionDelegate(insecure: insecure)

        self.downloadURLSession = URLSession(
            configuration: PPBaseClient.backgroundSessionConfiguration(
                identifier: "com.pusherplatform.swift.download",
                sdkHeaders: sdkInfo.headers
            ),
            delegate: downloadSessionDelegate,
            delegateQueue: nil
        )
        downloadURLSession.sessionDescription = "downloadURLSession"
    }

    deinit {
        self.subscriptionURLSession.invalidateAndCancel()
        self.generalRequestURLSession.invalidateAndCancel()
        self.downloadURLSession.invalidateAndCancel()
        self.uploadURLSession.invalidateAndCancel()
    }

    @discardableResult
    public func request(
        using requestOptions: PPRequestOptions,
        onSuccess: ((Data) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> PPGeneralRequest {
        var generalRequest = PPGeneralRequest()

        self.request(
            with: &generalRequest,
            using: requestOptions,
            onSuccess: onSuccess,
            onError: onError
        )
        return generalRequest
    }

    public func request(
        with generalRequest: inout PPGeneralRequest,
        using requestOptions: PPRequestOptions,
        onSuccess: ((Data) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let constructURLResult = constructURL(requestOptions)

        guard case let .success(url) = constructURLResult else {
            if case let .error(error) = constructURLResult {
                onError?(error)
            }
            return
        }

        self.logger?.log("URL for request in base client: \(url)", logLevel: .verbose)

        var request = URLRequest(url: url)
        request.httpMethod = requestOptions.method

        for (header, value) in requestOptions.headers {
            request.addValue(value, forHTTPHeaderField: header)
        }

        if self.enableTracing {
            request.addValue(UUID().uuidString, forHTTPHeaderField: "X-Client-Request-ID")
        }

        if let body = requestOptions.body {
            request.httpBody = body
        }

        let task: URLSessionDataTask = self.generalRequestURLSession.dataTask(with: request)

        let err = self.generalRequestSessionDelegate.addRequest(
            generalRequest,
            withTaskID: task.taskIdentifier
        )

        guard err == nil else {
            onError?(err!)
            return
        }

        generalRequest.options = requestOptions

        let generalRequestDelegate = generalRequest.delegate

        // Pass through logger where required
        generalRequestDelegate.logger = self.logger
        generalRequestDelegate.task = task
        generalRequestDelegate.onSuccess = onSuccess
        generalRequestDelegate.onError = onError

        task.resume()
    }

    public func requestWithRetry(
        with retryableGeneralRequest: inout PPRetryableGeneralRequest,
        using requestOptions: PPRequestOptions,
        onSuccess: ((Data) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let constructURLResult = constructURL(requestOptions)

        guard case let .success(url) = constructURLResult else {
            if case let .error(error) = constructURLResult {
                onError?(error)
            }
            return
        }

        self.logger?.log("URL for requestWithRetry in base client: \(url)", logLevel: .verbose)

        var request = URLRequest(url: url)
        request.httpMethod = requestOptions.method

        for (header, value) in requestOptions.headers {
            request.addValue(value, forHTTPHeaderField: header)
        }

        if self.enableTracing {
            request.addValue(UUID().uuidString, forHTTPHeaderField: "X-Client-Request-ID")
        }

        if let body = requestOptions.body {
            request.httpBody = body
        }

        let task: URLSessionDataTask = self.generalRequestURLSession.dataTask(with: request)

        let generalRequest = PPGeneralRequest()
        generalRequest.options = requestOptions

        let err = self.generalRequestSessionDelegate.addRequest(
            generalRequest,
            withTaskID: task.taskIdentifier
        )

        guard err == nil else {
            onError?(err!)
            return
        }

        let generalRequestDelegate = generalRequest.delegate

        generalRequestDelegate.task = task

        retryableGeneralRequest.generalRequest = generalRequest

        // Retry strategy from PPRequestOptions takes precedence, otherwise falls back to the
        // PPRetryStrategy set in the BaseClient, which is PPDefaultRetryStrategy unless
        // otherwise set
        if let reqOptionsRetryStrategy = requestOptions.retryStrategy {
            retryableGeneralRequest.retryStrategy = reqOptionsRetryStrategy
        } else {
            retryableGeneralRequest.retryStrategy = self.retryStrategyBuilder(requestOptions)
        }

        retryableGeneralRequest.onSuccess = onSuccess
        retryableGeneralRequest.onError = onError

        // Pass through logger where required
        generalRequestDelegate.logger = self.logger
        (retryableGeneralRequest.retryStrategy as? PPDefaultRetryStrategy)?.logger = self.logger

        task.resume()
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
        let constructURLResult = constructURL(requestOptions)

        guard case let .success(url) = constructURLResult else {
            if case let .error(error) = constructURLResult {
                onError?(error)
            }
            return
        }

        self.logger?.log("URL for subscribe in base client: \(url)", logLevel: .verbose)

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.SUBSCRIBE.rawValue
        request.timeoutInterval = REALLY_LONG_TIME

        for (header, value) in requestOptions.headers {
            request.addValue(value, forHTTPHeaderField: header)
        }

        if self.enableTracing {
            request.addValue(UUID().uuidString, forHTTPHeaderField: "X-Client-Request-ID")
        }

        let task: URLSessionDataTask = self.subscriptionURLSession.dataTask(with: request)

        let err = self.subscriptionSessionDelegate.addRequest(
            subscription,
            withTaskID: task.taskIdentifier
        )

        guard err == nil else {
            onError?(err!)
            return
        }

        subscription.options = requestOptions

        let subscriptionDelegate = subscription.delegate

        subscriptionDelegate.task = task
        subscriptionDelegate.requestCleanup = self.subscriptionSessionDelegate.removeRequestPairedWithTaskId

        // Pass through logger where required
        subscriptionDelegate.logger = self.logger

        subscriptionDelegate.heartbeatTimeout = Double(self.heartbeatTimeout)
        subscriptionDelegate.onOpening = onOpening
        subscriptionDelegate.onOpen = onOpen
        subscriptionDelegate.onEvent = onEvent
        subscriptionDelegate.onEnd = onEnd
        subscriptionDelegate.onError = onError

        task.resume()
    }

    public func subscribeWithResume(
        with resumableSubscription: inout PPResumableSubscription,
        using requestOptions: PPRequestOptions,
        instance: Instance,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onResuming: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let constructURLResult = constructURL(requestOptions)

        guard case let .success(url) = constructURLResult else {
            if case let .error(error) = constructURLResult {
                onError?(error)
            }
            return
        }

        self.logger?.log("URL for subscribeWithResume in base client: \(url)", logLevel: .verbose)

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.SUBSCRIBE.rawValue
        request.timeoutInterval = REALLY_LONG_TIME

        for (header, value) in requestOptions.headers {
            request.addValue(value, forHTTPHeaderField: header)
        }

        if self.enableTracing {
            request.addValue(UUID().uuidString, forHTTPHeaderField: "X-Client-Request-ID")
        }

        let task: URLSessionDataTask = self.subscriptionURLSession.dataTask(with: request)

        let subscription = PPSubscription()
        subscription.options = requestOptions

        let err = self.subscriptionSessionDelegate.addRequest(
            subscription,
            withTaskID: task.taskIdentifier
        )

        guard err == nil else {
            onError?(err!)
            return
        }

        let subscriptionDelegate = subscription.delegate

        subscriptionDelegate.requestCleanup = self.subscriptionSessionDelegate.removeRequestPairedWithTaskId
        subscriptionDelegate.task = task
        subscriptionDelegate.heartbeatTimeout = Double(self.heartbeatTimeout)

        // Retry strategy from PPRequestOptions takes precedence, otherwise falls back to the
        // PPRetryStrategy set in the BaseClient, which is PPDefaultRetryStrategy, unless
        // explicitly set to something else
        resumableSubscription.retryStrategy = requestOptions.retryStrategy ?? self.retryStrategyBuilder(requestOptions)
        resumableSubscription.subscription = subscription
        resumableSubscription.onOpening = onOpening
        resumableSubscription.onOpen = onOpen
        resumableSubscription.onResuming = onResuming
        resumableSubscription.onEvent = onEvent
        resumableSubscription.onEnd = onEnd
        resumableSubscription.onError = onError

        // Pass through logger where required
        subscriptionDelegate.logger = self.logger
        (resumableSubscription.retryStrategy as? PPDefaultRetryStrategy)?.logger = self.logger

        task.resume()
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

        self.download(
            with: &downloadRequest,
            using: requestOptions,
            to: destination,
            onSuccess: onSuccess,
            onError: onError,
            progressHandler: progressHandler
        )
        return downloadRequest
    }

    public func download(
        with downloadRequest: inout PPDownload,
        using requestOptions: PPRequestOptions,
        to destination: PPDownloadFileDestination? = nil,
        onSuccess: ((URL) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        progressHandler: ((Int64, Int64) -> Void)? = nil
    ) {
        // TODO: Should this all be done on an async queue?
        let constructURLResult = constructURL(requestOptions)

        guard case let .success(url) = constructURLResult else {
            if case let .error(error) = constructURLResult {
                onError?(error)
            }
            return
        }

        self.logger?.log("URL for download in base client: \(url)", logLevel: .verbose)

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.GET.rawValue

        for (header, value) in requestOptions.headers {
            request.addValue(value, forHTTPHeaderField: header)
        }

        if self.enableTracing {
            request.addValue(UUID().uuidString, forHTTPHeaderField: "X-Client-Request-ID")
        }

        let task: URLSessionDownloadTask = self.downloadURLSession.downloadTask(with: request)

        let err = self.downloadSessionDelegate.addRequest(
            downloadRequest,
            withTaskID: task.taskIdentifier
        )

        guard err == nil else {
            onError?(err!)
            return
        }

        downloadRequest.options = requestOptions

        let downloadDelegate = downloadRequest.delegate

        // Pass through logger where required
        downloadDelegate.logger = self.logger
        downloadDelegate.task = task
        downloadDelegate.onSuccess = onSuccess
        downloadDelegate.onError = onError
        downloadDelegate.destination = destination
        downloadDelegate.progressHandler = progressHandler

        task.resume()
    }

    @discardableResult
    public func upload(
        using requestOptions: PPRequestOptions,
        multipartFormData: @escaping (PPMultipartFormData) -> Void,
        onSuccess: ((Data) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        progressHandler: ((Int64, Int64) -> Void)? = nil
    ) -> PPUpload {
        var uploadRequest = PPUpload()

        self.upload(
            with: &uploadRequest,
            using: requestOptions,
            multipartFormData: multipartFormData,
            onSuccess: onSuccess,
            onError: onError,
            progressHandler: progressHandler
        )
        return uploadRequest
    }

    public func upload(
        with uploadRequest: inout PPUpload,
        using requestOptions: PPRequestOptions,
        multipartFormData: @escaping (PPMultipartFormData) -> Void,
        onSuccess: ((Data) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        progressHandler: ((Int64, Int64) -> Void)? = nil
    ) {
        // TODO: Should this all be done on an async queue?
        let constructURLResult = constructURL(requestOptions)

        guard case let .success(url) = constructURLResult else {
            if case let .error(error) = constructURLResult {
                onError?(error)
            }
            return
        }

        self.logger?.log("URL for upload in base client: \(url)", logLevel: .verbose)

        var request = URLRequest(url: url)
        request.httpMethod = requestOptions.method

        for (header, value) in requestOptions.headers {
            request.addValue(value, forHTTPHeaderField: header)
        }

        if self.enableTracing {
            request.addValue(UUID().uuidString, forHTTPHeaderField: "X-Client-Request-ID")
        }

        let formData = PPMultipartFormData()
        multipartFormData(formData)

        var tempFileURL: URL?

        do {
            request.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")

            // TODO: Do we want to have a version that does everything in memory? It wouldn't
            // work with background sessions (at least not reliably) but is going to be a good
            // deal quicker than writing out a file etc

           // let isBackgroundSession = self.session.configuration.identifier != nil
           // let multipartFormDataEncodingMemoryThreshold: UInt64 = 10_000_000
           // let encodingMemoryThreshold = multipartFormDataEncodingMemoryThreshold

            let fileManager = FileManager.default
            let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            let directoryURL = tempDirectoryURL.appendingPathComponent("com.pusherplatform.swift.multipart.form.data")
            let fileName = UUID().uuidString
            let fileURL = directoryURL.appendingPathComponent(fileName)

            tempFileURL = fileURL

            var directoryError: Error?

            // Create directory inside serial queue to ensure two threads don't do this in parallel
            self.uploadQueue.sync {
                do {
                    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    directoryError = error
                }
            }

            if let directoryError = directoryError { throw directoryError }

            try formData.writeEncodedData(to: fileURL)

            let task: URLSessionUploadTask = self.uploadURLSession.uploadTask(
                with: request,
                fromFile: fileURL
            )

            let wrappedOnSuccess = fileRemoverWrapper(fileURL: fileURL, onSuccess)
            let wrappedOnError = fileRemoverWrapper(fileURL: fileURL, onError)

            let err = self.uploadSessionDelegate.addRequest(
                uploadRequest,
                withTaskID: task.taskIdentifier
            )

            guard err == nil else {
                onError?(err!)
                return
            }

            uploadRequest.options = requestOptions

            let uploadDelegate = uploadRequest.delegate

            // Pass through logger where required
            uploadDelegate.logger = self.logger
            uploadDelegate.task = task
            uploadDelegate.onSuccess = wrappedOnSuccess
            uploadDelegate.onError = wrappedOnError
            uploadDelegate.progressHandler = progressHandler

            task.resume()
        } catch {
            // Cleanup the temp file in the event that the multipart form data encoding failed
            if let tempFileURL = tempFileURL {
                do {
                    try FileManager.default.removeItem(at: tempFileURL)
                } catch {
                    // No-op
                }
            }

            // TODO: Can this be dispatched on any queue?
            onError?(error)
        }
    }

    func fileRemoverWrapper<T>(fileURL: URL, _ inputClosure: ((T) -> Void)?) -> (T) -> Void {
        return { (input: T) in
            self.uploadCleanupQueue.async(flags: .barrier) {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    self.logger?.log("Cleaned up temp file at \(fileURL.absoluteString) after upload", logLevel: .verbose)
                } catch {
                    // No-op
                    self.logger?.log("Failed to clean up temp file at \(fileURL.absoluteString) after upload", logLevel: .verbose)
                }
            }

            inputClosure?(input)
        }
    }

    // TODO: Maybe need the same for cancelling general requests?
    public func unsubscribe(taskIdentifier: Int, completionHandler: ((Error?) -> Void)? = nil) -> Void {
        self.subscriptionURLSession.getAllTasks { tasks in
            guard let task = tasks.first(where: { $0.taskIdentifier == taskIdentifier }) else {
                completionHandler?(
                    PPBaseClientError.noTaskWithMatchingTaskIdentifierFound(
                        taskId: taskIdentifier,
                        session: self.subscriptionURLSession
                    )
                )
                return
            }

            task.cancel()
            completionHandler?(nil)
        }
    }

    enum URLConstructionResult {
        case success(URL)
        case error(_: PPBaseClientError)
    }

    fileprivate func constructURL(_ options: PPRequestOptions) -> URLConstructionResult {
        var urlComponents: URLComponents

        switch options.destination {
        case .relative(let path):
            guard let pathComponents = URLComponents(string: path) else {
                return .error(PPBaseClientError.invalidPath(path))
            }

            urlComponents = self.baseUrlComponents
            urlComponents.percentEncodedPath = pathComponents.percentEncodedPath

            if let pathQueryItems = pathComponents.queryItems {
                urlComponents.queryItems = pathQueryItems
            }
        case .absolute(let url):
            guard let components = URLComponents(string: url) else {
                self.logger?.log(
                    "Invalid URL provided for request in base client: \(url)",
                    logLevel: .verbose
                )
                return .error(PPBaseClientError.invalidRawURL(url))
            }

            urlComponents = components
        }

        var optionsQueryItemsComponents = URLComponents()

        if options.queryItems.count > 0 {
            optionsQueryItemsComponents.queryItems = options.queryItems
        }

        if let optionsQueryString = optionsQueryItemsComponents.percentEncodedQuery {
            if let query = urlComponents.percentEncodedQuery {
                urlComponents.percentEncodedQuery = "\(query)&\(optionsQueryString)"
            } else {
                urlComponents.percentEncodedQuery = optionsQueryString
            }
        }

        self.logger?.log(
            "URLComponents for request in base client: \(urlComponents.debugDescription)",
            logLevel: .verbose
        )

        guard let url = urlComponents.url else {
            return .error(PPBaseClientError.invalidURL(components: urlComponents))
        }

        return .success(url)
    }

    fileprivate static func backgroundSessionConfiguration(
        identifier: String,
        sdkHeaders: [String: String]
    ) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.background(
            withIdentifier: "\(identifier).\(UUID().uuidString)"
        )

        config.httpAdditionalHeaders = sdkHeaders
        return config
    }

    static public func methodAwareRetryStrategyGenerator(requestOptions: PPRequestOptions) -> PPRetryStrategy {
        if let httpMethod = HTTPMethod(rawValue: requestOptions.method) {
            switch httpMethod {
            case .POST, .PUT, .PATCH:
                return PPDefaultRetryStrategy(maxNumberOfAttempts: 1)
            default:
                break
            }
        }
        return PPDefaultRetryStrategy()
    }
}

internal enum PPBaseClientError: Error {
    case invalidPath(_: String)
    case invalidRawURL(_: String)
    case invalidURL(components: URLComponents)
    case preExistingTaskIdentifierForRequest
    case noTaskWithMatchingTaskIdentifierFound(taskId: Int, session: URLSession)
}

extension PPBaseClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .invalidRawURL(let url):
            return "Invalid URL: \(url)"
        case .invalidURL(let components):
            return "Invalid URL from components: \(components.debugDescription)"
        case .preExistingTaskIdentifierForRequest:
            return "Task identifier already in use for another request"
        case .noTaskWithMatchingTaskIdentifierFound(let taskId, let urlSession):
            return "No task with id \(taskId) for URLSession: \(urlSession.debugDescription)"
        }
    }
}

public enum HTTPMethod: String {
    case POST
    case GET
    case PUT
    case DELETE
    case OPTIONS
    case PATCH
    case HEAD
    case SUBSCRIBE
}
