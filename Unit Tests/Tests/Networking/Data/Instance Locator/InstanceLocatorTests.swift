import XCTest
@testable import PusherPlatform

class InstanceLocatorTests: XCTestCase {
    
    // MARK: - Tests
    
    func testShouldInstantiateInstanceLocatorWithCorrectValues() {
        let instanceLocator = InstanceLocator(string: "test:instance:locator")
        
        XCTAssertNotNil(instanceLocator)
        XCTAssertEqual(instanceLocator?.region, "instance")
        XCTAssertEqual(instanceLocator?.identifier, "locator")
        XCTAssertEqual(instanceLocator?.version, "test")
    }
    
    func testShouldNotInstantiateInstanceLocatorWithTooFewComponents() {
        let instanceLocator = InstanceLocator(string: "invalid:locator")
        
        XCTAssertNil(instanceLocator)
    }
    
    func testShouldNotInstantiateInstanceLocatorWithTooManyComponents() {
        let instanceLocator = InstanceLocator(string: "invalid:test:instance:locator")
        
        XCTAssertNil(instanceLocator)
    }
    
    func testShouldNotInstantiateInstanceLocatorWithEmptyComponents() {
        XCTAssertNil(InstanceLocator(string: "invalid:invalid:"))
        XCTAssertNil(InstanceLocator(string: "invalid::invalid"))
        XCTAssertNil(InstanceLocator(string: ":invalid:invalid"))
        XCTAssertNil(InstanceLocator(string: "invalid::"))
        XCTAssertNil(InstanceLocator(string: ":invalid:"))
        XCTAssertNil(InstanceLocator(string: "::invalid"))
        XCTAssertNil(InstanceLocator(string: "::"))

    }
        
}
