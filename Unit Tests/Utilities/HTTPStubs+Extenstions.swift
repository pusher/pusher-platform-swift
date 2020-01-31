import Foundation
import OHHTTPStubs
import OHHTTPStubsSwift

func jsonFixture(named name: String) -> HTTPStubsResponse {
    guard let filePath = Bundle.current.path(forResource: name, ofType: "json") else {
        fatalError("Failed to locate JSON fixture.")
    }
    
    let headers = ["Content-Type" : "application/json"]
    
    return fixture(filePath: filePath, headers: headers)
}
