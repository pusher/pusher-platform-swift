import Foundation
import OHHTTPStubs

extension OHHTTPStubs {
    
    @discardableResult class func stubRequestsIfNeeded(passingTest testBlock: @escaping OHHTTPStubsTestBlock, withStubResponse stubResponse: @escaping OHHTTPStubsResponseBlock) -> OHHTTPStubsDescriptor? {
        #if STUBBED
        return OHHTTPStubs.stubRequests(passingTest: testBlock, withStubResponse: stubResponse)
        #else
        return nil
        #endif
    }
    
}

// MARK: - Bundle locator

private class BundleLocator {}

// MARK: - Internal functions

func jsonFixture(named name: String) -> OHHTTPStubsResponse {
    let bundle = Bundle(for: BundleLocator.self)
    
    guard let filePath = bundle.path(forResource: name, ofType: "json") else {
        fatalError("Failed to locate JSON fixture.")
    }
    
    let headers = ["Content-Type" : "application/json"]
    
    return fixture(filePath: filePath, headers: headers)
}
