import Foundation

public class PPRequest {

    internal let type: PPRequestType
    internal let delegate: PPRequestTaskDelegate

    // TODO: Should I be Optional? Who should be able to set me?

    public var options: PPRequestOptions? = nil


    // TODO: Fix this - this is just wrong. It should only live on a PPSubscription
    // sort of object

//    public internal(set) var state: SubscriptionState = .opening

    internal init(type: PPRequestType, delegate: PPRequestTaskDelegate? = nil) {
        self.type = type
        switch type {
        case .subscription:
            self.delegate = delegate ?? PPSubscriptionDelegate()
        case .general:
            self.delegate = delegate ?? PPGeneralRequestDelegate()
        }
    }
}

extension PPRequest: CustomDebugStringConvertible {
    public var debugDescription: String {
        let requestInfo = "Request type: \(self.type.rawValue)"
        return [requestInfo, self.options.debugDescription].joined(separator: "\n")
    }
}


public enum PPRequestType: String {
    case subscription
    case general
}
