import Foundation

public class PPRequest {

    internal let delegate: PPRequestTaskDelegate

    // TOOD: Set options when needed, otherwise take provided value

    // TODO: Should I be Optional? Who should be able to set me?

    public var options: PPRequestOptions? = nil

    // TODO: Fix this - this is just wrong

//    public internal(set) var state: SubscriptionState = .opening

    internal init(type: PPRequestType, delegate: PPRequestTaskDelegate? = nil) {
        if delegate != nil {
            self.delegate = delegate!
        } else {
            switch type {
            case .subscription:
                self.delegate = PPSubscriptionDelegate()
            case .general:
                self.delegate = PPGeneralRequestDelegate()
            }
        }
    }
}

public enum PPRequestType {
    case subscription
    case general
}


//public protocol PPRequest {
//    var delegate: PPRequestTaskDelegate { get set }
//
//    init(delegate: PPRequestTaskDelegate?)
//}
//
//public class PPSubscription: PPRequest {
//    public var delegate: PPSubscriptionDelegate
//
//    public required init(delegate: PPSubscriptionDelegate? = nil) {
//        self.delegate = delegate ?? PPSubscriptionDelegate()
//    }
//}
//
//
//public class PPGeneralRequest: PPRequest {
//    public var delegate: PPGeneralRequestDelegate
//
//    public required init(delegate: PPGeneralRequestDelegate? = nil) {
//        self.delegate = delegate ?? PPGeneralRequestDelegate()
//    }
//}
