import Foundation

public protocol PPLogger {
    
    func log(_ message: @autoclosure @escaping () -> String, logLevel: PPLogLevel)
    
}
