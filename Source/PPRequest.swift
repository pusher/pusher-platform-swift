import Foundation

public class PPRequest {

    internal let delegate: PPRequestTaskDelegate

    // TODO: Should I be Optional? Who should be able to set me?

    public var options: PPRequestOptions? = nil


    // TODO: Fix this - this is just wrong. It should only live on a PPSubscription 
    // sort of object

//    public internal(set) var state: SubscriptionState = .opening

    internal init(type: PPRequestType, delegate: PPRequestTaskDelegate? = nil) {
        switch type {
        case .subscription:
            self.delegate = delegate ?? PPSubscriptionDelegate()
        case .general:
            self.delegate = delegate ?? PPGeneralRequestDelegate()
        }
    }
}

public enum PPRequestType {
    case subscription
    case general
}
