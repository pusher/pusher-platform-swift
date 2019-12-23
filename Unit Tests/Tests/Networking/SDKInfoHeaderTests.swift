import XCTest
@testable import PusherPlatform

class SDKInfoHeaderTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func testProductNameGetsSetAsHTTPAdditionalHeader() {
        let productName = "chatkit"
        let sdkVersion = "1.2.3"

        let instance = Instance(
            locator: "v1:test:test",
            serviceName: "chatkit",
            serviceVersion: "v1",
            sdkInfo: PPSDKInfo(productName: productName, sdkVersion: sdkVersion)
        )

        let baseClientAdditionalHeaders = instance.client.generalRequestURLSession.configuration.httpAdditionalHeaders as! [String: String]

        XCTAssertEqual(baseClientAdditionalHeaders["X-SDK-Product"], productName)
    }

    func testSDKVersionGetsSetAsHTTPAdditionalHeader() {
        let productName = "chatkit"
        let sdkVersion = "1.2.3"

        let instance = Instance(
            locator: "v1:test:test",
            serviceName: "chatkit",
            serviceVersion: "v1",
            sdkInfo: PPSDKInfo(productName: productName, sdkVersion: sdkVersion)
        )

        let baseClientAdditionalHeaders = instance.client.generalRequestURLSession.configuration.httpAdditionalHeaders as! [String: String]

        XCTAssertEqual(baseClientAdditionalHeaders["X-SDK-Version"], sdkVersion)
    }

    #if os(macOS)
    func testSDKPlatformGetsSetAsHTTPAdditionalHeaderFormacOS() {
        let productName = "chatkit"
        let sdkVersion = "1.2.3"

        let instance = Instance(
            locator: "v1:test:test",
            serviceName: "chatkit",
            serviceVersion: "v1",
            sdkInfo: PPSDKInfo(productName: productName, sdkVersion: sdkVersion)
        )

        let baseClientAdditionalHeaders = instance.client.generalRequestURLSession.configuration.httpAdditionalHeaders as! [String: String]

        XCTAssertEqual(baseClientAdditionalHeaders["X-SDK-Platform"], "macOS")
    }
    #elseif os(iOS)
    func testSDKPlatformGetsSetAsHTTPAdditionalHeaderForiOS() {
        let productName = "chatkit"
        let sdkVersion = "1.2.3"

        let instance = Instance(
            locator: "v1:test:test",
            serviceName: "chatkit",
            serviceVersion: "v1",
            sdkInfo: PPSDKInfo(productName: productName, sdkVersion: sdkVersion)
        )

        let baseClientAdditionalHeaders = instance.client.generalRequestURLSession.configuration.httpAdditionalHeaders as! [String: String]

        XCTAssertEqual(baseClientAdditionalHeaders["X-SDK-Platform"], "iOS")
    }
    #elseif os(tvOS)
    func testSDKPlatformGetsSetAsHTTPAdditionalHeaderFortvOS() {
        let productName = "chatkit"
        let sdkVersion = "1.2.3"

        let instance = Instance(
            locator: "v1:test:test",
            serviceName: "chatkit",
            serviceVersion: "v1",
            sdkInfo: PPSDKInfo(productName: productName, sdkVersion: sdkVersion)
        )

        let baseClientAdditionalHeaders = instance.client.generalRequestURLSession.configuration.httpAdditionalHeaders as! [String: String]

        XCTAssertEqual(baseClientAdditionalHeaders["X-SDK-Platform"], "tvOS")
    }
    #endif
}
