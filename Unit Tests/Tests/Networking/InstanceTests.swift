import XCTest
@testable import PusherPlatform

class InstanceTests: XCTestCase {
    
    let validInstanceLocator = InstanceLocator(string: "locator_version:locator_region:locator_identifier")!
    let validURL = URL(string: "http://some.url")!
    
    // MARK: - Tests
    
    /* MARK: initWithSDKInfo
     
        init(
            instanceLocator: InstanceLocator,
            serviceName: String,
            serviceVersion: String,
            sdkInfo: PPSDKInfo,
            tokenProvider: TokenProvider? = nil,
            logger: PPLogger = PPDefaultLogger()
        )
    */
    
    func test_initWithSDKInfo_allArgumentsSet_returnsFullyPopulated() {
        
        /******************/
        /*---- GIVEN -----*/
        /******************/
        
        let instanceLocator = validInstanceLocator
        let serviceName = "serviceName"
        let serviceVersion = "serviceVersion"
        let sdkInfo = PPSDKInfo(productName: "productName",
                                sdkVersion: "sdkVersion")
        let tokenProvider = DefaultTokenProvider(url: validURL)
        let logger = FakeLogger()
        
        /******************/
        /*----- WHEN -----*/
        /******************/
        
        let instance = Instance(instanceLocator: instanceLocator,
                                serviceName: serviceName,
                                serviceVersion: serviceVersion,
                                sdkInfo: sdkInfo,
                                tokenProvider: tokenProvider,
                                logger: logger)
        
        /******************/
        /*----- THEN -----*/
        /******************/
        
        XCTAssertEqual(instance.id, "locator_identifier")
        XCTAssertEqual(instance.serviceName, "serviceName")
        XCTAssertEqual(instance.serviceVersion, "serviceVersion")
        XCTAssertEqual(instance.client.baseUrlComponents.host, "locator_region.pusherplatform.io")
        XCTAssertEqual(instance.client.sdkInfo.productName, "productName")
        XCTAssertEqual(instance.client.sdkInfo.sdkVersion, "sdkVersion")
        XCTAssertNotNil(instance.tokenProvider as? RetryableTokenProvider)
        XCTAssertNotNil(instance.logger as? FakeLogger)
    }
    
    func test_initWithSDKInfo_nilTokenProviderNilLogger_returnsWithNilTokenProviderAndDefaultLogger() {
        
        /******************/
        /*---- GIVEN -----*/
        /******************/
        
        let instanceLocator = validInstanceLocator
        let serviceName = "serviceName"
        let serviceVersion = "serviceVersion"
        let sdkInfo = PPSDKInfo(productName: "productName",
                                sdkVersion: "sdkVersion")
        
        /******************/
        /*----- WHEN -----*/
        /******************/
        
        // Note that optional args `tokenProvider` and `logger` have not been passed
        let instance = Instance(instanceLocator: instanceLocator,
                                serviceName: serviceName,
                                serviceVersion: serviceVersion,
                                sdkInfo: sdkInfo)
        
        /******************/
        /*----- THEN -----*/
        /******************/
        
        XCTAssertEqual(instance.id, "locator_identifier")
        XCTAssertEqual(instance.serviceName, "serviceName")
        XCTAssertEqual(instance.serviceVersion, "serviceVersion")
        XCTAssertEqual(instance.client.baseUrlComponents.host, "locator_region.pusherplatform.io")
        XCTAssertEqual(instance.client.sdkInfo.productName, "productName")
        XCTAssertEqual(instance.client.sdkInfo.sdkVersion, "sdkVersion")
        XCTAssertNil(instance.tokenProvider) // Is nil by default
        XCTAssertNotNil(instance.logger as? PPDefaultLogger) // Is a `PPDefaultLogger` by default
    }
    
    /* MARK: initWithClient
     
        init(
            instanceLocator: InstanceLocator,
            serviceName: String,
            serviceVersion: String,
            client: PPBaseClient,
            tokenProvider: TokenProvider? = nil,
            logger: PPLogger = PPDefaultLogger()
        )
    */
    
    func test_initWithClient_allArgumentsSet_returnsFullyPopulated() {
        
        /******************/
        /*---- GIVEN -----*/
        /******************/
        
        let instanceLocator = validInstanceLocator
        let serviceName = "serviceName"
        let serviceVersion = "serviceVersion"
        let client = PPBaseClient(host: "host",
                                  sdkInfo: PPSDKInfo(productName: "productName",
                                                     sdkVersion: "sdkVersion"))
        let tokenProvider = DefaultTokenProvider(url: validURL)
        let logger = FakeLogger()
        
        /******************/
        /*----- WHEN -----*/
        /******************/
        
        let instance = Instance(instanceLocator: instanceLocator,
                                serviceName: serviceName,
                                serviceVersion: serviceVersion,
                                client: client,
                                tokenProvider: tokenProvider,
                                logger: logger)
        
        /******************/
        /*----- THEN -----*/
        /******************/
        
        XCTAssertEqual(instance.id, "locator_identifier")
        XCTAssertEqual(instance.serviceName, "serviceName")
        XCTAssertEqual(instance.serviceVersion, "serviceVersion")
        XCTAssertEqual(instance.client, client)
        XCTAssertNotNil(instance.tokenProvider as? RetryableTokenProvider)
        XCTAssertNotNil(instance.logger as? FakeLogger)
    }
    
    func test_initWithClient_nilTokenProviderNilLogger_returnsWithNilTokenProviderAndDefaultLogger() {
        
        /******************/
        /*---- GIVEN -----*/
        /******************/
        
        let instanceLocator = validInstanceLocator
        let serviceName = "serviceName"
        let serviceVersion = "serviceVersion"
        let client = PPBaseClient(host: "host",
                                  sdkInfo: PPSDKInfo(productName: "productName",
                                                     sdkVersion: "sdkVersion"))
        
        /******************/
        /*----- WHEN -----*/
        /******************/
        
        // Note that optional args `tokenProvider` and `logger` have not been passed
        let instance = Instance(instanceLocator: instanceLocator,
                                serviceName: serviceName,
                                serviceVersion: serviceVersion,
                                client: client)
        
        /******************/
        /*----- THEN -----*/
        /******************/
        
        XCTAssertEqual(instance.id, "locator_identifier")
        XCTAssertEqual(instance.serviceName, "serviceName")
        XCTAssertEqual(instance.serviceVersion, "serviceVersion")
        XCTAssertEqual(instance.client, client)
        XCTAssertNil(instance.tokenProvider) // Is nil by default
        XCTAssertNotNil(instance.logger as? PPDefaultLogger) // Is a `PPDefaultLogger` by default
    }

}
