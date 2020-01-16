import XCTest
@testable import PusherPlatform

class DispatchQueueExtensionsTests: XCTestCase {
    
    // MARK: - Tests
    
    func testShouldSetCorrectName() {
        let queue = DispatchQueue(for: Instance.self)
        
        XCTAssertEqual(queue.label, "com.pusher.platform.Instance")
    }
    
    func testShouldSetCorrectQoS() {
        let queue = DispatchQueue(for: Instance.self)
        
        XCTAssertEqual(queue.qos, DispatchQoS.default)
    }
    
}
