import XCTest
@testable import PusherPlatform

class URLEncodedBodySerializerTests: XCTestCase {
    
    // MARK: - Tests
    
    func testShouldCorrectlySerializeSingleValidBodyItem() {
        let bodyItem = URLEncodedBodyItem(name: "testName", value: "testValue")
        
        let serializedBodyItems = URLEncodedBodySerializer.serialize([bodyItem])
        
        XCTAssertEqual(serializedBodyItems, "testName=testValue")
    }
    
    func testShouldNotSerializeBodyItemWithEmptyName() {
        let bodyItem = URLEncodedBodyItem(name: "", value: "testValue")
        
        let serializedBodyItems = URLEncodedBodySerializer.serialize([bodyItem])
        
        XCTAssertEqual(serializedBodyItems, "")
    }
    
    func testShouldCorrectlySerializeSingleBodyItemWithEmptyValue() {
        let bodyItem = URLEncodedBodyItem(name: "testName", value: "")
        
        let serializedBodyItems = URLEncodedBodySerializer.serialize([bodyItem])
        
        XCTAssertEqual(serializedBodyItems, "testName=")
    }
    
    func testShouldCorrectlySerializeMultipleValidBodyItems() {
        let firstBodyItem = URLEncodedBodyItem(name: "firstName", value: "firstValue")
        let secondBodyItem = URLEncodedBodyItem(name: "secondName", value: "secondValue")
        let thirdBodyItem = URLEncodedBodyItem(name: "thirdName", value: "thirdValue")
        
        let serializedBodyItems = URLEncodedBodySerializer.serialize([firstBodyItem, secondBodyItem, thirdBodyItem])
        
        XCTAssertEqual(serializedBodyItems, "firstName=firstValue&secondName=secondValue&thirdName=thirdValue")
    }
    
    func testShouldIgnoreBodyItemWithEmptyName() {
        let firstBodyItem = URLEncodedBodyItem(name: "firstName", value: "firstValue")
        let secondBodyItem = URLEncodedBodyItem(name: "", value: "secondValue")
        let thirdBodyItem = URLEncodedBodyItem(name: "thirdName", value: "thirdValue")
        
        let serializedBodyItems = URLEncodedBodySerializer.serialize([firstBodyItem, secondBodyItem, thirdBodyItem])
        
        XCTAssertEqual(serializedBodyItems, "firstName=firstValue&thirdName=thirdValue")
    }
    
    func testShouldCorrectlySerializeMultipleBodyItemsWithEmptyValue() {
        let firstBodyItem = URLEncodedBodyItem(name: "firstName", value: "firstValue")
        let secondBodyItem = URLEncodedBodyItem(name: "secondName", value: "")
        let thirdBodyItem = URLEncodedBodyItem(name: "thirdName", value: "thirdValue")
        
        let serializedBodyItems = URLEncodedBodySerializer.serialize([firstBodyItem, secondBodyItem, thirdBodyItem])
        
        XCTAssertEqual(serializedBodyItems, "firstName=firstValue&secondName=&thirdName=thirdValue")
    }
    
}
