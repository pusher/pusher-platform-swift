import XCTest
@testable import PusherPlatform

class URLEncodedBodyItemNameTests: XCTestCase {
    
    // MARK: - Tests
    
    func testShouldHaveCorrectValueForGrantType() {
        XCTAssertEqual(URLEncodedBodyItem.Name.grantType.rawValue, "grant_type")
    }
    
}
