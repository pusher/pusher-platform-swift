import Foundation

public enum PPLogLevel: Int, Comparable {
    
    case verbose = 1
    case debug
    case info
    case warning
    case error
    
    public static func < (a: PPLogLevel, b: PPLogLevel) -> Bool {
        return a.rawValue < b.rawValue
    }
    
    public func stringRepresentation() -> String {
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
