import XCTest
@testable import PusherPlatform

class URLEncodedBodyItemValueTests: XCTestCase {
    
    // MARK: - Tests
    
    func testShouldHaveCorrectValueForClientCredentials() {
        XCTAssertEqual(URLEncodedBodyItem.Value.clientCredentials.rawValue, "client_credentials")
    }
    
}
