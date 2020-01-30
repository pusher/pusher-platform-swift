@testable import PusherPlatform

class FakeLogger: PPLogger {
    
    func log(_ message: @autoclosure @escaping () -> String, logLevel: PPLogLevel) {
    }
}
