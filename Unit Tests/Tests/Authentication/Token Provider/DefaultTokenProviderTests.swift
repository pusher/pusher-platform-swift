import XCTest
@testable import PusherPlatform

class DefaultTokenProviderTests: XCTestCase {
    
    // MARK: - Tests
    
    func testShouldInitializeTokenProviderWithCorrectValues() {
        guard let url = URL(string: "https://www.pusher.com") else {
            fatalError("Failed to instantiate URL.")
        }
        
        let headers = ["testHeaderField" : "testHeaderValue"]
        let queryItems = [URLQueryItem(name: "testQueryItemName", value: "testQueryItemValue")]
        let bodyItems = [URLEncodedBodyItem(name: "testBodyItemName", value: "testBodyItemValue")]
        
        let tokenProvider = DefaultTokenProvider(url: url, headers: headers, queryItems: queryItems, body: bodyItems, logger: PPDefaultLogger())
        
        XCTAssertEqual(tokenProvider.url, url)
        XCTAssertNotNil(tokenProvider.logger)
        XCTAssertEqual(tokenProvider.headers, headers)
        XCTAssertEqual(tokenProvider.queryItems, queryItems)
        
        guard let body = tokenProvider.body else {
            XCTFail("Empty body of token provider's request.")
            return
        }
        
        XCTAssertEqual(body.count, 1)
        XCTAssertEqual(body[0].name, "testBodyItemName")
        XCTAssertEqual(body[0].value, "testBodyItemValue")
    }
    
}
