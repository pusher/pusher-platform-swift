import Foundation

@objc public class ResumableSubscription: NSObject {
    public let path: String

    // TODO: This is pretty disgusting - may be able to just use willSet
    // instead of using storage properties like _onOpen
    // TODO: Check memory mangement stuff here - capture list etc

    internal var _onOpen: (() -> Void)?
    public var onOpen: (() -> Void)? {
        get {
            return self._onOpen
        }
        set {
            self._onOpen = newValue
            self.subscription?.onOpen = {
                self.handleOnOpen()
                self._onOpen?()
            }
        }
    }

    internal var _onEvent: ((String, [String: String], Any) -> Void)?
    public var onEvent: ((String, [String: String], Any) -> Void)? {
        get {
            return self._onEvent
        }

        set {
            self._onEvent = newValue
            self.subscription?.onEvent = { eventId, headers, data in
                self.handleOnEvent(eventId: eventId, headers: headers, data: data)
                self._onEvent?(eventId, headers, data)
            }
        }
    }

    internal var _onEnd: ((Int?, [String: String]?, Any?) -> Void)?
    public var onEnd: ((Int?, [String: String]?, Any?) -> Void)? {
        get {
            return self._onEnd
        }
        set {
            self._onEnd = newValue
            self.subscription?.onEnd = { statusCode, headers, info in
                self.handleOnEnd(statusCode: statusCode, headers: headers, info: info)
                self._onEnd?(statusCode, headers, info)
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

    // TODO: we should also provide some sort of closurse that can be set up to be called
    // if someone wants to store the lastEventIdReceived themselves, e.g. persistently
    public internal(set) var lastEventIdReceived: String? = nil

    // TODO: Make internal!
    public var retrySubscriptionTimer: Timer? = nil

    public init(
        app: ElementsApp,
        path: String,
        jwt: String? = nil,
        headers: [String: String]? = nil,
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
        // TODO: Not sure this ever gets called
        self.changeState(to: .open)
    }

    public func handleOnEvent(eventId: String, headers: [String: String]?, data: Any) {
        // TODO: potentially call "eventIdReceived" callback, although maybe onEvent itself is enough?
        self.lastEventIdReceived = eventId
    }

    public func handleOnEnd(statusCode: Int? = nil, headers: [String: String]? = nil, info: Any?) {
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
        // TODO: clean this up - shouldn't have to repeat the onOpen, onEvent and onEnd closures.
        // Maybe we can use the old subscription's closures? Probably.
        // TODO: what to do if this throws?

        // TODO: Add some debug logging that prints what the lastEventIdReceived is
        var headers: [String: String]? = nil

        if self.lastEventIdReceived != nil {
            headers = ["Last-Event-ID": self.lastEventIdReceived!]
        }

        try? self.app.subscribe(
            path: self.path,
            headers: headers,
            onOpen: {
                self.handleOnOpen()
                self._onOpen?()
            },
            onEvent: { eventId, headers, data in
                self.handleOnEvent(eventId: eventId, headers: headers, data: data)
                self._onEvent?(eventId, headers, data)
            },
            onEnd: { statusCode, headers, info in
                self.handleOnEnd(statusCode: statusCode, headers: headers, info: info)
                self._onEnd?(statusCode, headers, info)
            }
        ).then { subscription -> Void in
            print("Successfully created new subscription")
            self.subscription = subscription

            // TODO: should this be here?
            // Don't think it's necessary as a non-repeating timer should
            // invalidate itself as soon as it's fired, which should be straightaway
            self.retrySubscriptionTimer?.invalidate()
            self.retrySubscriptionTimer = nil
        }.catch { error in
            print("Error in setting up new subscription for resumable subscription at path \(self.path): \(error)")
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
