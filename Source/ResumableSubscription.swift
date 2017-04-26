import Foundation

@objc public class ResumableSubscription: NSObject {
    public let subscribeRequest: SubscribeRequest
    public var unsubscribed: Bool = false

    // TODO: Check memory mangement stuff here - capture list etc

    public var onOpen: (() -> Void)? {
        willSet {
            self.subscription?.delegate.onOpen = {
                self.handleOnOpen()
                newValue?()
            }
        }
    }

    public var onOpening: (() -> Void)? {
        willSet {
            self.subscription?.delegate.onOpening = {
                self.handleOnOpening()
                newValue?()
            }
        }
    }

    public var onResuming: (() -> Void)?

    public var onEvent: ((String, [String: String], Any) -> Void)? {
        willSet {
            self.subscription?.delegate.onEvent = { eventId, headers, data in
                self.handleOnEvent(eventId: eventId, headers: headers, data: data)
                newValue?(eventId, headers, data)
            }
        }
    }

    public var onEnd: ((Int?, [String: String]?, Any?) -> Void)? {
        willSet {
            self.subscription?.delegate.onEnd = { statusCode, headers, info in
                self.handleOnEnd(statusCode: statusCode, headers: headers, info: info)
                newValue?(statusCode, headers, info)
            }
        }
    }

    public var onError: ((Error) -> Void)? {
        willSet {
            self.subscription?.delegate.onError = { error in
                self.handleOnError(error: error)
                newValue?(error)
            }
        }
    }

    public internal(set) var subscription: Subscription? = nil
    public internal(set) var app: App
    public internal(set) var state: ResumableSubscriptionState = .opening
    public internal(set) var lastEventIdReceived: String? = nil

//    public var retryStrategy: RetryStrategy = DefaultRetryStrategy()

    internal var retrySubscriptionTimer: Timer? = nil

    public init(
        // TODO: Does this need to store things like jwt, headers, queryItems etc for when it recreates the subscription?
        // Don't think so, as things like header will probably change depending on context
        app: App,
        request: SubscribeRequest,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onResuming: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self.app = app
        self.subscribeRequest = request
    }

    public func changeState(to newState: ResumableSubscriptionState) {
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
    }

    public func handleOnResuming() {
        self.changeState(to: .resuming)
    }

    public func handleOnEvent(eventId: String, headers: [String: String]?, data: Any) {
        self.lastEventIdReceived = eventId
    }

    public func handleOnError(error: Error) {
        // TODO: not always resuming - need to figure out what to do here.
        // We need to be able to differentiate between a recoverable error and
        // errors that mean we need to stop the subscription.
        // Do we therefore also need to setup a onProperEnd (not the real name suggestion)?
        // Then we'd set the state to closed and not try and create a new subscription.

        guard !self.unsubscribed else {
            self.changeState(to: .ended)
            return
        }

        if self.state != .resuming {
            self.changeState(to: .resuming)
        }

        DispatchQueue.main.async {
            self.retrySubscriptionTimer = Timer.scheduledTimer(
                timeInterval: 1.0,
                target: self,
                selector: #selector(self.setupNewSubscription),
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

        self.changeState(to: .ended)
    }

    internal func setupNewSubscription() {
        if let eventId = self.lastEventIdReceived {
            DefaultLogger.Logger.log(message: "Creating new Subscription with Last-Event-ID \(eventId)")
            self.subscribeRequest.addHeaders(["Last-Event-ID": eventId])
        }

        let newSubscription = self.app.subscribe(
            using: self.subscribeRequest,
            onOpening: self.subscription?.delegate.onOpening,
            onOpen: self.subscription?.delegate.onOpen,
            onEvent: self.subscription?.delegate.onEvent,
            onEnd: self.subscription?.delegate.onEnd,
            onError: self.subscription?.delegate.onError
        )

        self.subscription = newSubscription
    }
}

public enum ResumableSubscriptionState {
    case opening
    case open
    case resuming
    case failed
    case ended
}
