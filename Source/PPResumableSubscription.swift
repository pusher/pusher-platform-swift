import Foundation

@objc public class PPResumableSubscription: NSObject {
    public let requestOptions: PPRequestOptions

    // TODO: Should app be a weak reference here?

    public internal(set) var app: App
    public internal(set) var unsubscribed: Bool = false
    public internal(set) var state: PPResumableSubscriptionState = .opening
    public internal(set) var lastEventIdReceived: String? = nil
    public internal(set) var subscription: PPRequest? = nil
    public var retryStrategy: PPRetryStrategy? = nil
    internal var retrySubscriptionTimer: Timer? = nil

    public var onOpen: (() -> Void)? {
        willSet {
            guard let subDelegate = self.subscription?.delegate as? PPSubscriptionDelegate else {
                self.app.logger.log(
                    "Invalid delegate for subscription: \(String(describing: self.subscription))",
                    logLevel: .error
                )
                return
            }

            subDelegate.onOpen = { [weak self] in
                guard let strongSelf = self else {
                    print("self is nil when trying to handle onOpen in subscription delegate")
                    return
                }

                strongSelf.handleOnOpen()
                newValue?()
            }
        }
    }

    public var onOpening: (() -> Void)? {
        willSet {
            guard let subDelegate = self.subscription?.delegate as? PPSubscriptionDelegate else {
                self.app.logger.log(
                    "Invalid delegate for subscription: \(String(describing: self.subscription))",
                    logLevel: .error
                )
                return
            }

            subDelegate.onOpening = { [weak self] in
                guard let strongSelf = self else {
                    print("self is nil when trying to handle onOpening in subscription delegate")
                    return
                }

                strongSelf.handleOnOpening()
                newValue?()
            }

        }
    }

    public var onResuming: (() -> Void)? = nil

    public var onEvent: ((String, [String: String], Any) -> Void)? {
        willSet {
            guard let subDelegate = self.subscription?.delegate as? PPSubscriptionDelegate else {
                self.app.logger.log(
                    "Invalid delegate for subscription: \(String(describing: self.subscription))",
                    logLevel: .error
                )
                return
            }

            subDelegate.onEvent = { [weak self] eventId, headers, data in
                guard let strongSelf = self else {
                    print("self is nil when trying to handle onEvent in subscription delegate")
                    return
                }

                strongSelf.handleOnEvent(eventId: eventId, headers: headers, data: data)
                newValue?(eventId, headers, data)
            }
        }
    }

    public var onEnd: ((Int?, [String: String]?, Any?) -> Void)? {
        willSet {
            guard let subDelegate = self.subscription?.delegate as? PPSubscriptionDelegate else {
                self.app.logger.log(
                    "Invalid delegate for subscription: \(String(describing: self.subscription))",
                    logLevel: .error
                )
                return
            }

            subDelegate.onEnd = { [weak self] statusCode, headers, info in
                guard let strongSelf = self else {
                    print("self is nil when trying to handle onEnd in subscription delegate")
                    return
                }

                strongSelf.handleOnEnd(statusCode: statusCode, headers: headers, info: info)
                newValue?(statusCode, headers, info)
            }
        }
    }

    // This represents the end user's onError callback that they want to be called. We only
    // ever call this at most once. For example, if we need to retry to instantiate a
    // subscription then the errors that lead to requiring a retry would not be communicated
    // back up to the end user, until the retry strategy returns an error itself.
    internal var _onError: ((Error) -> Void)? = nil

