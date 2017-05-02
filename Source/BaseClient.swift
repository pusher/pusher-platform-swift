import Foundation

let REALLY_LONG_TIME: Double = 252_460_800

@objc public class BaseClient: NSObject {
    public var port: Int?
    internal var baseUrlComponents: URLComponents

    // The subscriptionURLSession requires a different URLSessionConfiguration, which
    // is why it is separated from the generalRequestURLSession
    public let subscriptionURLSession: URLSession

    public let generalRequestURLSession: URLSession

    public let sessionDelegate: PPSessionDelegate

    // Should be between 30 and 300
    public let heartbeatTimeout: Int

    // Should be between 0 and 10240 (to avoid 422 response) but URLSession
    // seems to need 512+ bytes to ensure that it calls didReceiveResponse
    public let heartbeatInitialSize: Int

    // Set to true if you want to trust all certificates
    public let insecure: Bool

    // TODO: Finish explaining how it works

    // If you want to provide
    public var retryStrategyBuilder: (() -> PPRetryStrategy)?

    // TODO: Need to actually use these
    public var clientName: String
    public var clientVersion: String

    public init(
        cluster: String? = nil,
        port: Int? = nil,
        insecure: Bool = false,
        clientName: String = "pusher-platform-swift",
        clientVersion: String = "0.1.4",

        // TODO: @autoclosure ?
        retryStrategyBuilder: (() -> PPRetryStrategy)? = nil,
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

        self.sessionDelegate = PPSessionDelegate(insecure: insecure)

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

    public func request(using requestOptions: PPRequestOptions, completionHandler: @escaping (Result<Data>) -> Void) {
        var mutableURLComponents = self.baseUrlComponents
        mutableURLComponents.queryItems = requestOptions.queryItems

        guard var url = mutableURLComponents.url else {
            completionHandler(.failure(BaseClientError.invalidUrl(components: mutableURLComponents)))
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
//            onError?(BaseClientError.preExistingTaskIdentifierForSubscription)
            return
        }

        if requestOptions.retryStrategy == nil {
            requestOptions.retryStrategy = PPDefaultRetryStrategy()
        }

        let generalRequest = PPRequest(type: .general)

        // TODO: Probably move this to initializer

        generalRequest.options = requestOptions


        self.sessionDelegate[task] = generalRequest

        if let generalRequestDelegate = generalRequest.delegate as? PPGeneralRequestDelegate {
            generalRequestDelegate.task = task
            generalRequestDelegate.completionHandler = completionHandler
        } else {
            // TODO: What the fuck can we do?!
        }

        task.resume()

//        TODO: Do we want to return anything?

//        return request?
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
            // TODO: Maybe defer calling onError until after returning?

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
            onError?(BaseClientError.preExistingTaskIdentifierForSubscription)
            return
        }

        self.sessionDelegate[task] = subscription

        subscription.options = requestOptions

        if let subscriptionDelegate = subscription.delegate as? PPSubscriptionDelegate {
            subscriptionDelegate.task = task
            subscriptionDelegate.heartbeatTimeout = Double(self.heartbeatTimeout)
            subscriptionDelegate.onOpening = onOpening
            subscriptionDelegate.onOpen = onOpen
            subscriptionDelegate.onEvent = onEvent
            subscriptionDelegate.onEnd = onEnd
            subscriptionDelegate.onError = onError
        } else {
            // TODO: What the fuck can we do?!
        }

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
            onError?(BaseClientError.preExistingTaskIdentifierForSubscription)
            return
        }

        let subscription = PPRequest(type: .subscription)

        subscription.options = requestOptions

        self.sessionDelegate[task] = subscription

        if let subscriptionDelegate = subscription.delegate as? PPSubscriptionDelegate {
            subscriptionDelegate.task = task
            subscriptionDelegate.heartbeatTimeout = Double(self.heartbeatTimeout)
        } else {
            // TODO: What the fuck can we do?!
        }

        resumableSubscription.subscription = subscription

        resumableSubscription.onOpening = onOpening
        resumableSubscription.onOpen = onOpen
        resumableSubscription.onResuming = onResuming
        resumableSubscription.onEvent = onEvent
        resumableSubscription.onEnd = onEnd
        resumableSubscription.onError = onError

        task.resume()
    }

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
}

// TODO: LocalizedError

public enum BaseClientError: Error {
    case invalidUrl(components: URLComponents)
    case preExistingTaskIdentifierForSubscription
    case noTasksForSubscriptionUrlSession(URLSession)
    case noTaskWithMatchingTaskIdentifierFound(taskId: Int, session: URLSession)
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
