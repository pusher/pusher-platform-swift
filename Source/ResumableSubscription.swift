import Foundation

@objc public class ResumableSubscription: NSObject {
    public let subscribeRequestOptions: PPRequestOptions
    public var unsubscribed: Bool = false

    // TODO: Check memory mangement stuff here - capture list etc

    public var onOpen: (() -> Void)? {
        willSet {
            if let subDelegate = self.subscription?.delegate as? PPSubscriptionDelegate {
                subDelegate.onOpen = {
                    self.handleOnOpen()
                    newValue?()
                }
            } else {
                // TODO: What to do?
            }
        }
    }

    public var onOpening: (() -> Void)? {
        willSet {
            if let subDelegate = self.subscription?.delegate as? PPSubscriptionDelegate {
                subDelegate.onOpening = {
                    self.handleOnOpening()
                    newValue?()
                }
            } else {
                // TODO: What to do?
            }
        }
    }

    public var onResuming: (() -> Void)?

    public var onEvent: ((String, [String: String], Any) -> Void)? {
        willSet {
            if let subDelegate = self.subscription?.delegate as? PPSubscriptionDelegate {
                subDelegate.onEvent = { eventId, headers, data in
                    self.handleOnEvent(eventId: eventId, headers: headers, data: data)
                    newValue?(eventId, headers, data)
                }
            } else {
                // TODO: What to do?
            }
        }
    }

    public var onEnd: ((Int?, [String: String]?, Any?) -> Void)? {
        willSet {
            if let subDelegate = self.subscription?.delegate as? PPSubscriptionDelegate {
                subDelegate.onEnd = { statusCode, headers, info in
                    self.handleOnEnd(statusCode: statusCode, headers: headers, info: info)
                    newValue?(statusCode, headers, info)
                }
            } else {
                // TODO: What to do?
            }
        }
    }

    public var onError: ((Error) -> Void)? {
        willSet {
            if let subDelegate = self.subscription?.delegate as? PPSubscriptionDelegate {
                subDelegate.onError = { error in
                    self.handleOnError(error: error)
                    newValue?(error)
                }
            } else {
                // TODO: What to do?
            }
        }
    }

    public internal(set) var subscription: PPRequest? = nil
    public internal(set) var app: App
    public internal(set) var state: ResumableSubscriptionState = .opening
    public internal(set) var lastEventIdReceived: String? = nil

//    public var retryStrategy: RetryStrategy = DefaultRetryStrategy()

    internal var retrySubscriptionTimer: Timer? = nil

    public init(
        // TODO: Does this need to store things like jwt, headers, queryItems etc for when it recreates the subscription?
        // Don't think so, as things like header will probably change depending on context
        app: App,
        requestOptions: PPRequestOptions,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onResuming: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        self.app = app
        self.subscribeRequestOptions = requestOptions
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

        print("Received error and handling it in ResumableSubscription: \(error.localizedDescription)")

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
            print("on the main queue about to setup the retry subscription timer")

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
        print("in setupNewSubscription")

        if let eventId = self.lastEventIdReceived {
            DefaultLogger.Logger.log(message: "Creating new Subscription with Last-Event-ID \(eventId)")
            self.subscribeRequestOptions.addHeaders(["Last-Event-ID": eventId])
        }

        if let subscriptionDelegate = self.subscription?.delegate as? PPSubscriptionDelegate {
            let newSubscription = self.app.subscribe(
                using: self.subscribeRequestOptions,
                onOpening: subscriptionDelegate.onOpening,
                onOpen: subscriptionDelegate.onOpen,
                onEvent: subscriptionDelegate.onEvent,
                onEnd: subscriptionDelegate.onEnd,
                onError: subscriptionDelegate.onError
            )

            self.subscription = newSubscription
        } else {
            // TODO: What the fuck can we do?!
        }
    }
}

public enum ResumableSubscriptionState {
    case opening
    case open
    case resuming
    case failed
    case ended
}