    public var onError: ((Error) -> Void)? {
        willSet {
            guard let subDelegate = self.subscription?.delegate as? PPSubscriptionDelegate else {
                self.app.logger.log(
                    "Invalid delegate for subscription: \(String(describing: self.subscription))",
                    logLevel: .error
                )
                return
            }

            subDelegate.onError = { [weak self] error in
                guard let strongSelf = self else {
                    print("self is nil when trying to handle onError in subscription delegate")
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
        self.retrySubscriptionTimer?.invalidate()
    }

    public func setLastEventIdReceivedTo(_ eventId: String?) {
        self.lastEventIdReceived = eventId
    }

    public func changeState(to newState: PPResumableSubscriptionState) {
//        TODO: Potentially add an onStateChange handlers property
//        let oldState = self.state
//        self.onStateChangeHandlers.
        self.state = newState
    }

    public func handleOnOpening() {
        self.changeState(to: .opening)
    }

    public func handleOnOpen() {
        self.changeState(to: .open)
        self.retryStrategy?.requestSucceeded()
    }

    public func handleOnResuming() {
        self.changeState(to: .resuming)
    }

    public func handleOnEvent(eventId: String, headers: [String: String]?, data: Any) {
        if eventId != "" {
            self.lastEventIdReceived = eventId
        }
    }

    public func handleOnError(error: Error) {
        // TODO: Check which errors to pass to RetryStrategy

        // TODO: not always resuming - need to figure out what to do here.
        // We need to be able to differentiate between a recoverable error and
        // errors that mean we need to stop the subscription.
        // Then we'd set the state to closed and not try and create a new subscription.

        guard !self.unsubscribed else {
            // TODO: Really? Does this make sense?
            self.changeState(to: .ended)
            return
        }

        self.retrySubscriptionTimer?.invalidate()

        if let err = error as? PPSubscriptionError, case let .eosWithRetryAfter(eosWithRetryError) = err {
            let retryWaitTimeInterval = eosWithRetryError.timeInterval
            self.app.logger.log(
                "Attempting retry in \(retryWaitTimeInterval)s because of retry after message received with EOS message",
                logLevel: .debug
            )
            self.setupRetrySubscriptionTimer(retryWaitTimeInterval: retryWaitTimeInterval)
            return
        }

        if self.state != .resuming {
            self.changeState(to: .resuming)
        }

        guard let retryStrategy = self.retryStrategy else {
            self.app.logger.log("Not attempting retry because no retry strategy is set", logLevel: .debug)
            self._onError?(PPRetryableError.noRetryStrategyProvided)
            return
        }

        let shouldRetryResult = retryStrategy.shouldRetry(given: error)

        switch shouldRetryResult {
        case .retry(let retryWaitTimeInterval):
            self.setupRetrySubscriptionTimer(retryWaitTimeInterval: retryWaitTimeInterval)
        case .doNotRetry(let reasonErr):
            self._onError?(reasonErr)
        }
    }

    func setupRetrySubscriptionTimer(retryWaitTimeInterval: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                print("self is nil when setting up retry subscription timer")
                return
            }

            strongSelf.retrySubscriptionTimer = Timer.scheduledTimer(
                timeInterval: retryWaitTimeInterval,
                target: strongSelf,
                selector: #selector(strongSelf.setupNewSubscription),
                userInfo: nil,
                repeats: false
            )
        }
    }

    public func handleOnEnd(statusCode: Int? = nil, headers: [String: String]? = nil, info: Any? = nil) {
        // TODO: Why do we need this check?
//        guard !self.unsubscribed else {
//            self.changeState(to: .ended)
//            return
//        }

        self.retrySubscriptionTimer?.invalidate()
        self.changeState(to: .ended)
    }

    internal func setupNewSubscription() {
        guard let subscriptionDelegate = self.subscription?.delegate as? PPSubscriptionDelegate else {
            self.app.logger.log(
                "Invalid delegate for subscription: \(String(describing: self.subscription))",
                logLevel: .error
            )
            return
        }

        self.app.logger.log("Cancelling subscriptionDelegate's existing task", logLevel: .verbose)
        subscriptionDelegate.task?.cancel()

        if let eventId = self.lastEventIdReceived {
            self.app.logger.log("Creating new underlying subscription with Last-Event-ID \(eventId)", logLevel: .debug)
            self.requestOptions.addHeaders(["Last-Event-ID": eventId])
        } else {
            self.app.logger.log("Creating new underlying subscription", logLevel: .debug)
        }

        let newSubscription = self.app.subscribe(
            using: self.requestOptions,
            onOpening: subscriptionDelegate.onOpening,
            onOpen: subscriptionDelegate.onOpen,
            onEvent: subscriptionDelegate.onEvent,
            onEnd: subscriptionDelegate.onEnd,
            onError: subscriptionDelegate.onError
        )

        self.subscription = newSubscription

        guard let reqCleanupClosure = subscriptionDelegate.requestCleanup else {
            self.app.logger.log("No request cleanup closure set on subscription delegate", logLevel: .verbose)
            return
        }

        guard let taskId = subscriptionDelegate.task?.taskIdentifier else {
            self.app.logger.log(
                "Could not retrieve task identifier associated with subscription delegate",
                logLevel: .verbose
            )
            return
        }

        reqCleanupClosure(taskId)
    }
}

// TODO: I don't think this is being used nor is it being set properly 

public enum PPResumableSubscriptionState {
    case opening
    case open
    case resuming
    case failed
    case ended
}

public enum PPRetryableError: Error {
    case noRetryStrategyProvided
}
