import XCTest
@testable import PusherPlatform

class URLEncodedBodyItemTests: XCTestCase {
    
    // MARK: - Tests
    
    func testShouldSetCorrectValuesFromString() {
        let bodyItem = URLEncodedBodyItem(name: "testName", value: "testValue")
        
        XCTAssertEqual(bodyItem.name, "testName")
        XCTAssertEqual(bodyItem.value, "testValue")
    }
    
    func testShouldSetCorrectValuesFromEnumeration() {
        let bodyItem = URLEncodedBodyItem(name: URLEncodedBodyItem.Name.grantType, value: URLEncodedBodyItem.Value.clientCredentials)
        
        XCTAssertEqual(bodyItem.name, "grant_type")
        XCTAssertEqual(bodyItem.value, "client_credentials")
    }
    
}
