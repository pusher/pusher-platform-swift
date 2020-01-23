import Foundation

public class PPDefaultLogger {
    
    public var minimumLogLevel: LogLevel = .debug
    internal let logQueue = DispatchQueue(label: "com.pusherplatform.swift.defaultlogger")
    
    public init() {}
    
}

extension PPDefaultLogger: PPLogger {
    
    public func log(_ message: @autoclosure @escaping () -> String, logLevel: LogLevel) {
        if logLevel >= minimumLogLevel {
            logQueue.async {
                print("[\(logLevel.stringValue)] \(message())")
            }
        }
    }
    
}
