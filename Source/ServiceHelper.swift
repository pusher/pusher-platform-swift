@objc public protocol ServiceHelper: class {
    var app: App? { get set }
    static var namespace: String { get }
}

public enum ServiceHelperError: Error {
    case noAppObject
    case invalidJSONObjectAsData(Any)
    case failedToJSONSerializeData(Any)
}
