import Foundation

public protocol PPRequest: class {
    associatedtype Delegate
    var delegate: Delegate { get set }

    var options: PPRequestOptions? { get set }

    func setLoggerOnDelegate(_ logger: PPLogger?)
}


private class _AnyPPRequestBase<Delegate>: PPRequest {
    var delegate: Delegate {
        get { fatalError("Must override") }
        set { fatalError("Must override") }
    }
    var options: PPRequestOptions? {
        get { fatalError("Must override") }
        set { fatalError("Must override") }
    }

    // Ensure that init() cannot be called to initialise this class
    init() {
        guard type(of: self) != _AnyPPRequestBase.self else {
            fatalError("Cannot initialise, must subclass")
        }
    }

    func setLoggerOnDelegate(_ logger: PPLogger?) {
        fatalError("Must override")
    }
}

private final class _AnyPPRequestBox<ConcretePPRequest: PPRequest>: _AnyPPRequestBase<ConcretePPRequest.Delegate> {
    // Store the concrete type
    var concrete: ConcretePPRequest

    // Override all properties
    override var delegate: ConcretePPRequest.Delegate {
        get { return self.concrete.delegate }
        set { self.concrete.delegate = newValue }
    }

    override var options: PPRequestOptions? {
        get { return self.concrete.options }
        set { self.concrete.options = newValue }
    }

    // Define init()
    init(_ concrete: ConcretePPRequest) {
        self.concrete = concrete
    }

    // Override all functions
    override func setLoggerOnDelegate(_ logger: PPLogger?) {
        concrete.setLoggerOnDelegate(logger)
    }
}

final public class AnyPPRequest<Delegate>: PPRequest {
    // Store the box specialised by content.
    // This line is the reason why we need an abstract class _AnyCupBase. We cannot store here an instance of _AnyCupBox directly because the concrete type for Cup is provided by the initialiser, at a later stage.
    private let box: _AnyPPRequestBase<Delegate>

    public var delegate: Delegate {
        get { return self.box.delegate }
        set { self.box.delegate = newValue }
    }

    public var options: PPRequestOptions? {
        get { return self.box.options }
        set { self.box.options = newValue }
    }

    init<Concrete: PPRequest>(_ concrete: Concrete) where Concrete.Delegate == Delegate {
        self.box = _AnyPPRequestBox(concrete)
    }

    // All methods for the protocol Cup just call the e quivalent box method
    public func setLoggerOnDelegate(_ logger: PPLogger?) {
        self.box.setLoggerOnDelegate(logger)
    }
}

public typealias PPSubscription = AnyPPRequest<PPSubscriptionDelegate>
public typealias PPGeneralRequest = AnyPPRequest<PPGeneralRequestDelegate>




//public class PPSubscription: PPRequest {
//    public typealias Delegate = PPSubscriptionDelegate
//
//    public var delegate: PPSubscriptionDelegate
//    public var options: PPRequestOptions?
//
//    public required init(delegate: PPSubscriptionDelegate? = nil) {
//        self.delegate = delegate ?? PPSubscriptionDelegate()
//    }
//
//    public func setLoggerOnDelegate(_ logger: PPLogger?) {
//
//    }
//}
//
//public class PPGeneralRequest: PPRequest {
//    public typealias Delegate = PPGeneralRequestDelegate
//
//    public var delegate: PPGeneralRequestDelegate
//    public var options: PPRequestOptions?
//
//    public required init(delegate: PPGeneralRequestDelegate? = nil) {
//        self.delegate = delegate ?? PPGeneralRequestDelegate()
//    }
//
//    public func setLoggerOnDelegate(_ logger: PPLogger?) {
//
//    }
//}







//public class PPRequest {
//
//    let type: PPRequestType
//    var delegate: PPRequestTaskDelegate
//
//    // TODO: Should this be Optional? Who should be able to set options?
//
//    public var options: PPRequestOptions? = nil
//
//    // TODO: Fix this - this is just wrong. It should only live on a PPSubscription
//    // sort of object
//
////    public internal(set) var state: SubscriptionState = .opening
//
//
//    // TODO: Should this be public?
//    init(type: PPRequestType, delegate: PPRequestTaskDelegate? = nil) {
//        self.type = type
//        switch type {
//        case .subscription:
//            self.delegate = delegate ?? PPSubscriptionDelegate()
//        case .general:
//            self.delegate = delegate ?? PPGeneralRequestDelegate()
//        }
//    }
//
//    func setLoggerOnDelegate(_ logger: PPLogger?) {
//        self.delegate.logger = logger
//    }
//
//}

//extension PPRequest: CustomDebugStringConvertible {
//    public var debugDescription: String {
//        let requestInfo = "Request type: \(self.type.rawValue)"
//        return [requestInfo, self.options.debugDescription].joined(separator: "\n")
//    }
//}


//public enum PPRequestType: String {
//    case subscription
//    case general
//}

