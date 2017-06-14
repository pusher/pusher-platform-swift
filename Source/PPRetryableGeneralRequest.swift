import Foundation

// TODO: Rename, maybe?

@objc public class PPRetryableGeneralRequest: NSObject {
    public let requestOptions: PPRequestOptions
    public internal(set) var app: App
    public internal(set) var generalRequest: PPRequest? = nil
    public var retryStrategy: PPRetryStrategy? = nil
    internal var retryRequestTimer: Timer? = nil

    public var onSuccess: ((Data) -> Void)? {
        willSet {
            guard let generalRequestDelegate = self.generalRequest?.delegate as? PPGeneralRequestDelegate else {
                self.app.logger.log(
                    "Invalid delegate for general request: \(String(describing: self.generalRequest))",
                    logLevel: .error
                )
                return
            }

            generalRequestDelegate.onSuccess = { [weak self] data in
                guard let strongSelf = self else {
                    print("self is nil when trying to handle onSuccess in general request delegate")
                    return
                }

                strongSelf.handleOnSuccess(data)
                newValue?(data)
            }
        }
    }

    internal var _onError: ((Error) -> Void)? = nil

    public var onError: ((Error) -> Void)? {
        willSet {
            guard let generalRequestDelegate = self.generalRequest?.delegate as? PPGeneralRequestDelegate else {
                self.app.logger.log(
                    "Invalid delegate for general request: \(String(describing: self.generalRequest))",
                    logLevel: .error
                )
                return
            }

            generalRequestDelegate.onError = { [weak self] error in
                guard let strongSelf = self else {
                    print("self is nil when trying to handle onError in general request delegate")
                    return
                }

                strongSelf.handleOnError(error: error)
            }

            self._onError = newValue
        }
    }

    public init(app: App, requestOptions: PPRequestOptions) {
        self.app = app
        self.requestOptions = requestOptions
    }

    deinit {
        self.retryRequestTimer?.invalidate()
    }

    // TODO: Is this necessary in general?
    public func handleOnSuccess(_ data: Data) {}

    public func handleOnError(error: Error) {
//        TODO: Do we need something like this?

//        guard !self.cancelled else {
//            // TODO: Really? Does this make sense?
//            self.changeState(to: .ended)
//            return
//        }

        guard let retryStrategy = self.retryStrategy else {
            self.app.logger.log("Not attempting retry because no retry strategy is set", logLevel: .debug)
            self._onError?(PPRetryableError.noRetryStrategyProvided)
            return
        }

//         TODO: Check which errors to pass to RetryStrategy

        self.retryRequestTimer?.invalidate()

        let shouldRetryResult = retryStrategy.shouldRetry(given: error)

        switch shouldRetryResult {
        case .retry(let retryWaitTimeInterval):
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else {
                    print("self is nil when setting up retry subscription timer")
                    return
                }

                strongSelf.retryRequestTimer = Timer.scheduledTimer(
                    timeInterval: retryWaitTimeInterval,
                    target: strongSelf,
                    selector: #selector(strongSelf.retryRequest),
                    userInfo: nil,
                    repeats: false
                )
            }
        case .doNotRetry(let reasonErr):
            self._onError?(reasonErr)
        }
    }

    internal func retryRequest() {
        guard let generalRequestDelegate = self.generalRequest?.delegate as? PPGeneralRequestDelegate else {
            self.app.logger.log(
                "Invalid delegate for general request: \(String(describing: self.generalRequest))",
                logLevel: .error
            )
            return
        }

        self.app.logger.log("Cancelling subscriptionDelegate's existing task", logLevel: .verbose)
        generalRequestDelegate.task?.cancel()

        self.app.logger.log("Creating new underlying request for retrying", logLevel: .debug)

        let newRequest = self.app.request(
            using: self.requestOptions,
            onSuccess: generalRequestDelegate.onSuccess,
            onError: generalRequestDelegate.onError
        )

        self.generalRequest = newRequest
    }
}
