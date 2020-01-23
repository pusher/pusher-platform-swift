import Foundation

/// Enumeration defining log levels used by loggers implementing `Logger` protocol.
public enum LogLevel: Int {
    
    case verbose
    case debug
    case info
    case warning
    case error
    
}

// MARK: - String representation

extension LogLevel {
    
    // MARK: - Accessors
    
    /// The corresponding string value of the type.
    public var stringValue: String {
        switch self {
        case .verbose:
            return "VERBOSE"
            
        case .debug:
            return "DEBUG"
            
        case .info:
            return "INFO"
            
        case .warning:
            return "WARNING"
            
        case .error:
            return "ERROR"
        }
    }
    
}

// MARK: - Comparable

extension LogLevel: Comparable {
    
    /// Returns a Boolean value indicating whether the value of the first argument is less than that of
    /// the second argument.
    ///
    /// - Parameters:
    ///   - lhs: A log level to compare.
    ///   - rhs: Another log level to compare.
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
}
