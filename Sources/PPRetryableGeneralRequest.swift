import Foundation

// TODO: Rename, maybe?

@objc public class PPRetryableGeneralRequest: NSObject {
    public let requestOptions: PPRequestOptions
    public internal(set) unowned var instance: Instance
    public internal(set) var generalRequest: PPGeneralRequest? = nil
    public var retryStrategy: PPRetryStrategy? = nil
    internal var retryRequestTimer: PPRepeater? = nil

    public var onSuccess: ((Data) -> Void)? {
        willSet {
            guard let generalRequestDelegate = self.generalRequest?.delegate else {
                self.instance.logger.log(
                    "No delegate for general request: \(self.generalRequest.debugDescription))",
                    logLevel: .error
                )
                return
            }

            // TODO: Not using a weak self here because a request, unlike a subscription,
            // is not expected to be referenced and stored for its lifecycle, so we do in
            // fact want to capture self here - this isn't ideal though, so we need a
            // better way of handling with cleanup. Could just be a function that gets
            // called after success / error and sets the onSuccess and onError closures
            // on the delegate to be nil so that the references to this are gone
            generalRequestDelegate.onSuccess = { data in
                self.handleOnSuccess(data)
                newValue?(data)
            }
        }
    }

    internal var _onError: ((Error) -> Void)? = nil

    public var onError: ((Error) -> Void)? {
        willSet {
            guard let generalRequestDelegate = self.generalRequest?.delegate else {
                self.instance.logger.log(
                    "No delegate for general request: \(self.generalRequest.debugDescription))",
                    logLevel: .error
                )
                return
            }

            // TODO: Not using a weak self here because a request, unlike a subscription,
            // is notexpected to be referenced and stored for its lifecycle, so we do in
            // fact want to capture self here - this isn't ideal though, so we need a
            // better way of handling with cleanup. Could just be a function that gets
            // called after success / error and sets the onSuccess and onError closures
            // on the delegate to be nil so that the references to this are gone
            generalRequestDelegate.onError = { error in
                self.handleOnError(error: error)
            }

            self._onError = newValue
        }
    }

    public init(instance: Instance, requestOptions: PPRequestOptions) {
        self.instance = instance
        self.requestOptions = requestOptions
    }

    deinit {
        self.retryRequestTimer = nil
    }

    public func handleOnSuccess(_ data: Data) {
        self.retryRequestTimer = nil
    }

    public func handleOnError(error: Error) {
        // TODO: Do we need something like this?

//        guard !self.cancelled else {
//            // TODO: Really? Does this make sense?
//            self.changeState(to: .ended)
//            return
//        }

        guard let retryStrategy = self.retryStrategy else {
            self.instance.logger.log("Not attempting retry because no retry strategy is set", logLevel: .debug)
            self._onError?(PPRetryableError.noRetryStrategyProvided)
            return
        }

        // TODO: Check which errors to pass to RetryStrategy

        self.retryRequestTimer = nil

        let shouldRetryResult = retryStrategy.shouldRetry(given: error)

        switch shouldRetryResult {
        case .retry(let retryWaitTimeInterval):
            self.retryRequestTimer = PPRepeater.once(
                after: .seconds(retryWaitTimeInterval)
            ) { [weak self] _ in
                guard let strongSelf = self else {
                    print("self is nil when setting up retry request timer")
                    return
                }

                strongSelf.retryRequest()
            }
        case .doNotRetry(let reasonErr):
            self._onError?(reasonErr)
        }
    }

    internal func retryRequest() {
        guard let generalRequestDelegate = self.generalRequest?.delegate else {
            self.instance.logger.log(
                "No delegate for general request: \(self.generalRequest.debugDescription))",
                logLevel: .error
            )
            return
        }

        self.instance.logger.log("Cancelling subscriptionDelegate's existing task", logLevel: .verbose)
        generalRequestDelegate.task?.cancel()

        self.instance.logger.log("Creating new underlying request for retrying", logLevel: .debug)

        let newRequest = self.instance.request(
            using: self.requestOptions,
            onSuccess: generalRequestDelegate.onSuccess,
            onError: generalRequestDelegate.onError
        )

        self.generalRequest = newRequest
    }
}
