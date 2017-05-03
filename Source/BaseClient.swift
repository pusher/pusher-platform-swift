import Foundation

let REALLY_LONG_TIME: Double = 252_460_800

@objc public class BaseClient: NSObject {
    public var port: Int?
    internal var baseUrlComponents: URLComponents

    // The subscriptionURLSession requires a different URLSessionConfiguration, which
    // is why it is separated from the generalRequestURLSession
    public let subscriptionURLSession: URLSession

    public let generalRequestURLSession: URLSession

    public let sessionDelegate: PPURLSessionDelegate

    public var logger: PPLogger? = nil {
        willSet {
            self.sessionDelegate.logger = newValue
        }
    }

    // Should be between 30 and 300
    public let heartbeatTimeout: Int

    // Should be between 0 and 10240 (to avoid 422 response) but URLSession
    // seems to need 512+ bytes to ensure that it calls didReceiveResponse
    public let heartbeatInitialSize: Int

    // Set to true if you want to trust all certificates
    public let insecure: Bool

    // If you want to provide a closure that builds a PPRetryStrategy based on
    // a request's options then you can use this property
    public var retryStrategyBuilder: (PPRequestOptions) -> PPRetryStrategy

    public var clientName: String
    public var clientVersion: String

    public init(
        cluster: String? = nil,
        port: Int? = nil,
        insecure: Bool = false,
        clientName: String = "pusher-platform-swift",
        clientVersion: String = "0.1.4",
        retryStrategyBuilder: @escaping (PPRequestOptions) -> PPRetryStrategy = BaseClient.methodAwareRetryStrageyGenerator,
        heartbeatTimeoutInterval: Int = 60,
        heartbeatInitialSize: Int = 512
    ) {
        let cluster = cluster ?? "api.private-beta-1.pusherplatform.com"

        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = cluster
        urlComponents.port = port

        self.baseUrlComponents = urlComponents
        self.insecure = insecure
        self.clientName = clientName
        self.clientVersion = clientVersion
        self.retryStrategyBuilder = retryStrategyBuilder
        self.heartbeatTimeout = heartbeatTimeoutInterval
        self.heartbeatInitialSize = heartbeatInitialSize

        let subscriptionSessionConfiguration = URLSessionConfiguration.default
        subscriptionSessionConfiguration.timeoutIntervalForResource = REALLY_LONG_TIME
        subscriptionSessionConfiguration.timeoutIntervalForRequest = REALLY_LONG_TIME
        subscriptionSessionConfiguration.httpAdditionalHeaders = [
            "X-Heartbeat-Interval": String(self.heartbeatTimeout),
            "X-Initial-Heartbeat-Size": String(self.heartbeatInitialSize)
        ]

        self.sessionDelegate = PPURLSessionDelegate(insecure: insecure)

        self.subscriptionURLSession = URLSession(
            configuration: subscriptionSessionConfiguration,
            delegate: self.sessionDelegate,
            delegateQueue: nil
        )

        self.generalRequestURLSession = URLSession(
            configuration: .default,
            delegate: self.sessionDelegate,
            delegateQueue: nil
        )
    }

    deinit {
        self.subscriptionURLSession.invalidateAndCancel()
        self.generalRequestURLSession.invalidateAndCancel()
    }

