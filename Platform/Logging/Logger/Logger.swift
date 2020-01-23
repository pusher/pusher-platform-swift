import Foundation

/// Protocol defining the interface required to be implemented to provide logging capability used by the SDK.
public protocol Logger {
    
    /// Method used to log a message with a specified log level.
    ///
    /// - Parameters:
    ///     - message: Message that should be logged by the logger.
    ///     - logLevel: Log level of the message.
    func log(_ message: @autoclosure @escaping () -> String, logLevel: LogLevel)
    
}
