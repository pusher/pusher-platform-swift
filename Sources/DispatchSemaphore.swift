import Foundation

public extension DispatchSemaphore {
    
    func synchronized<T>(_ operation: () -> T) -> T {
        self.wait()
        let value = operation()
        self.signal()
        return value
    }

}
