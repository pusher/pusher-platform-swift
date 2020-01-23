import XCTest
import OHHTTPStubs
@testable import PusherPlatform

class DefaultTokenProviderTests: XCTestCase {
    
    // MARK: - Tests lifecycle
    
    override func tearDown() {
        OHHTTPStubs.removeAllStubs()
        
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testShouldInitializeTokenProviderWithCorrectValues() {
        guard let url = URL(string: "https://www.pusher.com") else {
            fatalError("Failed to instantiate URL.")
        }
        
        let headers = ["testHeaderField" : "testHeaderValue"]
        let queryItems = [URLQueryItem(name: "testQueryItemName", value: "testQueryItemValue")]
        let bodyItems = [URLEncodedBodyItem(name: "testBodyItemName", value: "testBodyItemValue")]
        
        let tokenProvider = DefaultTokenProvider(url: url, headers: headers, queryItems: queryItems, body: bodyItems, logger: DefaultLogger())
        
        XCTAssertEqual(tokenProvider.url, url)
        XCTAssertTrue(tokenProvider.logger is DefaultLogger)
        XCTAssertEqual(tokenProvider.headersInjector(), headers)
        XCTAssertEqual(tokenProvider.queryItemsInjector(), queryItems)
        
        guard let body = tokenProvider.bodyInjector() else {
            XCTFail("Empty body of token provider's request.")
            return
        }
        
        XCTAssertEqual(body.count, 1)
        XCTAssertEqual(body[0].name, "testBodyItemName")
        XCTAssertEqual(body[0].value, "testBodyItemValue")
    }
    
    func testShouldRetrieveTokenFromTestTokenSerivce() {
        guard let url = URL(string: "https://www.pusher.com") else {
            fatalError("Failed to instantiate URL.")
        }
        
        let userQueryItem = URLQueryItem(name: "user_id", value: "bob")
        
        OHHTTPStubs.stubRequests(passingTest: isPath(url.path)) { _ -> OHHTTPStubsResponse in
            return jsonFixture(named: "token")
        }
        
        let tokenProvider = DefaultTokenProvider(url: url, queryItems: [userQueryItem])
        
        let expectation = self.expectation(description: "Token retrieval")
        
        tokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertTrue(token.token.count > 0)
                XCTAssertFalse(token.isExpired)
                
            default:
                XCTFail("Failed to retrieve token from the web service.")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    func testShouldReportAnErrorWhenTokenRetrievalFailed() {
        guard let url = URL(string: "https://404.com") else {
            fatalError("Failed to instantiate URL.")
        }
        
        OHHTTPStubs.stubRequests(passingTest: isAbsoluteURLString(url.absoluteString)) { _ -> OHHTTPStubsResponse in
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorZeroByteResource)
            return OHHTTPStubsResponse(error: error)
        }
        
        let tokenProvider = DefaultTokenProvider(url: url)
        
        let expectation = self.expectation(description: "Token retrieval")
        
        tokenProvider.fetchToken { result in
            switch result {
            case let .failure(error: error):
                XCTAssertNotNil(error)
                
            default:
                XCTFail("Unexpectedly retrieved token from the web service.")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldSetDefaultContentTypeHeader() {
        guard let url = URL(string: "https://unimportant.url") else {
            fatalError("Failed to instantiate URL.")
        }
        
        OHHTTPStubs.stubRequests(passingTest: { request -> Bool in
            guard let headers = request.allHTTPHeaderFields,
                let contentType = headers[Header.Field.contentType.rawValue] else {
                    return false
            }
            
            return request.url == url && contentType == Header.Value.applicationFormURLEncoded.rawValue
        }) { _ -> OHHTTPStubsResponse in
            return jsonFixture(named: "token")
        }
        
        let tokenProvider = DefaultTokenProvider(url: url)
        
        let expectation = self.expectation(description: "Token retrieval")
        
        tokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertNotNil(token)
                
            default:
                XCTFail("Request has not been stubbed due to missing headers.")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldSetDefaultContentTypeBodyItem() {
        guard let url = URL(string: "https://unimportant.url") else {
            fatalError("Failed to instantiate URL.")
        }
        
        OHHTTPStubs.stubRequests(passingTest: { request -> Bool in
            let bodyItem = URLEncodedBodyItem(name: URLEncodedBodyItem.Name.grantType, value: URLEncodedBodyItem.Value.clientCredentials)
            
            guard let body = request.ohhttpStubs_httpBody,
                let serializedBodyItems = URLEncodedBodySerializer.serialize([bodyItem]).data(using: .utf8) else {
                    return false
            }
            
            return request.url == url && body == serializedBodyItems
        }) { _ -> OHHTTPStubsResponse in
            return jsonFixture(named: "token")
        }
        
        let tokenProvider = DefaultTokenProvider(url: url)
        
        let expectation = self.expectation(description: "Token retrieval")
        
        tokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertNotNil(token)
                
            default:
                XCTFail("Request has not been stubbed due to incorrect content of the body.")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldSetCustomHeader() {
        guard let url = URL(string: "https://unimportant.url") else {
            fatalError("Failed to instantiate URL.")
        }
        
        let headerField = "x-custom-header"
        let headerValue = "testValue"
        
        OHHTTPStubs.stubRequests(passingTest: { request -> Bool in
            guard let headers = request.allHTTPHeaderFields,
                let customHeader = headers[headerField] else {
                    return false
            }
            
            return request.url == url && customHeader == headerValue
        }) { _ -> OHHTTPStubsResponse in
            return jsonFixture(named: "token")
        }
        
        let tokenProvider = DefaultTokenProvider(url: url, headers: [headerField : headerValue])
        
        let expectation = self.expectation(description: "Token retrieval")
        
        tokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertNotNil(token)
                
            default:
                XCTFail("Request has not been stubbed due to missing headers.")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldAllowContentTypeHeaderOverride() {
        guard let url = URL(string: "https://unimportant.url") else {
            fatalError("Failed to instantiate URL.")
        }
        
        let headerValue = "text/csv"
        
        OHHTTPStubs.stubRequests(passingTest: { request -> Bool in
            guard let headers = request.allHTTPHeaderFields,
                let contentType = headers[Header.Field.contentType.rawValue] else {
                    return false
            }
            
            return request.url == url && contentType == headerValue
        }) { _ -> OHHTTPStubsResponse in
            return jsonFixture(named: "token")
        }
        
        let tokenProvider = DefaultTokenProvider(url: url, headers: [Header.Field.contentType.rawValue : headerValue])
        
        let expectation = self.expectation(description: "Token retrieval")
        
        tokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertNotNil(token)
                
            default:
                XCTFail("Request has not been stubbed due to missing headers.")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldSetCustomQueryItem() {
        guard let url = URL(string: "https://unimportant.url") else {
            fatalError("Failed to instantiate URL.")
        }
        
        let queryItem = URLQueryItem(name: "customItem", value: "customValue")
        
        OHHTTPStubs.stubRequests(passingTest: { request -> Bool in
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [queryItem]
            
            guard let stubURL = components?.url else {
                return false
            }
            return request.url == stubURL
        }) { _ -> OHHTTPStubsResponse in
            return jsonFixture(named: "token")
        }
        
        let tokenProvider = DefaultTokenProvider(url: url, queryItems: [queryItem])
        
        let expectation = self.expectation(description: "Token retrieval")
        
        tokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertNotNil(token)
                
            default:
                XCTFail("Request has not been stubbed due to missing query items.")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldSetCustomBodyItem() {
        guard let url = URL(string: "https://unimportant.url") else {
            fatalError("Failed to instantiate URL.")
        }
        
        let customBodyItem = URLEncodedBodyItem(name: "customItem", value: "customValue")
        
        OHHTTPStubs.stubRequests(passingTest: { request -> Bool in
            let grantTypeBodyItem = URLEncodedBodyItem(name: URLEncodedBodyItem.Name.grantType, value: URLEncodedBodyItem.Value.clientCredentials)
            
            guard let body = request.ohhttpStubs_httpBody,
                let serializedBodyItems = URLEncodedBodySerializer.serialize([grantTypeBodyItem, customBodyItem]).data(using: .utf8) else {
                    return false
            }
            
            return request.url == url && body == serializedBodyItems
        }) { _ -> OHHTTPStubsResponse in
            return jsonFixture(named: "token")
        }
        
        let tokenProvider = DefaultTokenProvider(url: url, body: [customBodyItem])
        
        let expectation = self.expectation(description: "Token retrieval")
        
        tokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertNotNil(token)
                
            default:
                XCTFail("Request has not been stubbed due to incorrect content of the body.")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldAllowGrantTypeBodyItemOverride() {
        guard let url = URL(string: "https://unimportant.url") else {
            fatalError("Failed to instantiate URL.")
        }
        
        let bodyItem = URLEncodedBodyItem(name: URLEncodedBodyItem.Name.grantType.rawValue, value: "customValue")
        
        OHHTTPStubs.stubRequests(passingTest: { request -> Bool in
            guard let body = request.ohhttpStubs_httpBody,
                let serializedBodyItems = URLEncodedBodySerializer.serialize([bodyItem]).data(using: .utf8) else {
                    return false
            }
            
            return request.url == url && body == serializedBodyItems
        }) { _ -> OHHTTPStubsResponse in
            return jsonFixture(named: "token")
        }
        
        let tokenProvider = DefaultTokenProvider(url: url, body: [bodyItem])
        
        let expectation = self.expectation(description: "Token retrieval")
        
        tokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertNotNil(token)
                
            default:
                XCTFail("Request has not been stubbed due to incorrect content of the body.")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldInjectCustomHeader() {
        guard let url = URL(string: "https://unimportant.url") else {
            fatalError("Failed to instantiate URL.")
        }
        
        let headerField = "x-custom-header"
        let firstHeaderValue = "firsyTestValue"
        let secondHeaderValue = "secondTestValue"
        
        OHHTTPStubs.stubRequests(passingTest: { request -> Bool in
            guard let headers = request.allHTTPHeaderFields,
                let customHeader = headers[headerField] else {
                    return false
            }
            
            return request.url == url && customHeader == secondHeaderValue
        }) { _ -> OHHTTPStubsResponse in
            return jsonFixture(named: "token")
        }
        
        let tokenProvider = DefaultTokenProvider(url: url, headers: [headerField : firstHeaderValue])
        tokenProvider.headersInjector = { [headerField : secondHeaderValue] }
        
        let expectation = self.expectation(description: "Token retrieval")
        
        tokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertNotNil(token)
                
            default:
                XCTFail("Request has not been stubbed due to missing headers.")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldInjectCustomQueryItem() {
        guard let url = URL(string: "https://unimportant.url") else {
            fatalError("Failed to instantiate URL.")
        }
        
        let firstQueryItem = URLQueryItem(name: "customItem", value: "firstCustomValue")
        let secondQueryItem = URLQueryItem(name: "customItem", value: "secondCustomValue")
        
        OHHTTPStubs.stubRequests(passingTest: { request -> Bool in
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [secondQueryItem]
            
            guard let stubURL = components?.url else {
                return false
            }
            return request.url == stubURL
        }) { _ -> OHHTTPStubsResponse in
            return jsonFixture(named: "token")
        }
        
        let tokenProvider = DefaultTokenProvider(url: url, queryItems: [firstQueryItem])
        tokenProvider.queryItemsInjector = { [secondQueryItem] }
        
        let expectation = self.expectation(description: "Token retrieval")
        
        tokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertNotNil(token)
                
            default:
                XCTFail("Request has not been stubbed due to missing query items.")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldInjectCustomBodyItem() {
        guard let url = URL(string: "https://unimportant.url") else {
            fatalError("Failed to instantiate URL.")
        }
        
        let firstCustomBodyItem = URLEncodedBodyItem(name: "customItem", value: "firstCustomValue")
        let secondCustomBodyItem = URLEncodedBodyItem(name: "customItem", value: "secondCustomValue")
        
        OHHTTPStubs.stubRequests(passingTest: { request -> Bool in
            let grantTypeBodyItem = URLEncodedBodyItem(name: URLEncodedBodyItem.Name.grantType, value: URLEncodedBodyItem.Value.clientCredentials)
            
            guard let body = request.ohhttpStubs_httpBody,
                let serializedBodyItems = URLEncodedBodySerializer.serialize([grantTypeBodyItem, secondCustomBodyItem]).data(using: .utf8) else {
                    return false
            }
            
            return request.url == url && body == serializedBodyItems
        }) { _ -> OHHTTPStubsResponse in
            return jsonFixture(named: "token")
        }
        
        let tokenProvider = DefaultTokenProvider(url: url, body: [firstCustomBodyItem])
        tokenProvider.bodyInjector = { [secondCustomBodyItem] }
        
        let expectation = self.expectation(description: "Token retrieval")
        
        tokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertNotNil(token)
                
            default:
                XCTFail("Request has not been stubbed due to incorrect content of the body.")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
}
