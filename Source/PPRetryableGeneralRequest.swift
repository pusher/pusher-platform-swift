import Foundation

// TODO: Rename

@objc public class PPRetryableGeneralRequest: NSObject {
    public let requestOptions: PPRequestOptions
    public internal(set) var app: App
    public internal(set) var generalRequest: PPRequest? = nil
    public var retryStrategy: PPRetryStrategy? = nil
    public var logger: PPLogger? = nil
    internal var retryRequestTimer: Timer? = nil

    public var onSuccess: ((Data) -> Void)? {
        willSet {
            guard let generalRequestDelegate = self.generalRequest?.delegate as? PPGeneralRequestDelegate else {
                self.logger?.log(
                    "Invalid delegate for general request: \(String(describing: self.generalRequest))",
                    logLevel: .error
                )
                return
            }

            generalRequestDelegate.onSuccess = { data in
                self.handleOnSuccess(data)
                newValue?(data)
            }
        }
    }

    public var onError: ((Error) -> Void)? {
        willSet {
            guard let generalRequestDelegate = self.generalRequest?.delegate as? PPGeneralRequestDelegate else {
                self.logger?.log(
                    "Invalid delegate for general request: \(String(describing: self.generalRequest))",
                    logLevel: .error
                )
                return
            }

            generalRequestDelegate.onError = { error in
                self.handleOnError(error: error)
                newValue?(error)
            }
        }
    }

    // TODO: Figure out when / if this should be used

    public var onRetry: ((Error?) -> Void)?


    public init(app: App, requestOptions: PPRequestOptions) {
        self.app = app
        self.requestOptions = requestOptions
    }

    deinit {
        self.retryRequestTimer?.invalidate()
    }

    // TODO: What is this doing?
    public func handleOnSuccess(_ data: Data) {}

    public func handleOnError(error: Error) {

        // TODO: Check how many times this can be called
        // TODO: Check which errors to pass to RetryStrategy

        // TODO: not always retrying - need to figure out what to do here.
        // We need to be able to differentiate between a recoverable error and
        // errors that mean we need to stop attempting the request
        // Do we therefore also need to setup a onProperEnd (not the real name suggestion)?
        // Then we'd set the state to failed and not try and create a new request?

//        TODO: Do we need something like this?

//        guard !self.cancelled else {
//            // TODO: Really? Does this make sense?
//            self.changeState(to: .ended)
//            return
//        }

        guard let retryStrategy = self.retryStrategy else {
            self.logger?.log("Not attempting retry because no retry strategy is set", logLevel: .debug)
            return
        }

        if let retryWaitTimeInterval = retryStrategy.shouldRetry(given: error) {
            DispatchQueue.main.async {
                self.retryRequestTimer = Timer.scheduledTimer(
                    timeInterval: retryWaitTimeInterval,
                    target: self,
                    selector: #selector(self.retryRequest),
                    userInfo: nil,
                    repeats: false
                )
            }
        }    }

    internal func retryRequest() {
        guard let generalRequestDelegate = self.generalRequest?.delegate as? PPGeneralRequestDelegate else {
            self.logger?.log(
                "Invalid delegate for general request: \(String(describing: self.generalRequest))",
                logLevel: .error
            )
            return
        }

        let newRequest = self.app.request(
            using: self.requestOptions,
            onSuccess: generalRequestDelegate.onSuccess,
            onError: generalRequestDelegate.onError
        )

        self.generalRequest = newRequest
    }
}
