import Foundation

// TODO: Rename, maybe?

@objc public class PPRetryableGeneralRequest: NSObject {
    public let requestOptions: PPRequestOptions
    public internal(set) unowned var instance: Instance
    public internal(set) var generalRequest: PPGeneralRequest? = nil
    public var retryStrategy: PPRetryStrategy? = nil
    internal var retryRequestTimer: PPRepeater? = nil

    internal var _onSuccess: ((Data) -> Void)? = nil

    public var onSuccess: ((Data) -> Void)? {
        willSet {
            guard let generalRequestDelegate = self.generalRequest?.delegate else {
                self.instance.logger.log(
                    "No delegate for general request: \(self.generalRequest.debugDescription))",
                    logLevel: .error
                )
                return
            }

            // Not using a weak self here because a request, unlike a subscription, is
            // not expected to be referenced and stored for its lifecycle, so we do in
            // fact want to capture self here - this isn't ideal though. What we have
            // to do is after the request has succeeded / errored, the onSuccess and
            // onError closures on the delegate get set to nil so that the references
            // to this are gone. If we want to allow request cancellation, for example,
            // then the consumer of this SDK would likely be responsible for storing
            // this PPRetryableGeneralRequest object (like we expect the consumer of
            // PPResumableSubscriptions to store them) and so we could change the
            // contract at that point so that it's then their responsibility to hold
            // on to the request for as long as they want / need to. At that point
            // we'd be able to stop taking a strong reference to self here, as well
            // as then not being required to nil out the onSuccess and onError closures
            // in the handleCompletion function of the delegate.
            generalRequestDelegate.onSuccess = { data in
                self.handleOnSuccess(data)
            }

            self._onSuccess = newValue
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

            // Not using a weak self here because a request, unlike a subscription, is
            // not expected to be referenced and stored for its lifecycle, so we do in
            // fact want to capture self here - this isn't ideal though. What we have
            // to do is after the request has succeeded / errored, the onSuccess and
            // onError closures on the delegate get set to nil so that the references
            // to this are gone. If we want to allow request cancellation, for example,
            // then the consumer of this SDK would likely be responsible for storing
            // this PPRetryableGeneralRequest object (like we expect the consumer of
            // PPResumableSubscriptions to store them) and so we could change the
            // contract at that point so that it's then their responsibility to hold
            // on to the request for as long as they want / need to. At that point
            // we'd be able to stop taking a strong reference to self here, as well
            // as then not being required to nil out the onSuccess and onError closures
            // in the handleCompletion function of the delegate.
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
        self._onSuccess?(data)
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
