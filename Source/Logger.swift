import Foundation

@objc public protocol Logger: class {
    func log(message: String)
}

@objc public class DefaultLogger: NSObject, Logger {
    static public var Logger: Logger = DefaultLogger()
    internal let logQueue = DispatchQueue(label: "com.pusherplatform.swift.logger")

    public func log(message: String) {
        logQueue.async {
            print(message)
        }
    }
}
