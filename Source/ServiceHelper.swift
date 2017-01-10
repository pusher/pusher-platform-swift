@objc public protocol Service: class {
    var app: App? { get set }
    static var namespace: String { get }
}

public enum ServiceError: Error {
    case noAppObject
    case invalidJSONObjectAsData(Any)
    case failedToJSONSerializeData(Any)
}