    public func request(
        with generalRequest: inout PPRequest,
        using requestOptions: PPRequestOptions,
        onSuccess: ((Data) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        var mutableURLComponents = self.baseUrlComponents
        mutableURLComponents.queryItems = requestOptions.queryItems

        guard var url = mutableURLComponents.url else {
            onError?(BaseClientError.invalidUrl(components: mutableURLComponents))
            return
        }

        url = url.appendingPathComponent(requestOptions.path)

        var request = URLRequest(url: url)
        request.httpMethod = requestOptions.method

        for (header, value) in requestOptions.headers {
            request.addValue(value, forHTTPHeaderField: header)
        }

        if let body = requestOptions.body {
            request.httpBody = body
        }

        let task: URLSessionDataTask = self.generalRequestURLSession.dataTask(with: request)

        guard self.sessionDelegate[task] == nil else {
            onError?(BaseClientError.preExistingTaskIdentifierForRequest)
            return
        }

        self.sessionDelegate[task] = generalRequest

        generalRequest.options = requestOptions

        guard let generalRequestDelegate = generalRequest.delegate as? PPGeneralRequestDelegate else {
            onError?(BaseClientError.requestHasInvalidDelegate(request: generalRequest, delegate: generalRequest.delegate))
            return
        }

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
        onError: ((Error) -> Void)? = nil,
        onRetry: ((Error?) -> Void)? = nil
    ) {
        var mutableURLComponents = self.baseUrlComponents
        mutableURLComponents.queryItems = requestOptions.queryItems

        guard var url = mutableURLComponents.url else {
            onError?(BaseClientError.invalidUrl(components: mutableURLComponents))
            return
        }

        url = url.appendingPathComponent(requestOptions.path)

        var request = URLRequest(url: url)
        request.httpMethod = requestOptions.method

        for (header, value) in requestOptions.headers {
            request.addValue(value, forHTTPHeaderField: header)
        }

        if let body = requestOptions.body {
            request.httpBody = body
        }

        let task: URLSessionDataTask = self.generalRequestURLSession.dataTask(with: request)

        guard self.sessionDelegate[task] == nil else {
            onError?(BaseClientError.preExistingTaskIdentifierForRequest)
            return
        }

        let generalRequest = PPRequest(type: .general)
        generalRequest.options = requestOptions

        self.sessionDelegate[task] = generalRequest

        guard let generalRequestDelegate = generalRequest.delegate as? PPGeneralRequestDelegate else {
            onError?(BaseClientError.requestHasInvalidDelegate(request: generalRequest, delegate: generalRequest.delegate))
            return
        }

        generalRequestDelegate.task = task

        retryableGeneralRequest.generalRequest = generalRequest

        // Retry strategy from PPRequestOptions takes precedent, otherwise falls back to the
        // PPRetryStrategy set in the BaseClient, which is PPDefaultRetryStrategy unless
        // otherwise set
        if let reqOptionsRetryStrategy = requestOptions.retryStrategy {
            retryableGeneralRequest.retryStrategy = reqOptionsRetryStrategy
        } else {
            retryableGeneralRequest.retryStrategy = self.retryStrategyBuilder(requestOptions)
        }

        retryableGeneralRequest.onSuccess = onSuccess
        retryableGeneralRequest.onError = onError
        retryableGeneralRequest.onRetry = onRetry

        // Pass through logger where required
        generalRequestDelegate.logger = self.logger
        retryableGeneralRequest.logger = self.logger
        (retryableGeneralRequest.retryStrategy as? PPDefaultRetryStrategy)?.logger = self.logger

        task.resume()
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
        var mutableURLComponents = self.baseUrlComponents
        mutableURLComponents.queryItems = requestOptions.queryItems

        guard var url = mutableURLComponents.url else {
            onError?(BaseClientError.invalidUrl(components: mutableURLComponents))
            return
        }

        url = url.appendingPathComponent(requestOptions.path)

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.SUBSCRIBE.rawValue
        request.timeoutInterval = REALLY_LONG_TIME

        for (header, value) in requestOptions.headers {
            request.addValue(value, forHTTPHeaderField: header)
        }

        let task: URLSessionDataTask = self.subscriptionURLSession.dataTask(with: request)

        guard self.sessionDelegate[task] == nil else {
            onError?(BaseClientError.preExistingTaskIdentifierForRequest)
            return
        }

        self.sessionDelegate[task] = subscription

        subscription.options = requestOptions

        guard let subscriptionDelegate = subscription.delegate as? PPSubscriptionDelegate else {
            onError?(BaseClientError.requestHasInvalidDelegate(request: subscription, delegate: subscription.delegate))
            return
        }

        subscriptionDelegate.task = task

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
        with resumableSubscription: inout ResumableSubscription,
        using requestOptions: PPRequestOptions,
        app: App,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onResuming: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        var mutableURLComponents = self.baseUrlComponents
        mutableURLComponents.queryItems = requestOptions.queryItems

        guard var url = mutableURLComponents.url else {
            onError?(BaseClientError.invalidUrl(components: mutableURLComponents))
            return
        }

        url = url.appendingPathComponent(requestOptions.path)

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.SUBSCRIBE.rawValue
        request.timeoutInterval = REALLY_LONG_TIME

        for (header, value) in requestOptions.headers {
            request.addValue(value, forHTTPHeaderField: header)
        }

        let task: URLSessionDataTask = self.subscriptionURLSession.dataTask(with: request)

        guard self.sessionDelegate[task] == nil else {
            onError?(BaseClientError.preExistingTaskIdentifierForRequest)
            return
        }

        let subscription = PPRequest(type: .subscription)

        subscription.options = requestOptions

        self.sessionDelegate[task] = subscription

        guard let subscriptionDelegate = subscription.delegate as? PPSubscriptionDelegate else {
            onError?(BaseClientError.requestHasInvalidDelegate(request: subscription, delegate: subscription.delegate))
            return
        }

        subscriptionDelegate.task = task
        subscriptionDelegate.heartbeatTimeout = Double(self.heartbeatTimeout)

        // Retry strategy from PPRequestOptions takes precedent, otherwise falls back to the
        // PPRetryStrategy set in the BaseClient, which is PPDefaultRetryStrategy unless
        // otherwise set
        if let reqOptionsRetryStrategy = requestOptions.retryStrategy {
            resumableSubscription.retryStrategy = reqOptionsRetryStrategy
        } else {
            resumableSubscription.retryStrategy = self.retryStrategyBuilder(requestOptions)
        }

        resumableSubscription.subscription = subscription
        resumableSubscription.onOpening = onOpening
        resumableSubscription.onOpen = onOpen
        resumableSubscription.onResuming = onResuming
        resumableSubscription.onEvent = onEvent
        resumableSubscription.onEnd = onEnd
        resumableSubscription.onError = onError

        // Pass through logger where required
        subscriptionDelegate.logger = self.logger
        resumableSubscription.logger = self.logger
        (resumableSubscription.retryStrategy as? PPDefaultRetryStrategy)?.logger = self.logger

        task.resume()
    }

    // TODO: Maybe need the same for cancelling general requests?

    // TODO: Look at this

    public func unsubscribe(taskIdentifier: Int, completionHandler: ((Result<Bool>) -> Void)? = nil) -> Void {
        self.subscriptionURLSession.getAllTasks { tasks in
            guard tasks.count > 0 else {
                completionHandler?(.failure(BaseClientError.noTasksForSubscriptionUrlSession(self.subscriptionURLSession)))
                return
            }

            let filteredTasks = tasks.filter { $0.taskIdentifier == taskIdentifier }

            guard filteredTasks.count == 1 else {
                completionHandler?(.failure(BaseClientError.noTaskWithMatchingTaskIdentifierFound(taskId: taskIdentifier, session: self.subscriptionURLSession)))
                return
            }

            filteredTasks.first!.cancel()
            completionHandler?(.success(true))
        }
    }

    static public func methodAwareRetryStrageyGenerator(requestOptions: PPRequestOptions) -> PPRetryStrategy {
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

// TODO: LocalizedError

internal enum BaseClientError: Error {
    case invalidUrl(components: URLComponents)
    case preExistingTaskIdentifierForRequest
    case noTasksForSubscriptionUrlSession(URLSession)
    case noTaskWithMatchingTaskIdentifierFound(taskId: Int, session: URLSession)
    case requestHasInvalidDelegate(request: PPRequest, delegate: PPRequestTaskDelegate)
}

//extension BaseClientError: LocalizedError {
//    public var errorDescription: String? {
//        switch self {
//        case .invalidUrl(let components):
//
//        }
//    }
//}

public enum RequestError: Error {
    case invalidHttpResponse(response: URLResponse?, data: Data?)
    case badResponseStatusCode(response: HTTPURLResponse)
    case badResponseStatusCodeWithMessage(response: HTTPURLResponse, errorMessage: String)
    case noDataPresent
}

public enum SubscriptionError: Error {
    case unexpectedError
    case heartbeatTimeoutReached
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
