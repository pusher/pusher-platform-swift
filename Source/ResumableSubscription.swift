import Foundation

@objc public class ResumableSubscription: NSObject {
    public let path: String

    // TODO: Check memory mangement stuff here - capture list etc

    public var onOpen: (() -> Void)? {
        willSet {
            self.subscription?.onOpen = {
                self.handleOnOpen()
                newValue?()
            }
        }
    }

    public var onEvent: ((String, [String: String], Any) -> Void)? {
        willSet {
            self.subscription?.onEvent = { eventId, headers, data in
                self.handleOnEvent(eventId: eventId, headers: headers, data: data)
                newValue?(eventId, headers, data)
            }
        }
    }

    public var onEnd: ((Int?, [String: String]?, Any?) -> Void)? {
        willSet {
            self.subscription?.onEnd = { statusCode, headers, info in
                self.handleOnEnd(statusCode: statusCode, headers: headers, info: info)
                newValue?(statusCode, headers, info)
            }
        }
    }

    public var onError: ((Error) -> Void)? {
        willSet {
            self.subscription?.onError = { error in
                self.handleOnError(error: error)
                newValue?(error)
            }
        }
    }

    public var onStateChange: ((ResumableSubscriptionState, ResumableSubscriptionState) -> Void)?

    internal var onUnderlyingSubscriptionChange: ((Subscription?, Subscription?) -> Void)? = nil

    public internal(set) var subscription: Subscription? = nil {
        willSet {
            self.onUnderlyingSubscriptionChange?(self.subscription, newValue)
        }
    }

    public internal(set) var app: App
    public internal(set) var state: ResumableSubscriptionState = .closed
    public internal(set) var lastEventIdReceived: String? = nil
    internal var retrySubscriptionTimer: Timer? = nil

    public init(
        // TODO: Does this need to store things like jwt, headers, queryItems etc for when it recreates the subscription?
        app: App,
        path: String,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onStateChange: ((ResumableSubscriptionState, ResumableSubscriptionState) -> Void)? = nil,
        onUnderlyingSubscriptionChange: ((Subscription?, Subscription?) -> Void)? = nil) {
            self.path = path
            self.app = app
            self.onUnderlyingSubscriptionChange = onUnderlyingSubscriptionChange

            // TODO: don't like having to do this
            super.init()

            self.onOpen = onOpen
            self.onEvent = onEvent
            self.onEnd = onEnd

            self.onStateChange = onStateChange
    }

    internal func changeState(to newState: ResumableSubscriptionState) {
        let oldState = self.state
        self.state = newState
        self.onStateChange?(oldState, newState)
    }

    public func handleOnOpen() {
        // TODO: Not sure this ever gets called with the current setup
        self.changeState(to: .open)
    }

    public func handleOnEvent(eventId: String, headers: [String: String]?, data: Any) {
        self.lastEventIdReceived = eventId
    }

    public func handleOnError(error: Error) {
        // TODO: Fix this - it's a hack while I figure out what we need to do
        // Perhaps just call the onError() closure and then attempt subscription again,
        // provided we want to keep on retrying subscriptions at that point
        handleOnEnd()
    }

    public func handleOnEnd(statusCode: Int? = nil, headers: [String: String]? = nil, info: Any? = nil) {
        // TODO: not always resuming - need to figure out what to do here.
        // We need to be able to differentiate between a recoverable error and
        // errors that mean we need to stop the subscription.
        // Do we therefore also need to setup a onProperEnd (not the real name suggestion)?
        // Then we'd set the state to closed and not try and create a new subscription.
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

    internal func setupNewSubscription() {
        var headers: [String: String]? = nil

        if let eventId = self.lastEventIdReceived {
            DefaultLogger.Logger.log(message: "Creating new Subscription with Last-Event-ID \(eventId)")
            headers = ["Last-Event-ID": eventId]
        }

        let subscribeRequest = SubscribeRequest(path: self.path, headers: headers)

        self.app.subscribe(
            using: subscribeRequest,
            onOpen: self.subscription?.onOpen,
            onEvent: self.subscription?.onEvent,
            onEnd: self.subscription?.onEnd,
            onError: self.subscription?.onError
        ) { result in
            switch result {
            case .failure(let error):
                // TODO: does it make sense to handle this error like this?
                // What sort of error would we even get here?
                self.handleOnError(error: error)
                DefaultLogger.Logger.log(message: "Error in setting up new subscription for resumable subscription at path \(self.path): \(error)")
            case .success(let subscription):
                self.subscription = subscription

                self.retrySubscriptionTimer?.invalidate()
                self.retrySubscriptionTimer = nil
            }
        }
    }
}

public enum ResumableSubscriptionState {
    case closed
    case closing
    case open
    case opening
    case resuming
}
