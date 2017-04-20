import Foundation

@objc public class Subscription: NSObject {
    public let path: String
    public internal(set) var taskIdentifier: Int?

    public var onOpening: (() -> Void)?
    public var onOpen: (() -> Void)?
    public var onEvent: ((String, [String: String], Any) -> Void)?
    public var onEnd: ((Int?, [String: String]?, Any?) -> Void)?
    public var onError: ((Error) -> Void)?

    public var badResponseCodeError: RequestError? = nil

    public var error: Error? = nil

    public init(
        path: String,
        taskIdentifier: Int? = nil,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil) {
            self.path = path
            self.taskIdentifier = taskIdentifier
            self.onOpening = onOpening
            self.onOpen = onOpen
            self.onEvent = onEvent
            self.onEnd = onEnd
            self.onError = onError
    }
}
