import XCTest
@testable import PusherPlatform

class HeaderFieldTests: XCTestCase {
    
    // MARK: - Tests
    
    func testShouldHaveCorrectValueForContentType() {
        XCTAssertEqual(Header.Field.contentType.rawValue, "Content-Type")
    }
    
}
