import Foundation

// TODO: Rename

@objc public class PPRetryableGeneralRequest: NSObject {
    public let requestOptions: PPRequestOptions
    public internal(set) var app: App
    public var retryStrategy: PPRetryStrategy? = nil

    public internal(set) var generalRequest: PPRequest? = nil

    internal var retryRequestTimer: Timer? = nil

    public var onSuccess: ((Data) -> Void)? {
        willSet {
            if let genReqDelegate = self.generalRequest?.delegate as? PPGeneralRequestDelegate {
                genReqDelegate.onSuccess = { data in
                    self.handleOnSuccess(data)
                    newValue?(data)
                }
            } else {
                // TODO: What to do?
            }
        }
    }

    public var onError: ((Error) -> Void)? {
        willSet {
            if let genReqDelegate = self.generalRequest?.delegate as? PPGeneralRequestDelegate {
                genReqDelegate.onError = { error in
                    self.handleOnError(error: error)
                    newValue?(error)
                }
            } else {
                // TODO: What to do?
            }
        }
    }

    public var onRetry: ((Error?) -> Void)?


    public init(app: App, requestOptions: PPRequestOptions) {
        self.app = app
        self.requestOptions = requestOptions
    }

    deinit {
        self.retryRequestTimer?.invalidate()
    }

    public func handleOnSuccess(_ data: Data) {
        print("HANDLING ON SUCCESS IN PPRETRYABLEGENERALREQUEST")
    }

    public func handleOnError(error: Error) {

        // TODO: Check how many times this can be called
        // TODO: Check which errors to pass to RetryStrategy

        print("Received error and handling it in PPRetryableGeneralRequest: \(error.localizedDescription)")

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
            // TODO: Log about not retrying request because no retry strategy
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
        } else {
            // TODO: Log about not retrying request because retry strategy said so
        }
    }

    internal func retryRequest() {
        if let genReqDelegate = self.generalRequest?.delegate as? PPGeneralRequestDelegate {

            let newRequest = self.app.request(
                using: self.requestOptions,
                onSuccess: genReqDelegate.onSuccess,
                onError: genReqDelegate.onError
            )

            self.generalRequest = newRequest
        } else {
            // TODO: What the fuck can we do?!
        }
    }
}
