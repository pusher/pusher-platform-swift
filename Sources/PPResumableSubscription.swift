import Foundation

@objc public class PPResumableSubscription: NSObject {
    public let requestOptions: PPRequestOptions

    public internal(set) unowned var instance: Instance
    public internal(set) var unsubscribed: Bool = false
    public internal(set) var state: PPResumableSubscriptionState = .opening
    public internal(set) var lastEventIdReceived: String? = nil
    public internal(set) var subscription: PPSubscription? = nil
    public var retryStrategy: PPRetryStrategy? = nil
    var retrySubscriptionTimer: PPRepeater? = nil

    public var onOpen: (() -> Void)? {
        willSet {
            guard let subscriptionDelegate = self.subscription?.delegate else {
                self.instance.logger.log(
                    "No delegate for subscription: \(self.subscription.debugDescription)",
                    logLevel: .error
                )
                return
            }

            subscriptionDelegate.onOpen = { [weak self] in
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
            guard let subscriptionDelegate = self.subscription?.delegate else {
                self.instance.logger.log(
                    "No delegate for subscription: \(self.subscription.debugDescription))",
                    logLevel: .error
                )
                return
            }

            subscriptionDelegate.onOpening = { [weak self] in
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
            guard let subscriptionDelegate = self.subscription?.delegate else {
                self.instance.logger.log(
                    "No delegate for subscription: \(self.subscription.debugDescription)",
                    logLevel: .error
                )
                return
            }

            subscriptionDelegate.onEvent = { [weak self] eventId, headers, data in
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
            guard let subscriptionDelegate = self.subscription?.delegate else {
                self.instance.logger.log(
                    "No delegate for subscription: \(self.subscription.debugDescription)",
                    logLevel: .error
                )
                return
            }

            subscriptionDelegate.onEnd = { [weak self] statusCode, headers, info in
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
    var _onError: ((Error) -> Void)? = nil

    public var onError: ((Error) -> Void)? {
        willSet {
            guard let subscriptionDelegate = self.subscription?.delegate else {
                self.instance.logger.log(
                    "No delegate for subscription: \(self.subscription.debugDescription)",
                    logLevel: .error
                )
                return
            }

            subscriptionDelegate.onError = { [weak self] error in
                guard let strongSelf = self else {
                    print("self is nil when trying to handle onError in subscription delegate")
                    return
                }

                strongSelf.handleOnError(error: error)
            }

            self._onError = newValue
        }
    }

    public init(instance: Instance, requestOptions: PPRequestOptions) {
        self.instance = instance
        self.requestOptions = requestOptions
    }

    deinit {
        self.retrySubscriptionTimer = nil

        guard let subDelegate = self.subscription?.delegate else {
            return
        }

        subDelegate.cleanUpHeartbeatTimeoutTimer()
        subDelegate.cancelTask()
        self.cleanUpOldSubscription(subscriptionDelegate: subDelegate)
    }

    public func end() {
        guard let subscriptionDelegate = self.subscription?.delegate else {
            self.instance.logger.log(
                "No delegate for subscription: \(self.subscription.debugDescription)",
                logLevel: .error
            )
            return
        }

        self.retrySubscriptionTimer = nil

        self.cancelExistingSubscriptionTask(subscriptionDelegate: subscriptionDelegate)
        subscriptionDelegate.endSubscription()
        self.cleanUpOldSubscription(subscriptionDelegate: subscriptionDelegate)
    }

    public func setLastEventIdReceivedTo(_ eventId: String?) {
        self.lastEventIdReceived = eventId
    }

    public func changeState(to newState: PPResumableSubscriptionState) {
        // TODO: Potentially add an onStateChange handlers property
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

        self.retrySubscriptionTimer = nil

        if let err = error as? PPSubscriptionError, case let .eosWithRetryAfter(eosWithRetryError) = err {
            let retryWaitTimeInterval = eosWithRetryError.timeInterval
            self.instance.logger.log(
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
            self.instance.logger.log("Not attempting retry because no retry strategy is set", logLevel: .debug)
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
        self.retrySubscriptionTimer = PPRepeater.once(
            after: .seconds(retryWaitTimeInterval)
        ) { [weak self] _ in
            guard let strongSelf = self else {
                print("self is nil when setting up retry subscription timer")
                return
            }

            strongSelf.setupNewSubscription()
        }
    }

    public func handleOnEnd(statusCode: Int? = nil, headers: [String: String]? = nil, info: Any? = nil) {
        // TODO: Why do we need this check?
//        guard !self.unsubscribed else {
//            self.changeState(to: .ended)
//            return
//        }

        self.retrySubscriptionTimer = nil
        self.changeState(to: .ended)
    }

    func setupNewSubscription() {
        guard let subscriptionDelegate = self.subscription?.delegate else {
            self.instance.logger.log(
                "No delegate for subscription: \(self.subscription.debugDescription)",
                logLevel: .error
            )
            return
        }

        self.cancelExistingSubscriptionTask(subscriptionDelegate: subscriptionDelegate)
        self.cleanUpOldSubscription(subscriptionDelegate: subscriptionDelegate)

        if let eventId = self.lastEventIdReceived {
            self.instance.logger.log("Creating new underlying subscription with Last-Event-ID \(eventId)", logLevel: .debug)
            self.requestOptions.addHeaders(["Last-Event-ID": eventId])
        } else {
            self.instance.logger.log("Creating new underlying subscription", logLevel: .debug)
        }

        let newSubscription = self.instance.subscribe(
            using: self.requestOptions,
            onOpening: subscriptionDelegate.onOpening,
            onOpen: subscriptionDelegate.onOpen,
            onEvent: subscriptionDelegate.onEvent,
            onEnd: subscriptionDelegate.onEnd,
            onError: subscriptionDelegate.onError
        )

        self.subscription = newSubscription
    }

    func cancelExistingSubscriptionTask(subscriptionDelegate: PPSubscriptionDelegate) {
        self.instance.logger.log("Cancelling subscriptionDelegate's existing task, if it exists", logLevel: .verbose)
        subscriptionDelegate.cancelTask()
    }

    func cleanUpOldSubscription(subscriptionDelegate: PPSubscriptionDelegate) {
        guard let reqCleanupClosure = subscriptionDelegate.requestCleanup else {
            self.instance.logger.log("No request cleanup closure set on subscription delegate", logLevel: .verbose)
            return
        }

        guard let taskId = subscriptionDelegate.task?.taskIdentifier else {
            self.instance.logger.log(
                "Could not retrieve task identifier associated with subscription delegate",
                logLevel: .verbose
            )
            return
        }

        reqCleanupClosure(taskId)
    }
}

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
