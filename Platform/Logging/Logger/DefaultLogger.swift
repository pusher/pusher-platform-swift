import Foundation

/// DefaultLogger prints all passed to it messages in Xcode's console. Messages printed in the console
/// are filtered by the provided log level.
public class DefaultLogger {
    
    // MARK: - Properties
    
    /// Log level used to filter messages which should be printed in Xcode's console.
    public var logLevel: LogLevel
    
    private let queue: DispatchQueue
    
    // MARK: - Initializers
    
    /// Create an DefaultLogger which prints all passed to it messages in Xcode's console.
    ///
    /// - Parameters:
    ///     - logLevel: Log level used to filter messages which should be printed in the console.
    public init(logLevel: LogLevel = .debug) {
        self.logLevel = logLevel
        self.queue = DispatchQueue(for: DefaultLogger.self)
    }
    
}

// MARK: - Logger

extension DefaultLogger: PPLogger {
    
    /// Method used to log a message with a specified log level.
    ///
    /// - Parameters:
    ///     - message: Message that should be logged by the logger.
    ///     - logLevel: Log level of the message.
    public func log(_ message: @autoclosure @escaping () -> String, logLevel: LogLevel) {
        guard logLevel >= self.logLevel else {
            return
        }
        
        self.queue.async {
            print("[\(logLevel.stringValue)] \(message())")
        }
    }
    
}
