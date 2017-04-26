import Foundation

@objc public class Subscription: NSObject {
    // TODO: Do we want to store the request here? Probably not

//    public let subscribeRequest: SubscribeRequest

    public let delegate: PPSubscriptionDelegate
    public internal(set) var state: SubscriptionState = .opening

    public init(delegate: PPSubscriptionDelegate = PPSubscriptionDelegate()) {
        self.delegate = delegate
    }
}

// TODO: What are we doing with this?

public enum SubscriptionState {
    case opening
    case open
    case failed
    case ended
}
